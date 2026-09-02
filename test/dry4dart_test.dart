import 'dart:io';

import 'package:dry4dart/dry4dart.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dry4dart_cli_');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  Future<({int code, String out, String err})> runWithCapture(
    List<String> args,
  ) async {
    final outFile = File('${tmp.path}/_out.txt');
    final errFile = File('${tmp.path}/_err.txt');
    final out = outFile.openWrite();
    final err = errFile.openWrite();
    final code = runCli(args, out: out, err: err);
    await out.close();
    await err.close();
    return (
      code: code,
      out: outFile.readAsStringSync(),
      err: errFile.readAsStringSync(),
    );
  }

  test(
    'runCli --version prints the version declared in pubspec.yaml',
    () async {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final declared = RegExp(
        r'^version:\s*(\S+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1);
      final result = await runWithCapture(['--version']);
      expect(result.code, equals(0));
      expect(result.err, isEmpty);
      expect(result.out, equals('dry4dart $declared\n'));
    },
  );

  test('runCli reports a usage error when no paths are provided', () async {
    final result = await runWithCapture(const []);
    expect(result.code, equals(64));
    expect(result.err, contains('Specify at least one'));
  });

  test(
    'runCli returns success on a directory with no candidate matches',
    () async {
      File('${tmp.path}/a.dart').writeAsStringSync('int answer = 42;\n');
      final result = await runWithCapture([tmp.path]);
      expect(result.code, equals(0));
      expect(result.out, isEmpty);
    },
  );

  test('runCli rejects --json combined with --format text', () async {
    File('${tmp.path}/a.dart').writeAsStringSync('int answer = 42;\n');
    final result = await runWithCapture([
      '--json',
      '--format',
      'text',
      tmp.path,
    ]);
    expect(result.code, equals(64));
    expect(result.err, contains('conflicts'));
  });

  test('runCli reports functions that differ only in names, defaults, and '
      'argument values', () async {
    File('${tmp.path}/a.dart').writeAsStringSync('''
int total({int start = 0, int step = 1}) {
  final sum = combine(start, step, scale: 2);
  return sum + 1;
}
''');
    File('${tmp.path}/b.dart').writeAsStringSync('''
int subtotal({int base = 10, int delta = 5}) {
  final result = combine(base, delta, scale: 3);
  return result + 2;
}
''');
    final result = await runWithCapture([
      '--min-nodes',
      '1',
      '--min-lines',
      '1',
      tmp.path,
    ]);
    expect(result.code, equals(0));
    expect(result.err, isEmpty);
    expect(result.out, startsWith('DUPLICATE score=1.0'));
    expect(result.out, contains('a.dart:1-4'));
    expect(result.out, contains('b.dart:1-4'));
  });

  test('runCli compares primary constructor bodies across files', () async {
    File('${tmp.path}/a.dart').writeAsStringSync('''
class Point(final int x, final int y) {
  this : assert(x >= 0) {
    print(x + y);
  }
}
''');
    File('${tmp.path}/b.dart').writeAsStringSync('''
class Size(final int width, final int height) {
  this : assert(width >= 1) {
    print(width + height);
  }
}
''');
    final result = await runWithCapture([
      '--min-nodes',
      '1',
      '--min-lines',
      '1',
      tmp.path,
    ]);
    expect(result.code, equals(0));
    expect(result.err, isEmpty);
    expect(result.out, startsWith('DUPLICATE score=1.0'));
    expect(result.out, contains('a.dart:2-4'));
    expect(result.out, contains('b.dart:2-4'));
  });

  test('runCli warns on parse errors and continues', () async {
    File('${tmp.path}/broken.dart').writeAsStringSync('int x =\n');
    final result = await runWithCapture([tmp.path]);
    expect(result.code, equals(0));
    expect(result.err, contains('warning'));
    expect(result.err, contains('broken.dart'));
  });
}
