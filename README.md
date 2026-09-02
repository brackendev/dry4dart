# dry4dart

A command-line tool that finds candidate duplicate Dart code across files and directories. Reports fuzzy structural matches by file and line range so developers can review similar declarations before refactoring.

## Features

- Compares top-level functions, methods, constructors, getters, and setters
- Structural matching via normalized syntax nodes and Jaccard similarity
- Text and JSON output formats
- Excludes generated files (`.g.dart`, `.freezed.dart`, `.mocks.dart`, `.config.dart`, `.gr.dart`) by default
- Optional non-zero exit when any candidate is found, for continuous integration use

## Overview

dry4dart compares top-level Dart declarations by first converting each declaration into normalized syntax nodes. The normalized form is then walked to collect a set of structural fingerprints, one for the whole declaration and one for each nested subexpression.

Similarity is Jaccard similarity over those fingerprint sets:

```text
score = shared fingerprints / all fingerprints seen in either declaration
```

A score of `1.0` means the normalized structures have the same fingerprint set. Lower scores mean the declarations still share structure, but each declaration also has some structure the other does not. The default `--threshold 0.82` reports candidates whose normalized structures are close enough to be worth review.

For example, these two functions score `1.0`: their names, local names, predicates, and mapped functions differ, but those incidental symbols are removed by normalization and the retained structure is identical.

```dart
List<int> alpha(List<int> xs) {
  final ys = xs.where(isOdd);
  return ys.map((x) => x + 1).toList();
}

List<int> beta(List<int> items) {
  final kept = items.where(isEven);
  return kept.map((x) => x + 2).toList();
}
```

Scores below `1.0` reflect smaller divergences. Two functions that match except for one extra local binding typically score around `0.89`, because the extra binding contributes a few unique fingerprints to the Jaccard union.

## Installation

dry4dart is not published on pub.dev. Install it from the Git repository as a development dependency so each project pins the tool and resolves `analyzer` against the same constraints as the project itself.

```bash
dart pub add --dev dry4dart --git-url https://github.com/brackendev/dry4dart.git --git-ref master
dart run dry4dart lib
```

`dart pub add --dev` writes the entry into the `dev_dependencies` section of `pubspec.yaml`. If editing `pubspec.yaml` by hand, the resulting entry is:

```yaml
dev_dependencies:
  dry4dart:
    git:
      url: https://github.com/brackendev/dry4dart.git
      ref: master
```

dry4dart requires Dart 3.11 or later. It depends on `package:analyzer` to parse Dart source. Because analyzer changes its public syntax tree across major versions, dry4dart supports a bounded analyzer range, currently 13.1.0 through 14.x. See `pubspec.yaml` in this repository for the current constraint if dependency resolution fails in a project that already pins analyzer indirectly.

For ad-hoc scans where a development dependency is impractical, install dry4dart globally. A globally installed `analyzer` may not match the project being scanned, which can cause newer language features to misparse.

```bash
dart pub global activate --source git https://github.com/brackendev/dry4dart.git --git-ref master
dry4dart lib
```

## Usage

```bash
dart run dry4dart [options] [file-or-directory ...]
```

A globally activated install exposes the same command as `dry4dart` without the `dart run` prefix.

| Option | Description |
|--------|-------------|
| `--threshold N` | Minimum structural similarity score. Default `0.82`. |
| `--min-lines N` | Minimum source lines in a candidate declaration. Default `4`. |
| `--min-nodes N` | Minimum normalized syntax nodes in a candidate declaration. Default `20`. |
| `--format F` | Output format: `text` or `json`. Default `text`. |
| `--json` | Same as `--format json`. |
| `--text` | Same as `--format text`. |
| `--include-generated` | Include `.g.dart`, `.freezed.dart`, `.mocks.dart`, `.config.dart`, and `.gr.dart` files. |
| `--fail-on-findings` | Exit with status `1` when any candidate is reported. |
| `--help` | Show usage information. |
| `--version` | Show the dry4dart version. |

By default, findings do not fail the command. Use `--fail-on-findings` for continuous integration checks.

Examples:

```bash
dart run dry4dart lib
dart run dry4dart lib/foo.dart lib/bar.dart
dart run dry4dart --json --threshold 0.9 lib
```

All paths in one invocation share the same search set. Directory arguments expand recursively to `.dart` files, so `dart run dry4dart lib test/foo_test.dart` compares `test/foo_test.dart` with every Dart file under `lib` and with any other files in the same invocation.

Default text output is intended for quick reading:

```text
DUPLICATE score=0.89
  lib/billing/invoice.dart:12-32
  lib/billing/receipt.dart:40-60
```

JSON output is intended for tools:

```json
{
  "candidates": [
    {
      "score": 0.8909090909090909,
      "left": {"file": "lib/billing/invoice.dart", "startLine": 12, "endLine": 32},
      "right": {"file": "lib/billing/receipt.dart", "startLine": 40, "endLine": 60},
      "leftNodes": 88,
      "rightNodes": 91
    }
  ]
}
```

## Development

```bash
dart test
```

## Issues

Report bugs or request features at [github.com/brackendev/dry4dart/issues](https://github.com/brackendev/dry4dart/issues).

## Related project

Inspired by [dry4clj](https://github.com/unclebob/dry4clj).
