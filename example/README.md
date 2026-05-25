# dry4dart examples

dry4dart is a command-line tool. The examples below cover the most common
invocations after adding the package as a development dependency:

```bash
dart pub add --dev dry4dart
```

## Scan a directory

Walks every `.dart` file under `lib/` and reports candidate duplicates above
the default threshold of `0.82`:

```bash
dart run dry4dart lib
```

## Scan multiple paths

Directory and file paths can be mixed. Each `.dart` file is included in the
same duplication search:

```bash
dart run dry4dart lib bin test/integration_test.dart
```

## Loosen the thresholds

Lower `--threshold` or `--min-lines` to surface smaller or less-similar pairs:

```bash
dart run dry4dart --threshold 0.7 --min-lines 6 lib
```

## Emit JSON for tooling

`--json` writes a machine-readable report. Each candidate carries the score,
file paths, line ranges, and node counts:

```bash
dart run dry4dart --json lib > duplicates.json
```

## Fail continuous integration on findings

`--fail-on-findings` exits with status `1` when at least one candidate pair is
reported. The default exit status is `0` so the tool remains non-fatal during
interactive use:

```bash
dart run dry4dart --fail-on-findings lib
```

## Include generated files

Generated files (`.g.dart`, `.freezed.dart`, `.mocks.dart`, `.config.dart`,
`.gr.dart`) are excluded by default. Opt back in with `--include-generated`:

```bash
dart run dry4dart --include-generated lib
```

## Example text output

```text
DUPLICATE score=0.89
  lib/billing/invoice.dart:12-32
  lib/billing/receipt.dart:40-60
```

## Example JSON output

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
