import 'package:dry4dart/src/fingerprint.dart';
import 'package:test/test.dart';

import '_helpers.dart';

const _alpha = '''
List<int> alpha(List<int> xs) {
  final ys = xs.where(isOdd);
  return ys.map((x) => x + 1).toList();
}
''';

const _beta = '''
List<int> beta(List<int> items) {
  final kept = items.where(isEven);
  return kept.map((x) => x + 2).toList();
}
''';

const _invoice = r'''
Map<String, Object> invoiceSummary(List<Order> orders) {
  final paid = orders.where(isPaid);
  final domestic = paid.where(isDomestic);
  final sorted = domestic.toList()..sort((a, b) => a.date.compareTo(b.date));
  final amounts = sorted.map((o) => o.amount).toList();
  final taxes = amounts.map(tax).toList();
  final ids = sorted.map((o) => o.id).toList();
  final customers = sorted.map((o) => o.customer).toList();
  final regions = groupBy(sorted, (o) => o.region);
  final flagged = sorted.where(isFlagged).toList();
  return {
    'count': sorted.length,
    'firstId': ids.first,
    'lastId': ids.last,
    'customers': customers.toSet(),
    'regions': regions.keys,
    'flagged': flagged.length,
    'total': amounts.fold(0, (a, b) => a + b),
    'tax': taxes.fold(0, (a, b) => a + b),
  };
}
''';

const _receipt = r'''
Map<String, Object> receiptSummary(List<Row> rows) {
  final closed = rows.where(isClosed);
  final local = closed.where(isLocal);
  final ordered = local.toList()..sort((a, b) => a.date.compareTo(b.date));
  final amounts = ordered.map((r) => r.amount).toList();
  final taxable = ordered.where(isTaxable).toList();
  final taxes = amounts.map(tax).toList();
  final ids = ordered.map((r) => r.id).toList();
  final customers = ordered.map((r) => r.customer).toList();
  final regions = groupBy(ordered, (r) => r.region);
  final flagged = ordered.where(isFlagged).toList();
  return {
    'count': ordered.length,
    'firstId': ids.first,
    'lastId': ids.last,
    'customers': customers.toSet(),
    'regions': regions.keys,
    'flagged': flagged.length,
    'total': amounts.fold(0, (a, b) => a + b),
    'tax': taxes.fold(0, (a, b) => a + b),
  };
}
''';

void main() {
  group('README examples', () {
    test('alpha and beta score 1.0', () {
      final score = _scoreOf(_alpha, _beta);
      expect(score, closeTo(1.0, 1e-9));
    });

    test(
      'invoiceSummary and receiptSummary score above the default threshold',
      () {
        final score = _scoreOf(_invoice, _receipt);
        expect(score, greaterThan(0.82));
        expect(score, lessThan(1.0));
      },
    );
  });
}

double _scoreOf(String left, String right) {
  final l = collectFingerprints(normalizeSingle(left)).fingerprints;
  final r = collectFingerprints(normalizeSingle(right)).fingerprints;
  final shared = l.intersection(r).length;
  final union = l.union(r).length;
  return shared / union;
}
