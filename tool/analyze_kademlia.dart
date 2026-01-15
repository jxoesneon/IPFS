// ignore_for_file: avoid_print
import 'dart:io';

void main(List<String> args) {
  final file = File(args[0]);
  final lines = file.readAsLinesSync();

  String? currentFile;
  int totalLines = 0;
  int hitLines = 0;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
    } else if (line == 'end_of_record') {
      if (currentFile != null &&
          currentFile.contains('kademlia_routing_table.dart')) {
        print('File: $currentFile');
        print('Lines Found: $totalLines');
        print('Lines Hit: $hitLines');
        print('Coverage: ${(hitLines / totalLines * 100).toStringAsFixed(2)}%');
      }
      currentFile = null;
      totalLines = 0;
      hitLines = 0;
    } else if (currentFile != null && line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final hits = int.parse(parts[1]);
      totalLines++;
      if (hits > 0) hitLines++;
    }
  }
}
