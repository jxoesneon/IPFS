// ignore_for_file: avoid_print

import 'dart:io';

/// Reports uncovered lines among lines changed relative to a base ref.
///
/// Usage:
///   dart run tool/changed_line_coverage.dart \
///     --base=origin/main \
///     --lcov=coverage/lcov.info
///
/// Only `.dart` files under `lib/` and `packages/*/lib/` are considered.
/// Exits non-zero when changed executable lines are uncovered.
///
/// Standard `coverage:ignore-*` markers are honored the same way
/// `format_coverage --check-ignore` honors them — this matters for
/// platform-conditional code (e.g. web-only files behind conditional
/// imports) that never produces an lcov record under VM test runs.
void main(List<String> args) {
  var base = 'origin/main';
  var lcovPath = 'coverage/lcov.info';
  var prefix = '';
  var verbose = true;

  for (final arg in args) {
    if (arg.startsWith('--base=')) {
      base = arg.substring('--base='.length);
    } else if (arg.startsWith('--lcov=')) {
      lcovPath = arg.substring('--lcov='.length);
    } else if (arg.startsWith('--prefix=')) {
      prefix = arg.substring('--prefix='.length);
    } else if (arg == '--quiet') {
      verbose = false;
    }
  }

  if (!File(lcovPath).existsSync()) {
    stderr.writeln('lcov file not found: $lcovPath');
    exit(2);
  }

  final uncoveredByFile = _parseUncoveredLines(lcovPath, prefix);
  final changedByFile = _parseChangedLines(base);

  var totalChanged = 0;
  var totalUncovered = 0;
  final report = <String, List<int>>{};

  for (final entry in changedByFile.entries) {
    final file = entry.key;
    if (!_isCoverable(file, prefix)) continue;
    final ignored = _ignoredLines(file);
    if (ignored == null) continue; // coverage:ignore-file
    final changed = entry.value.difference(ignored);
    if (changed.isEmpty) continue;
    totalChanged += changed.length;

    if (!uncoveredByFile.containsKey(file)) {
      // No coverage record — only executable-looking changed lines count
      // (export/import barrels legitimately have no instrumentable lines).
      final missed =
          changed.where((n) => _looksExecutable(_sourceLine(file, n))).toList()
            ..sort();
      if (missed.isNotEmpty) {
        report[file] = missed;
        totalUncovered += missed.length;
      }
      continue;
    }
    // Even with a coverage record the VM emits DA rows for lines that carry
    // no statement (closing parens, signature fragments, doc comments) and
    // can never be hit — filter those the same way as no-record files.
    final missed =
        changed
            .where(
              (n) =>
                  uncoveredByFile[file]!.contains(n) &&
                  _looksExecutable(_sourceLine(file, n)),
            )
            .toList()
          ..sort();
    if (missed.isNotEmpty) {
      report[file] = missed;
      totalUncovered += missed.length;
    }
  }

  final pct = totalChanged == 0
      ? 100.0
      : (100.0 * (totalChanged - totalUncovered) / totalChanged);
  print(
    'Changed-line coverage vs $base: '
    '${totalChanged - totalUncovered}/$totalChanged covered '
    '(${pct.toStringAsFixed(1)}%)',
  );
  if (verbose && report.isNotEmpty) {
    for (final entry in report.entries) {
      print('  ${entry.key}: ${entry.value.join(', ')}');
    }
  }

  if (totalUncovered > 0) {
    exit(1);
  }
}

final _fileLines = <String, List<String>>{};
final _ignoredLinesCache = <String, Set<int>?>{};

final _ignoreStart = RegExp(r'//\s*coverage:ignore-start[\w\d\s]*$');
final _ignoreEnd = RegExp(r'//\s*coverage:ignore-end[\w\d\s]*$');
final _ignoreLine = RegExp(r'//\s*coverage:ignore-line[\w\d\s]*$');
final _ignoreFile = RegExp(r'//\s*coverage:ignore-file[\w\d\s]*$');

/// Returns the set of 1-based line numbers excluded by `coverage:ignore-*`
/// markers in [file], or `null` when `coverage:ignore-file` excludes the
/// whole file. Mirrors `format_coverage --check-ignore` semantics.
Set<int>? _ignoredLines(String file) {
  if (_ignoredLinesCache.containsKey(file)) return _ignoredLinesCache[file];
  List<String> lines;
  try {
    lines = _fileLines.putIfAbsent(file, () => File(file).readAsLinesSync());
  } catch (_) {
    lines = const [];
  }
  final ignored = <int>{};
  var start = -1;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains(_ignoreFile)) {
      return _ignoredLinesCache[file] = null;
    }
    if (start < 0) {
      if (line.contains(_ignoreLine)) ignored.add(i + 1);
      if (line.contains(_ignoreStart)) start = i + 1;
    } else if (line.contains(_ignoreEnd)) {
      for (var n = start; n <= i + 1; n++) {
        ignored.add(n);
      }
      start = -1;
    }
  }
  return _ignoredLinesCache[file] = ignored;
}

/// Returns the 1-based [lineNo] of [file] from disk, or '' when unreadable.
String _sourceLine(String file, int lineNo) {
  try {
    final lines = _fileLines.putIfAbsent(
      file,
      () => File(file).readAsLinesSync(),
    );
    return lineNo >= 1 && lineNo <= lines.length ? lines[lineNo - 1] : '';
  } catch (_) {
    return '';
  }
}

/// Heuristic: does this source line contain executable code?
///
/// Excludes blanks, comments, pure directive lines (import/export/part), and
/// VM-coverage artifacts: punctuation-only continuation lines (`);`, `}`) and
/// multi-line signature fragments (`T name(params) {`) get DA rows that can
/// never be hit — a dead function still flags through its body lines.
bool _looksExecutable(String line) {
  final t = line.trim();
  if (t.isEmpty ||
      t.startsWith('//') ||
      t.startsWith('/*') ||
      t.startsWith('*')) {
    return false;
  }
  if (RegExp(r'^(import|export|part|library)\b').hasMatch(t)) return false;
  if (RegExp(r'^[{}()\[\];,.]*$').hasMatch(t)) return false;
  // `const` declarations are compile-time — the VM still emits DA rows that
  // can never report a hit (e.g. the package version constant).
  if (RegExp(r'^(static\s+)?const\s').hasMatch(t)) return false;
  if (t.endsWith('{') &&
      !t.contains('=') &&
      RegExp(r'^\w[\w<>\[\]?]*\s+\w+\s*\(').hasMatch(t) &&
      !RegExp(
        r'^(if|for|while|switch|return|throw|await|yield|assert|case)\b',
      ).hasMatch(t)) {
    return false;
  }
  return true;
}

bool _isCoverable(String path, String prefix) {
  final p = path.replaceAll('\\', '/');
  // With --prefix, only files inside that package are gated (each package
  // enforces coverage of its own lib/ against its own coverage run).
  if (prefix.isNotEmpty) {
    return p.startsWith('$prefix/lib/');
  }
  return p.startsWith('lib/');
}

/// Parses an lcov file into a map of repo-relative path -> uncovered lines.
///
/// When [prefix] is set, bare `lib/`-relative source paths (produced when
/// coverage is collected inside a sub-package) are prefixed so they match
/// repo-root diff paths.
Map<String, Set<int>> _parseUncoveredLines(
  String lcovPath, [
  String prefix = '',
]) {
  final result = <String, Set<int>>{};
  String? current;
  for (final line in File(lcovPath).readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      var path = line.substring(3).replaceAll('\\', '/');
      // Normalize to repo-relative paths.
      final pkgIdx = path.indexOf('/packages/');
      final libIdx = path.indexOf('/lib/');
      if (pkgIdx >= 0) {
        path = path.substring(pkgIdx + 1);
      } else if (libIdx >= 0) {
        path = path.substring(libIdx + 1);
      }
      if (prefix.isNotEmpty && !path.startsWith('packages/')) {
        path = '$prefix/$path';
      }
      current = path;
      result.putIfAbsent(current, () => <int>{});
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      final lineNo = int.tryParse(parts[0]);
      final hits = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      if (lineNo != null && hits == 0) {
        result[current]!.add(lineNo);
      }
    }
  }
  return result;
}

/// Parses `git diff --unified=0 <base>` into changed new-side line numbers.
Map<String, Set<int>> _parseChangedLines(String base) {
  final proc = Process.runSync('git', [
    'diff',
    '--unified=0',
    '--diff-filter=ACMR',
    base,
    '--',
    '*.dart',
  ]);
  if (proc.exitCode != 0) {
    stderr.writeln('git diff failed: ${proc.stderr}');
    exit(2);
  }

  final result = <String, Set<int>>{};
  String? currentFile;
  final hunkRe = RegExp(r'@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@');

  for (final line in (proc.stdout as String).split('\n')) {
    if (line.startsWith('+++ b/')) {
      currentFile = line.substring(6);
      result.putIfAbsent(currentFile, () => <int>{});
    } else if (line.startsWith('@@') && currentFile != null) {
      final m = hunkRe.firstMatch(line);
      if (m == null) continue;
      final start = int.parse(m.group(1)!);
      final count = int.tryParse(m.group(2) ?? '1') ?? 1;
      for (var i = start; i < start + count; i++) {
        result[currentFile]!.add(i);
      }
    }
  }
  return result;
}
