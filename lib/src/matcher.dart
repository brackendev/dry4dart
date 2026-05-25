import 'declaration.dart';

class MatcherOptions {
  const MatcherOptions({
    this.threshold = 0.82,
    this.minLines = 4,
    this.minNodes = 20,
  });

  final double threshold;
  final int minLines;
  final int minNodes;
}

List<CandidatePair> findCandidates(
  List<Declaration> declarations,
  MatcherOptions options,
) {
  final filtered = <Declaration>[];
  for (final d in declarations) {
    if (d.lineCount < options.minLines) continue;
    if (d.nodeCount < options.minNodes) continue;
    filtered.add(d);
  }

  final index = <String, List<int>>{};
  for (var i = 0; i < filtered.length; i++) {
    for (final fp in filtered[i].fingerprints) {
      index.putIfAbsent(fp, () => []).add(i);
    }
  }

  final candidatePairs = <(int, int)>{};
  for (final ids in index.values) {
    if (ids.length < 2) continue;
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final a = ids[i];
        final b = ids[j];
        if (a == b) continue;
        candidatePairs.add(a < b ? (a, b) : (b, a));
      }
    }
  }

  final results = <CandidatePair>[];
  for (final (a, b) in candidatePairs) {
    final fpsA = filtered[a].fingerprints;
    final fpsB = filtered[b].fingerprints;
    final shared = _intersectionSize(fpsA, fpsB);
    final union = fpsA.length + fpsB.length - shared;
    if (union == 0) continue;
    final score = shared / union;
    if (score < options.threshold) continue;
    final aFirst = _isFirst(filtered[a], filtered[b]);
    final left = aFirst ? filtered[a] : filtered[b];
    final right = aFirst ? filtered[b] : filtered[a];
    results.add(CandidatePair(left, right, score));
  }

  results.sort((x, y) {
    final byScore = y.score.compareTo(x.score);
    if (byScore != 0) return byScore;
    final byLeftPath = x.left.relativePath.compareTo(y.left.relativePath);
    if (byLeftPath != 0) return byLeftPath;
    final byLeftLine = x.left.startLine.compareTo(y.left.startLine);
    if (byLeftLine != 0) return byLeftLine;
    final byRightPath = x.right.relativePath.compareTo(y.right.relativePath);
    if (byRightPath != 0) return byRightPath;
    return x.right.startLine.compareTo(y.right.startLine);
  });

  return results;
}

int _intersectionSize(Set<String> a, Set<String> b) {
  final small = a.length < b.length ? a : b;
  final big = identical(small, a) ? b : a;
  var count = 0;
  for (final fp in small) {
    if (big.contains(fp)) count++;
  }
  return count;
}

bool _isFirst(Declaration a, Declaration b) {
  final byPath = a.relativePath.compareTo(b.relativePath);
  if (byPath != 0) return byPath < 0;
  return a.startLine < b.startLine;
}
