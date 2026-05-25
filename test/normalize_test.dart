import 'package:dry4dart/src/normalize.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  group('normalize', () {
    test('drops local variable and parameter names', () {
      final left = normalizeSingle('''
int alpha(int xs) {
  final ys = xs + 1;
  return ys;
}
''');
      final right = normalizeSingle('''
int beta(int items) {
  final kept = items + 1;
  return kept;
}
''');
      expect(_renderKinds(left), equals(_renderKinds(right)));
      expect(_renderLabels(left), equals(_renderLabels(right)));
    });

    test('preserves operator labels', () {
      final plus = normalizeSingle('''
int plus(int x) => x + 1;
''');
      final minus = normalizeSingle('''
int minus(int x) => x - 1;
''');
      expect(_renderLabels(plus), isNot(equals(_renderLabels(minus))));
    });

    test('preserves method-call targets', () {
      final whereCall = normalizeSingle('''
Iterable<int> a(Iterable<int> xs) => xs.where(isOdd);
''');
      final mapCall = normalizeSingle('''
Iterable<int> b(Iterable<int> xs) => xs.map(toInt);
''');
      expect(_renderLabels(whereCall), isNot(equals(_renderLabels(mapCall))));
    });

    test('list and map literals are distinguished', () {
      final listLit = normalizeSingle('''
List<int> a() => [1, 2, 3];
''');
      final mapLit = normalizeSingle('''
Map<String, int> b() => {'a': 1, 'b': 2};
''');
      expect(_renderKinds(listLit), isNot(equals(_renderKinds(mapLit))));
    });
  });
}

String _renderKinds(NormalizedNode node) {
  final buf = StringBuffer()..write(node.kind);
  if (node.children.isNotEmpty) {
    buf.write('[');
    for (var i = 0; i < node.children.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(_renderKinds(node.children[i]));
    }
    buf.write(']');
  }
  return buf.toString();
}

String _renderLabels(NormalizedNode node) {
  final buf = StringBuffer()
    ..write(node.kind)
    ..write('|')
    ..write(node.label ?? '');
  if (node.children.isNotEmpty) {
    buf.write('[');
    for (var i = 0; i < node.children.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(_renderLabels(node.children[i]));
    }
    buf.write(']');
  }
  return buf.toString();
}
