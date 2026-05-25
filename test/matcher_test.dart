import 'package:dry4dart/src/declaration.dart';
import 'package:dry4dart/src/matcher.dart';
import 'package:test/test.dart';

Declaration _decl({
  required int index,
  required String path,
  required int startLine,
  required int endLine,
  required Set<String> fingerprints,
  int? nodeCount,
}) {
  return Declaration(
    index: index,
    relativePath: path,
    startLine: startLine,
    endLine: endLine,
    fingerprints: fingerprints,
    nodeCount: nodeCount ?? fingerprints.length,
  );
}

void main() {
  group('findCandidates', () {
    test('returns nothing when scores are below the threshold', () {
      final pairs = findCandidates([
        _decl(
          index: 0,
          path: 'a.dart',
          startLine: 1,
          endLine: 30,
          fingerprints: {'a', 'b', 'c', 'd'},
        ),
        _decl(
          index: 1,
          path: 'b.dart',
          startLine: 1,
          endLine: 30,
          fingerprints: {'a', 'e', 'f', 'g'},
        ),
      ], const MatcherOptions(threshold: 0.5, minLines: 1, minNodes: 1));
      expect(pairs, isEmpty);
    });

    test('returns a pair when Jaccard meets the threshold', () {
      final pairs = findCandidates([
        _decl(
          index: 0,
          path: 'a.dart',
          startLine: 1,
          endLine: 30,
          fingerprints: {'a', 'b', 'c', 'd'},
        ),
        _decl(
          index: 1,
          path: 'b.dart',
          startLine: 1,
          endLine: 30,
          fingerprints: {'a', 'b', 'c', 'd'},
        ),
      ], const MatcherOptions(threshold: 0.5, minLines: 1, minNodes: 1));
      expect(pairs, hasLength(1));
      expect(pairs.single.score, closeTo(1.0, 1e-9));
    });

    test('drops declarations below min-lines or min-nodes', () {
      final pairs = findCandidates([
        _decl(
          index: 0,
          path: 'small.dart',
          startLine: 1,
          endLine: 2,
          fingerprints: {'a'},
          nodeCount: 1,
        ),
        _decl(
          index: 1,
          path: 'big.dart',
          startLine: 1,
          endLine: 30,
          fingerprints: {'a', 'b', 'c', 'd'},
          nodeCount: 50,
        ),
      ], const MatcherOptions(threshold: 0.1, minLines: 4, minNodes: 20));
      expect(pairs, isEmpty);
    });

    test('orders left/right by (path, startLine)', () {
      final pairs = findCandidates([
        _decl(
          index: 0,
          path: 'z.dart',
          startLine: 5,
          endLine: 30,
          fingerprints: {'a', 'b', 'c'},
        ),
        _decl(
          index: 1,
          path: 'a.dart',
          startLine: 1,
          endLine: 30,
          fingerprints: {'a', 'b', 'c'},
        ),
      ], const MatcherOptions(threshold: 0.5, minLines: 1, minNodes: 1));
      expect(pairs, hasLength(1));
      expect(pairs.single.left.relativePath, equals('a.dart'));
      expect(pairs.single.right.relativePath, equals('z.dart'));
    });

    test('sorts results by score descending', () {
      final pairs = findCandidates([
        _decl(
          index: 0,
          path: 'a.dart',
          startLine: 1,
          endLine: 30,
          fingerprints: {'x', 'y', 'z', 'w'},
        ),
        _decl(
          index: 1,
          path: 'b.dart',
          startLine: 1,
          endLine: 30,
          fingerprints: {'x', 'y', 'z', 'w'},
        ),
        _decl(
          index: 2,
          path: 'c.dart',
          startLine: 1,
          endLine: 30,
          fingerprints: {'x', 'y', 'z', 'q'},
        ),
      ], const MatcherOptions(threshold: 0.5, minLines: 1, minNodes: 1));
      expect(pairs, hasLength(3));
      for (var i = 1; i < pairs.length; i++) {
        expect(pairs[i - 1].score, greaterThanOrEqualTo(pairs[i].score));
      }
    });
  });
}
