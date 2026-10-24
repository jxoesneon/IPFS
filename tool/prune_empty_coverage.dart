// Removes empty coverage reports from a coverage directory.
//
// `dart test --coverage=coverage` writes one `*.vm.json` report per test
// suite. A suite that never executes — for example the Docker-gated interop
// tests, which are skipped by default in `dart_test.yaml` — produces an
// empty report (`{}`).
//
// `coverage` 1.16 rejects those files outright:
//
//   FormatException: Unrecognized coverage JSON in "...". Expected a
//   {"coverage": [...]} report, but got _Map<String, dynamic>.
//
// `coverage` 1.15 tolerated them, so the behaviour changed when the
// dependency was bumped. Rather than pinning an older `coverage` (or
// special-casing the interop suites), this tool drops the empty reports
// before `coverage:format_coverage` runs.
//
// Usage:
//   dart run tool/prune_empty_coverage.dart [--dir=coverage] [--dry-run]
//
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  var dir = 'coverage';
  var dryRun = false;

  for (final arg in args) {
    if (arg.startsWith('--dir=')) {
      dir = arg.substring('--dir='.length);
    } else if (arg == '--dry-run') {
      dryRun = true;
    }
  }

  final root = Directory(dir);
  if (!root.existsSync()) {
    // Nothing to prune — the coverage run has not produced reports yet.
    print('no coverage directory at $dir; nothing to prune');
    return;
  }

  var removed = 0;
  for (final file in root.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;
    if (!_isEmptyReport(file)) continue;
    removed++;
    if (dryRun) {
      print('would remove ${file.path}');
    } else {
      file.deleteSync();
    }
  }

  print(
    dryRun
        ? 'would remove $removed empty coverage report(s) from $dir'
        : 'removed $removed empty coverage report(s) from $dir',
  );
}

/// Whether the report carries no coverage data.
///
/// A report is treated as empty when it is not a JSON object with a
/// `coverage` list. Reports that fail to parse are left alone: a corrupt
/// file should surface as a real error rather than silently disappearing.
bool _isEmptyReport(File file) {
  final String contents;
  try {
    contents = file.readAsStringSync();
  } catch (_) {
    return false;
  }
  if (contents.trim().isEmpty) return true;

  Object? decoded;
  try {
    decoded = json.decode(contents);
  } catch (_) {
    return false;
  }
  if (decoded is! Map) return false;
  final coverage = decoded['coverage'];
  return coverage is! List || coverage.isEmpty;
}
