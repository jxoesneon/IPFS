// ignore_for_file: avoid_print

import 'dart:io';

void main() async {
  final file = File('coverage/lcov.info');
  if (!await file.exists()) {
    print('lcov.info not found');
    return;
  }

  final lines = await file.readAsLines();
  String? currentFile;
  int foundLines = 0;
  int hitLines = 0;

  Map<String, List<int>> stats = {};

  int totalFound = 0;
  int totalHit = 0;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      if (currentFile.contains('generated') ||
          currentFile.endsWith('.pb.dart') ||
          currentFile.endsWith('.pbenum.dart')) {
        currentFile = null;
      }
    } else if (line.startsWith('LF:')) {
      foundLines = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hitLines = int.parse(line.substring(3));
    } else if (line == 'end_of_record') {
      if (currentFile != null) {
        stats[currentFile] = [hitLines, foundLines];
        totalHit += hitLines;
        totalFound += foundLines;
      }
    }
  }

  print('Coverage Summary:');
  print('----------------');
  final sortedKeys = stats.keys.toList()..sort();
  for (final key in sortedKeys) {
    final s = stats[key]!;
    final percent = s[1] == 0 ? 100.0 : (s[0] / s[1] * 100);
    if (percent < 90) {
      print('${percent.toStringAsFixed(1)}% - $key (${s[0]}/${s[1]})');
    }
  }

  final totalPercent = totalFound == 0 ? 100.0 : (totalHit / totalFound * 100);
  print('----------------');
  print(
    'TOTAL COVERAGE: ${totalPercent.toStringAsFixed(2)}% ($totalHit/$totalFound)',
  );
}
