import 'dart:convert';

import 'declaration.dart';

enum ReportFormat { text, json }

String formatReport(List<CandidatePair> pairs, ReportFormat format) {
  switch (format) {
    case ReportFormat.text:
      return _formatText(pairs);
    case ReportFormat.json:
      return _formatJson(pairs);
  }
}

String _formatText(List<CandidatePair> pairs) {
  final buf = StringBuffer();
  for (final pair in pairs) {
    final score = pair.score.toStringAsFixed(2);
    buf
      ..write('DUPLICATE score=')
      ..writeln(score)
      ..write('  ')
      ..write(pair.left.relativePath)
      ..write(':')
      ..write(pair.left.startLine)
      ..write('-')
      ..writeln(pair.left.endLine)
      ..write('  ')
      ..write(pair.right.relativePath)
      ..write(':')
      ..write(pair.right.startLine)
      ..write('-')
      ..writeln(pair.right.endLine);
  }
  return buf.toString();
}

String _formatJson(List<CandidatePair> pairs) {
  const encoder = JsonEncoder.withIndent('  ');
  final payload = {
    'candidates': [
      for (final pair in pairs)
        {
          'score': pair.score,
          'left': {
            'file': pair.left.relativePath,
            'startLine': pair.left.startLine,
            'endLine': pair.left.endLine,
          },
          'right': {
            'file': pair.right.relativePath,
            'startLine': pair.right.startLine,
            'endLine': pair.right.endLine,
          },
          'leftNodes': pair.left.nodeCount,
          'rightNodes': pair.right.nodeCount,
        },
    ],
  };
  return encoder.convert(payload);
}
