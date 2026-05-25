class Declaration {
  Declaration({
    required this.index,
    required this.relativePath,
    required this.startLine,
    required this.endLine,
    required this.fingerprints,
    required this.nodeCount,
  });

  final int index;
  final String relativePath;
  final int startLine;
  final int endLine;
  final Set<String> fingerprints;
  final int nodeCount;

  int get lineCount => endLine - startLine + 1;
}

class CandidatePair {
  CandidatePair(this.left, this.right, this.score);

  final Declaration left;
  final Declaration right;
  final double score;
}
