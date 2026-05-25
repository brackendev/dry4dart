import 'dart:io';

import 'package:path/path.dart' as p;

const _generatedSuffixes = [
  '.g.dart',
  '.freezed.dart',
  '.mocks.dart',
  '.config.dart',
  '.gr.dart',
];

class DiscoveryOptions {
  const DiscoveryOptions({this.includeGenerated = false});

  final bool includeGenerated;
}

List<File> discoverDartFiles(List<String> paths, DiscoveryOptions options) {
  final seen = <String>{};
  final out = <File>[];

  void maybeAdd(File f) {
    final abs = p.canonicalize(f.absolute.path);
    if (!seen.add(abs)) return;
    if (!options.includeGenerated && isGeneratedFile(f.path)) return;
    out.add(f);
  }

  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (entity is Directory) {
        walk(entity);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        maybeAdd(entity);
      }
    }
  }

  for (final path in paths) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException('Path not found', path);
    }
    if (type == FileSystemEntityType.directory) {
      walk(Directory(path));
    } else if (type == FileSystemEntityType.file) {
      if (!path.endsWith('.dart')) {
        throw ArgumentError.value(path, 'path', 'Not a Dart file');
      }
      maybeAdd(File(path));
    }
  }
  out.sort((a, b) => a.path.compareTo(b.path));
  return out;
}

bool isGeneratedFile(String path) {
  for (final suffix in _generatedSuffixes) {
    if (path.endsWith(suffix)) return true;
  }
  return false;
}
