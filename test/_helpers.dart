import 'package:dry4dart/src/normalize.dart';
import 'package:test/test.dart';

NormalizedNode normalizeSingle(String source, {String path = 'test.dart'}) {
  final parsed = parseDartSource(source, path);
  expect(
    parsed.declarations,
    hasLength(1),
    reason: 'expected exactly one comparable declaration',
  );
  return normalize(parsed.declarations.first.node);
}
