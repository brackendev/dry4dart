import 'package:dry4dart/src/normalize.dart';
import 'package:test/test.dart';

List<ComparableDeclaration> parseDeclarations(
  String source, {
  String path = 'test.dart',
}) {
  return parseDartSource(source, path).declarations;
}

NormalizedNode normalizeSingle(String source, {String path = 'test.dart'}) {
  final declarations = parseDeclarations(source, path: path);
  expect(
    declarations,
    hasLength(1),
    reason: 'expected exactly one comparable declaration',
  );
  return normalize(declarations.first.node);
}
