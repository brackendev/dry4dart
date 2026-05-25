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

  test('runCli warns on parse errors and continues', () async {
    File('${tmp.path}/broken.dart').writeAsStringSync('int x =\n');
    final result = await runWithCapture([tmp.path]);
    expect(result.code, equals(0));
    expect(result.err, contains('warning'));
    expect(result.err, contains('broken.dart'));
  });
}
