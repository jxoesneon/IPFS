import 'dart:io';

void main() async {
  final lcovFile = File('coverage/lcov.info');
  if (!await lcovFile.exists()) {
    print('Error: coverage/lcov.info not found.');
    return;
  }

  final lines = await lcovFile.readAsLines();
  final coveredFiles = <String, Map<String, int>>{};
  String? currentFile;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      coveredFiles[currentFile] = {'total': 0, 'hit': 0};
    } else if (line.startsWith('DA:') && currentFile != null) {
      final parts = line.substring(3).split(',');
      final count = int.parse(parts[1]);
      coveredFiles[currentFile]!['total'] =
          coveredFiles[currentFile]!['total']! + 1;
      if (count > 0) {
        coveredFiles[currentFile]!['hit'] =
            coveredFiles[currentFile]!['hit']! + 1;
      }
    }
  }

  print('Coverage Report:');
  print('----------------');

  final allLibFiles = Directory('lib/src')
      .listSync(recursive: true)
      .where((e) =>
          e is File && e.path.endsWith('.dart') && !e.path.contains('/proto/'))
      .map((e) => e.absolute.path)
      .toList();

  int totalLines = 0;
  int totalHit = 0;

  // Normalize paths for comparison
  final projectRoot = Directory.current.absolute.path;

  for (final file in allLibFiles) {
    // LCOV paths might be relative or absolute. usually relative to project root or absolute.
    // LCOV in dart often uses relative paths like 'lib/src/...'

    final relPath =
        file.substring(projectRoot.length + 1); // remove /Users/.../IPFS/

    // Check if in coveredFiles (which might be absolute or relative)
    // lcov usually is relative to root: "lib/src/..."

    var stats = coveredFiles[relPath];
    if (stats == null) {
      // Try matching absolute path if lcov has absolute
      stats = coveredFiles[file];
    }

    // Also try simple filename match if needed, but path is better.

    if (stats == null) {
      print('[   0.0%] $relPath (No coverage data)');
    } else {
      final total = stats['total']!;
      final hit = stats['hit']!;
      totalLines += total;
      totalHit += hit;
      final coverage = total == 0 ? 100.0 : (hit / total * 100);
      print('[${coverage.toStringAsFixed(1).padLeft(6)}%] $relPath');
    }
  }

  print('----------------');
  final totalCoverage = totalLines == 0 ? 0.0 : (totalHit / totalLines * 100);
  print(
      'Total Coverage (excluding proto): ${totalCoverage.toStringAsFixed(1)}%');
}
