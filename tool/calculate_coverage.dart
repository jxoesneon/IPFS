// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final file = File('coverage.lcov');
  if (!file.existsSync()) {
    print('coverage.lcov not found');
    exit(1);
  }

  final lines = file.readAsLinesSync();
  int totalLines = 0;
  int coveredLines = 0;
  bool isIgnoring = false;

  // Track detailed coverage for gap analysis
  final fileCoverage = <String, _FileStat>{};
  _FileStat? currentStat;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      final path = line.substring(3);
      isIgnoring = path.contains('lib/src/proto/generated');
      if (!isIgnoring) {
        currentStat = _FileStat(path);
        fileCoverage[path] = currentStat;
      } else {
        currentStat = null;
      }
    } else if (!isIgnoring && line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final count = int.tryParse(parts[1]) ?? 0;

      totalLines++;
      currentStat?.total++;

      if (count > 0) {
        coveredLines++;
        currentStat?.covered++;
      }
    }
  }

  if (totalLines == 0) {
    print('No executable lines found');
    return;
  }

  final percentage = (coveredLines / totalLines) * 100;
  print('Total Executable Lines: $totalLines');
  print('Covered Lines: $coveredLines');
  print('Global Coverage: ${percentage.toStringAsFixed(2)}%');

  print('\n--- All Non-Generated File Coverage ---');
  final sortedFiles = fileCoverage.values.toList()
    ..sort((a, b) => a.percentage.compareTo(b.percentage));

  for (final stat in sortedFiles) {
    if (stat.percentage <= 100.0) {
      print(
        '${stat.percentage.toStringAsFixed(1)}%\t(${stat.covered}/${stat.total})\t${stat.path}',
      );
    }
  }
}

class _FileStat {
  _FileStat(this.path);
  final String path;
  int total = 0;
  int covered = 0;

  double get percentage => total == 0 ? 0.0 : (covered / total) * 100;
}
