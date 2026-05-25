import 'package:dry4dart/src/fingerprint.dart';
import 'package:dry4dart/src/normalize.dart';
import 'package:test/test.dart';

void main() {
  group('collectFingerprints', () {
    test('produces a fingerprint for every node', () {
      final root = NormalizedNode(
        'binary',
        label: '+',
        children: [NormalizedNode('ref'), NormalizedNode('literal')],
      );
      final result = collectFingerprints(root);
      expect(result.nodeCount, equals(3));
      expect(result.fingerprints, hasLength(3));
    });

    test('deduplicates identical subtrees into the same fingerprint', () {
      final ref = NormalizedNode('ref');
      final root = NormalizedNode('binary', label: '+', children: [ref, ref]);
      final result = collectFingerprints(root);
      expect(result.nodeCount, equals(3));
      expect(result.fingerprints, hasLength(2));
    });

    test('escapes label characters that would break the canonical grammar', () {
      final a = NormalizedNode('m', label: 'foo bar');
      final b = NormalizedNode('m', label: 'foo|bar');
      final aFps = collectFingerprints(a).fingerprints;
      final bFps = collectFingerprints(b).fingerprints;
      expect(aFps.intersection(bFps), isEmpty);
    });

    test('output is deterministic across calls', () {
      NormalizedNode build() => NormalizedNode(
        'method-call',
        label: 'where',
        children: [
          NormalizedNode('ref'),
          NormalizedNode('args', children: [NormalizedNode('ref')]),
        ],
      );
      final first = collectFingerprints(build()).fingerprints;
      final second = collectFingerprints(build()).fingerprints;
      expect(first, equals(second));
    });
  });
}
