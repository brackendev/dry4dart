import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'declaration.dart';
import 'discovery.dart';
import 'fingerprint.dart';
import 'matcher.dart';
import 'normalize.dart';
import 'report.dart';

// Must be kept in sync with the version field in pubspec.yaml.
const _version = '0.2.0';

/// Runs the dry4dart pipeline against [arguments] and returns a process exit
/// code.
///
/// Non-option arguments are interpreted as file or directory paths to scan.
/// Pass `--help` to see the available options.
///
/// Returns:
///
/// - `0` on success, whether or not candidate pairs are reported.
/// - `1` when `--fail-on-findings` is set and at least one candidate pair is
///   reported.
/// - `64` for argument and usage errors (`EX_USAGE`).
/// - `66` when an input path does not exist (`EX_NOINPUT`).
///
/// [out] and [err] default to [stdout] and [stderr]. Tests can supply
/// alternate sinks to capture output.
int runCli(List<String> arguments, {IOSink? out, IOSink? err}) {
  final stdoutSink = out ?? stdout;
  final stderrSink = err ?? stderr;

  final parser = _buildParser();
  final ArgResults parsed;
  try {
    parsed = parser.parse(arguments);
  } on FormatException catch (e) {
    stderrSink.writeln(e.message);
    stderrSink.writeln(_usage(parser));
    return 64;
  }

  if (parsed['help'] as bool) {
    stdoutSink.writeln(_usage(parser));
    return 0;
  }
  if (parsed['version'] as bool) {
    stdoutSink.writeln('dry4dart $_version');
    return 0;
  }

  final paths = parsed.rest;
  if (paths.isEmpty) {
    stderrSink.writeln('Specify at least one file or directory to scan.');
    stderrSink.writeln(_usage(parser));
    return 64;
  }

  final double threshold;
  final int minLines;
  final int minNodes;
  try {
    threshold = double.parse(parsed['threshold'] as String);
    minLines = int.parse(parsed['min-lines'] as String);
    minNodes = int.parse(parsed['min-nodes'] as String);
  } on FormatException catch (e) {
    stderrSink.writeln('Invalid numeric option: ${e.message}');
    return 64;
  }
  if (threshold < 0 || threshold > 1) {
    stderrSink.writeln('--threshold must be between 0.0 and 1.0.');
    return 64;
  }

  final format = _resolveFormat(parsed, stderrSink);
  if (format == null) return 64;

  final discoveryOptions = DiscoveryOptions(
    includeGenerated: parsed['include-generated'] as bool,
  );

  final List<File> files;
  try {
    files = discoverDartFiles(paths, discoveryOptions);
  } on FileSystemException catch (e) {
    stderrSink.writeln('${e.message}: ${e.path}');
    return 66;
  } on ArgumentError catch (e) {
    stderrSink.writeln(e.message);
    return 64;
  }

  final declarations = <Declaration>[];
  final cwd = Directory.current.path;
  var nextIndex = 0;
  for (final file in files) {
    final source = file.readAsStringSync();
    final relativePath = p.relative(file.path, from: cwd);
    final parse = parseDartSource(source, file.path);
    if (parse.errors.isNotEmpty) {
      stderrSink.writeln(
        'warning: $relativePath has ${parse.errors.length} parse error(s). '
        'Analysis may be incomplete.',
      );
    }
    for (final cd in parse.declarations) {
      final norm = normalize(cd.node);
      final fp = collectFingerprints(norm);
      declarations.add(
        Declaration(
          index: nextIndex++,
          relativePath: relativePath,
          startLine: cd.startLine,
          endLine: cd.endLine,
          fingerprints: fp.fingerprints,
          nodeCount: fp.nodeCount,
        ),
      );
    }
  }

  final pairs = findCandidates(
    declarations,
    MatcherOptions(
      threshold: threshold,
      minLines: minLines,
      minNodes: minNodes,
    ),
  );

  final report = formatReport(pairs, format);
  if (format == ReportFormat.json) {
    stdoutSink.writeln(report);
  } else if (report.isNotEmpty) {
    stdoutSink.write(report);
  }

  if (parsed['fail-on-findings'] as bool && pairs.isNotEmpty) return 1;
  return 0;
}

ArgParser _buildParser() {
  return ArgParser()
    ..addOption(
      'threshold',
      defaultsTo: '0.82',
      help: 'Minimum structural similarity score (0.0-1.0).',
    )
    ..addOption(
      'min-lines',
      defaultsTo: '4',
      help: 'Minimum source lines in a candidate declaration.',
    )
    ..addOption(
      'min-nodes',
      defaultsTo: '20',
      help: 'Minimum normalized syntax nodes in a candidate declaration.',
    )
    ..addOption(
      'format',
      defaultsTo: 'text',
      allowed: ['text', 'json'],
      help: 'Output format.',
    )
    ..addFlag('json', negatable: false, help: 'Same as --format json.')
    ..addFlag('text', negatable: false, help: 'Same as --format text.')
    ..addFlag(
      'include-generated',
      negatable: false,
      help:
          'Include generated files (.g.dart, .freezed.dart, .mocks.dart, '
          '.config.dart, .gr.dart) in the scan.',
    )
    ..addFlag(
      'fail-on-findings',
      negatable: false,
      help: 'Exit with status 1 when any candidate is reported.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help text.')
    ..addFlag('version', negatable: false, help: 'Show the dry4dart version.');
}

ReportFormat? _resolveFormat(ArgResults parsed, IOSink err) {
  final jsonFlag = parsed['json'] as bool;
  final textFlag = parsed['text'] as bool;
  final formatExplicit = parsed.wasParsed('format');
  final formatOption = parsed['format'] as String;

  if (jsonFlag && textFlag) {
    err.writeln('--json and --text cannot be combined.');
    return null;
  }
  if (jsonFlag && formatExplicit && formatOption != 'json') {
    err.writeln('--json conflicts with --format $formatOption.');
    return null;
  }
  if (textFlag && formatExplicit && formatOption != 'text') {
    err.writeln('--text conflicts with --format $formatOption.');
    return null;
  }

  if (jsonFlag) return ReportFormat.json;
  if (textFlag) return ReportFormat.text;
  return formatOption == 'json' ? ReportFormat.json : ReportFormat.text;
}

String _usage(ArgParser parser) {
  final buf = StringBuffer()
    ..writeln('dry4dart - find candidate duplicate Dart code.')
    ..writeln()
    ..writeln('Usage: dart run dry4dart [options] <file-or-directory> ...')
    ..writeln()
    ..write(parser.usage);
  return buf.toString();
}
