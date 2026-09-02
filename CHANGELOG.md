# Changelog

## [Unreleased]

## [0.2.0]

### Changed

- dry4dart now requires `package:analyzer` 13.1.0 through 14.x and Dart 3.11 or later. It no longer resolves with analyzer 9 through 12 or with Dart 3.9 and 3.10.
- Scores for declarations that contain labeled statements can differ slightly from 0.1.0, because the analyzer 13 syntax tree no longer represents a label as an identifier. All other fingerprints are unchanged.
- Installation instructions now add dry4dart from the Git repository, because the package is not published on pub.dev.

### Added

- Classes declared with a Dart 3.13 primary constructor are scanned. A primary constructor body written as `this : ... { ... }` is compared like a regular constructor. A header-only primary constructor is not a candidate.

## [0.1.0]

- First release.
