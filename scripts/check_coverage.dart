import 'dart:io';

void main() async {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print('coverage/lcov.info not found');
    return;
  }

  final lines = await file.readAsLines();
  final coverage = <String, _FileCoverage>{};
  String? currentFile;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      coverage[currentFile] = _FileCoverage();
    } else if (line.startsWith('DA:')) {
      // DA:line,count
      final parts = line.substring(3).split(',');
      final count = int.parse(parts[1]);
      if (coverage.containsKey(currentFile)) {
        coverage[currentFile]!.totalLines++;
        if (count > 0) {
          coverage[currentFile]!.coveredLines++;
        }
      }
    }
  }

  print('Coverage Report:');
  print('----------------------------------------');

  var totalLines = 0;
  var totalCovered = 0;

  final sortedKeys = coverage.keys.toList()
    ..sort((a, b) => coverage[a]!.percent.compareTo(coverage[b]!.percent));

  for (final file in sortedKeys) {
    final cov = coverage[file]!;
    totalLines += cov.totalLines;
    totalCovered += cov.coveredLines;
    print(
        '${cov.percent.toStringAsFixed(1)}% - $file (${cov.coveredLines}/${cov.totalLines})');
  }

  print('----------------------------------------');
  final totalPercent = (totalCovered / totalLines) * 100;
  print(
      'Total Coverage: ${totalPercent.toStringAsFixed(1)}% ($totalCovered/$totalLines)');
}

class _FileCoverage {
  int totalLines = 0;
  int coveredLines = 0;
  double get percent => totalLines == 0 ? 0 : (coveredLines / totalLines) * 100;
}
