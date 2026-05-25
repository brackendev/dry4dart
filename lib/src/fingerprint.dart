import 'normalize.dart';

const fingerprintAlgorithmVersion = 1;

class FingerprintResult {
  FingerprintResult(this.fingerprints, this.nodeCount);

  final Set<String> fingerprints;
  final int nodeCount;
}

FingerprintResult collectFingerprints(NormalizedNode root) {
  final fingerprints = <String>{};
  var nodeCount = 0;

  String visit(NormalizedNode node) {
    nodeCount++;
    final childFps = node.children.map(visit).toList();
    final buf = StringBuffer('(')..write(node.kind);
    final label = node.label;
    if (label != null) {
      buf
        ..write('|')
        ..write(_escape(label));
    }
    for (final c in childFps) {
      buf
        ..write(' ')
        ..write(c);
    }
    buf.write(')');
    final fp = buf.toString();
    fingerprints.add(fp);
    return fp;
  }

  visit(root);
  return FingerprintResult(fingerprints, nodeCount);
}

String _escape(String s) {
  // Keep the canonical form unambiguous when labels contain characters that
  // also appear in the fingerprint grammar.
  return s
      .replaceAll(r'\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)')
      .replaceAll('|', r'\|')
      .replaceAll(' ', r'\s');
}
