// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print('lcov.info not found');
    exit(1);
  }

  int totalLF = 0;
  int totalLH = 0;

  final lines = file.readAsLinesSync();
  String currentFile = '';
  bool skipFile = false;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      // Skip generated files
      if (currentFile.contains('/generated/') ||
          currentFile.endsWith('.pb.dart') ||
          currentFile.endsWith('.pbenum.dart') ||
          currentFile.endsWith('.pbjson.dart') ||
          currentFile.endsWith('.pbserver.dart')) {
        skipFile = true;
      } else {
        skipFile = false;
      }
    } else if (!skipFile) {
      if (line.startsWith('LF:')) {
        totalLF += int.parse(line.substring(3));
      } else if (line.startsWith('LH:')) {
        totalLH += int.parse(line.substring(3));
      }
    }
  }

  if (totalLF == 0) {
    print('No instrumented lines found.');
    return;
  }

  final coverage = (totalLH / totalLF) * 100;
  print(
    'Global Coverage: ${coverage.toStringAsFixed(2)}% ($totalLH / $totalLF)',
  );
}
