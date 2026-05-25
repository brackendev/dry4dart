import 'dart:io';

import 'package:dry4dart/src/discovery.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dry4dart_discovery_');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  void touch(String relativePath) {
    final f = File(p.join(tmp.path, relativePath));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync('// stub\n');
  }

  test('walks directories recursively and picks up .dart files', () {
    touch('lib/a.dart');
    touch('lib/sub/b.dart');
    touch('lib/sub/c.txt');
    final found = discoverDartFiles([
      tmp.path,
    ], const DiscoveryOptions()).map((f) => p.basename(f.path)).toSet();
    expect(found, equals({'a.dart', 'b.dart'}));
  });

  test('skips hidden directories by default', () {
    touch('lib/a.dart');
    touch('.dart_tool/b.dart');
    final found = discoverDartFiles([
      tmp.path,
    ], const DiscoveryOptions()).map((f) => p.basename(f.path)).toSet();
    expect(found, equals({'a.dart'}));
  });

  test('excludes generated files by default', () {
    touch('lib/model.dart');
    touch('lib/model.g.dart');
    touch('lib/model.freezed.dart');
    final found = discoverDartFiles([
      tmp.path,
    ], const DiscoveryOptions()).map((f) => p.basename(f.path)).toSet();
    expect(found, equals({'model.dart'}));
  });

  test('includes generated files when requested', () {
    touch('lib/model.dart');
    touch('lib/model.g.dart');
    final found = discoverDartFiles(
      [tmp.path],
      const DiscoveryOptions(includeGenerated: true),
    ).map((f) => p.basename(f.path)).toSet();
    expect(found, equals({'model.dart', 'model.g.dart'}));
  });

  test('deduplicates files reached through multiple paths', () {
    touch('lib/a.dart');
    final found = discoverDartFiles([
      tmp.path,
      p.join(tmp.path, 'lib', 'a.dart'),
    ], const DiscoveryOptions());
    expect(found, hasLength(1));
  });

  test('rejects an explicit file that is not Dart source', () {
    touch('lib/notes.txt');
    expect(
      () => discoverDartFiles([
        p.join(tmp.path, 'lib', 'notes.txt'),
      ], const DiscoveryOptions()),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('throws when an input path does not exist', () {
    expect(
      () => discoverDartFiles([
        p.join(tmp.path, 'missing.dart'),
      ], const DiscoveryOptions()),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('isGeneratedFile recognises the documented suffix list', () {
    expect(isGeneratedFile('a.g.dart'), isTrue);
    expect(isGeneratedFile('a.freezed.dart'), isTrue);
    expect(isGeneratedFile('a.mocks.dart'), isTrue);
    expect(isGeneratedFile('a.config.dart'), isTrue);
    expect(isGeneratedFile('a.gr.dart'), isTrue);
    expect(isGeneratedFile('a.dart'), isFalse);
  });
}
