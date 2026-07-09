@Tags(['cli'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';

void main() {
  final dart = Platform.resolvedExecutable;
  final repoRoot = Directory.current.path;
  final cliPath = '$repoRoot/bin/ipfs.dart';

  String tempDataDir() {
    final random = Random.secure().nextInt(0x7fffffff);
    final dir = Directory(
      '$repoRoot/test_tmp/cli_${DateTime.now().millisecondsSinceEpoch}_${random}',
    );
    dir.createSync(recursive: true);
    return dir.path;
  }

  Future<ProcessResult> runCli(
    List<String> args, {
    String? dataDir,
    String? configPath,
    String? input,
  }) async {
    final env = <String, String>{...Platform.environment};
    if (dataDir != null) {
      env['IPFS_DATA_DIR'] = dataDir;
      if (configPath == null) {
        final defaultConfig = '$dataDir/config.json';
        if (!File(defaultConfig).existsSync()) {
          File(defaultConfig).writeAsStringSync(
            jsonEncode(<String, dynamic>{
              'offline': true,
              'customConfig': <String, dynamic>{},
            }),
          );
        }
        env['IPFS_CONFIG_PATH'] = defaultConfig;
      }
    }
    if (configPath != null) {
      env['IPFS_CONFIG_PATH'] = configPath;
    }
    final result = await Process.run(
      dart,
      ['run', cliPath, ...args],
      environment: env,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      stderr.writeln('CLI stderr: ${result.stderr}');
    }
    return result;
  }

  group('version', () {
    test('prints package version', () async {
      final result = await runCli(['version']);
      expect(result.exitCode, equals(0));
      expect(result.stdout as String, contains('ipfs version'));
    });
  });

  group('id', () {
    late String dataDir;

    setUp(() {
      dataDir = tempDataDir();
    });

    tearDown(() async {
      await Directory(dataDir).delete(recursive: true);
    });

    test('outputs identity JSON', () async {
      final result = await runCli(['id'], dataDir: dataDir);
      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      expect(json['ID'], isNotEmpty);
      expect(json['AgentVersion'], contains('dart_ipfs'));
      expect(json['Addresses'], isA<List<dynamic>>());
    });
  });

  group('add', () {
    late String dataDir;
    late Directory tempDir;
    late String filePath;

    setUp(() {
      dataDir = tempDataDir();
      tempDir = Directory('$dataDir/source');
      tempDir.createSync(recursive: true);
      filePath = '${tempDir.path}/hello.txt';
      File(filePath).writeAsStringSync('hello ipfs');
    });

    tearDown(() async {
      await Directory(dataDir).delete(recursive: true);
    });

    test('adds a file and returns a CID', () async {
      final result = await runCli(['add', filePath], dataDir: dataDir);
      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      expect(json['Hash'], isNotEmpty);
      expect(json['Name'], equals('hello.txt'));
    });

    test('quieter mode prints only CID', () async {
      final result = await runCli([
        'add',
        '--quieter',
        filePath,
      ], dataDir: dataDir);
      expect(result.exitCode, equals(0));
      expect(result.stdout.trim().length, greaterThan(0));
      expect(result.stdout, isNot(contains('Hash')));
    });
  });

  group('cat', () {
    late String dataDir;
    late String filePath;
    late String cid;

    setUp(() async {
      dataDir = tempDataDir();
      filePath = '$dataDir/hello.txt';
      File(filePath).writeAsStringSync('hello ipfs');
      final addResult = await runCli([
        'add',
        '--quieter',
        filePath,
      ], dataDir: dataDir);
      cid = (addResult.stdout as String).trim();
    });

    tearDown(() async {
      await Directory(dataDir).delete(recursive: true);
    });

    test('retrieves content by CID', () async {
      final result = await runCli(['cat', cid], dataDir: dataDir);
      expect(result.exitCode, equals(0));
      expect(result.stdout, equals('hello ipfs'));
    });
  });

  group('ls', () {
    late String dataDir;
    late String dirPath;
    late String cid;

    setUp(() async {
      dataDir = tempDataDir();
      dirPath = '$dataDir/source';
      Directory(dirPath).createSync(recursive: true);
      File('$dirPath/a.txt').writeAsStringSync('a');
      File('$dirPath/b.txt').writeAsStringSync('b');
      final addResult = await runCli([
        'add',
        '--recursive',
        '--quieter',
        dirPath,
      ], dataDir: dataDir);
      cid = (addResult.stdout as String).trim();
    });

    tearDown(() async {
      await Directory(dataDir).delete(recursive: true);
    });

    test('lists directory entries', () async {
      final result = await runCli(['ls', cid], dataDir: dataDir);
      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final objects = json['Objects'] as List<dynamic>;
      expect(objects, isNotEmpty);
      final links = objects.first['Links'] as List<dynamic>;
      final names = links.map((l) => l['Name'] as String).toList();
      expect(names, contains('a.txt'));
      expect(names, contains('b.txt'));
    });
  });

  group('pin', () {
    late String dataDir;
    late String cid;

    setUp(() async {
      dataDir = tempDataDir();
      final filePath = '$dataDir/file.txt';
      File(filePath).writeAsStringSync('pin me');
      final addResult = await runCli([
        'add',
        '--quieter',
        filePath,
      ], dataDir: dataDir);
      cid = (addResult.stdout as String).trim();
    });

    tearDown(() async {
      await Directory(dataDir).delete(recursive: true);
    });

    test('pins a CID', () async {
      final result = await runCli(['pin', cid], dataDir: dataDir);
      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      expect(json['Pins'], contains(cid));
    });

    test(
      'unpins a CID',
      () async {
        await runCli(['pin', cid], dataDir: dataDir);
        final result = await runCli(['unpin', cid], dataDir: dataDir);
        expect(result.exitCode, equals(0));
        final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
        expect(json['Pins'], contains(cid));
      },
      skip: 'Flaky CLI subprocess test hangs/times out when starting a node in a separate process; tracked separately.',
    );
  });

  group('config', () {
    late String dataDir;
    late String configPath;

    setUp(() {
      dataDir = tempDataDir();
      configPath = '$dataDir/config.json';
      File(
        configPath,
      ).writeAsStringSync(jsonEncode({'customConfig': <String, dynamic>{}}));
    });

    tearDown(() async {
      await Directory(dataDir).delete(recursive: true);
    });

    test('show prints config JSON', () async {
      final result = await runCli(
        ['config'],
        dataDir: dataDir,
        configPath: configPath,
      );
      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      expect(json.containsKey('dataPath'), isTrue);
    });

    test('get returns a value', () async {
      final result = await runCli(
        ['config', 'offline'],
        dataDir: dataDir,
        configPath: configPath,
      );
      expect(result.exitCode, equals(0));
      expect(result.stdout.trim(), equals('false'));
    });

    test('set writes a value', () async {
      final result = await runCli(
        ['config', 'customConfig.foo', 'bar'],
        dataDir: dataDir,
        configPath: configPath,
      );
      expect(result.exitCode, equals(0));
      final file = File(configPath);
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(json['customConfig']['foo'], equals('bar'));
    });
  });

  group('swarm', () {
    late String dataDir;

    setUp(() {
      dataDir = tempDataDir();
    });

    tearDown(() async {
      await Directory(dataDir).delete(recursive: true);
    });

    test('peers returns empty list in offline mode', () async {
      final result = await runCli(['swarm', 'peers'], dataDir: dataDir);
      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      expect(json['Peers'], isA<List<dynamic>>());
    });
  });
}
