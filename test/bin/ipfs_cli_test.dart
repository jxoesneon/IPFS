@Tags(['cli'])
library;

import 'dart:async';
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
      '$repoRoot/test_tmp/cli_${DateTime.now().millisecondsSinceEpoch}_$random',
    );
    dir.createSync(recursive: true);
    return dir.path;
  }

  /// Maximum wall-clock time allowed for a single CLI subprocess.
  ///
  /// `dart run` JIT-compiles the whole package on every invocation, so cold
  /// runs can take tens of seconds (longer on loaded CI runners). Anything
  /// beyond this limit is a real hang: the process is killed rather than
  /// leaving an orphaned child holding locks on the temp data dir.
  final cliTimeout = const Duration(minutes: 2);

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
    // Process.start (not Process.run) so a hung child can be killed.
    // No runInShell: `dart` is an absolute path (Platform.resolvedExecutable),
    // and killing the process directly also reaps the CLI it hosts.
    final process = await Process.start(dart, [
      'run',
      cliPath,
      ...args,
    ], environment: env);
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .listen(stdoutBuffer.write)
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .listen(stderrBuffer.write)
        .asFuture<void>();
    if (input != null) {
      process.stdin.write(input);
    }
    await process.stdin.close();

    final int exitCode;
    try {
      exitCode = await process.exitCode.timeout(cliTimeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await Future.wait([stdoutDone, stderrDone]);
      throw TimeoutException(
        '`ipfs ${args.join(' ')}` exceeded $cliTimeout and was killed.\n'
        'stdout so far: $stdoutBuffer\nstderr so far: $stderrBuffer',
        cliTimeout,
      );
    }
    await Future.wait([stdoutDone, stderrDone]);

    final result = ProcessResult(
      process.pid,
      exitCode,
      stdoutBuffer.toString(),
      stderrBuffer.toString(),
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
        final json =
            jsonDecode(result.stdout as String) as Map<String, dynamic>;
        expect(json['Pins'], contains(cid));
      },
      // This test body runs two CLI subprocesses (`pin` then `unpin`), each
      // of which JIT-compiles the package before executing. The default
      // 30s timeout (2x via the `cli` tag = 60s) is too tight on loaded CI
      // runners, which is what used to look like a "hang".
      timeout: const Timeout(Duration(minutes: 5)),
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

  group('daemon', () {
    late String dataDir;
    late String configPath;

    setUp(() {
      dataDir = tempDataDir();
      configPath = '$dataDir/config.json';
    });

    tearDown(() async {
      await Directory(dataDir).delete(recursive: true);
    });

    Future<int> freePort() async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      return port;
    }

    /// Starts `ipfs daemon` with [config] written to [configPath], waits
    /// until [marker] appears in the output (or the process exits), then
    /// sends SIGTERM and waits for the daemon to shut down.
    ///
    /// `dart bin/ipfs.dart` is used instead of `dart run` so the CLI runs in
    /// a single process: SIGTERM then reaches the VM's signal watchers
    /// directly instead of the `dart run` launcher.
    Future<ProcessResult> runDaemon({
      required String marker,
      required Map<String, dynamic> config,
      int gatewayPort = 0,
    }) async {
      final apiPort = await freePort();
      final cliGatewayPort = gatewayPort == 0 ? await freePort() : gatewayPort;
      final swarmPort = await freePort();
      File(configPath).writeAsStringSync(jsonEncode(config));

      final env = <String, String>{
        ...Platform.environment,
        'IPFS_DATA_DIR': dataDir,
        'IPFS_CONFIG_PATH': configPath,
      };
      final process = await Process.start(dart, [
        cliPath,
        'daemon',
        '--api-addr',
        '/ip4/127.0.0.1/tcp/$apiPort',
        '--gateway-addr',
        '/ip4/127.0.0.1/tcp/$cliGatewayPort',
        '--swarm-addr',
        '/ip4/127.0.0.1/tcp/$swarmPort',
      ], environment: env);

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final markerSeen = Completer<void>();
      void capture(String chunk, StringBuffer buffer) {
        buffer.write(chunk);
        if (!markerSeen.isCompleted &&
            stdoutBuffer.toString().contains(marker)) {
          markerSeen.complete();
        }
      }

      final stdoutDone = process.stdout
          .transform(utf8.decoder)
          .listen((chunk) => capture(chunk, stdoutBuffer))
          .asFuture<void>();
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .listen((chunk) => capture(chunk, stderrBuffer))
          .asFuture<void>();
      await process.stdin.close();

      // Wait for the marker or an early exit; a daemon that never reaches
      // readiness is a failure, not a hang.
      final startupTimeout = const Duration(minutes: 2);
      final earlyExit =
          await Future.any<int>([
            markerSeen.future.then((_) => -1),
            process.exitCode,
          ]).timeout(
            startupTimeout,
            onTimeout: () {
              process.kill(ProcessSignal.sigkill);
              throw TimeoutException(
                '`ipfs daemon` never printed "$marker" within $startupTimeout.\n'
                'stdout so far: $stdoutBuffer\nstderr so far: $stderrBuffer',
                startupTimeout,
              );
            },
          );
      if (earlyExit != -1) {
        await Future.wait([stdoutDone, stderrDone]);
        fail(
          '`ipfs daemon` exited with $earlyExit before printing "$marker".\n'
          'stdout: $stdoutBuffer\nstderr: $stderrBuffer',
        );
      }

      process.kill(ProcessSignal.sigterm);
      final int exitCode;
      try {
        exitCode = await process.exitCode.timeout(const Duration(seconds: 30));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await Future.wait([stdoutDone, stderrDone]);
        fail(
          '`ipfs daemon` did not exit within 30s of SIGTERM.\n'
          'stdout: $stdoutBuffer\nstderr: $stderrBuffer',
        );
      }
      await Future.wait([stdoutDone, stderrDone]);

      return ProcessResult(
        process.pid,
        exitCode,
        stdoutBuffer.toString(),
        stderrBuffer.toString(),
      );
    }

    test('does not start a second gateway when config enables one', () async {
      final configGatewayPort = await freePort();
      final result = await runDaemon(
        marker: 'RPC API running at:',
        config: <String, dynamic>{
          'offline': true,
          'customConfig': <String, dynamic>{},
          'gateway': <String, dynamic>{
            'enabled': true,
            'address': '127.0.0.1',
            'port': configGatewayPort,
          },
        },
      );
      final stdout = result.stdout as String;
      expect(
        stdout,
        contains(
          'Gateway already running from config at '
          '127.0.0.1:$configGatewayPort',
        ),
      );
      // The CLI must not bind --gateway-addr on top of the
      // config-started gateway.
      expect(stdout, isNot(contains('Gateway running at:')));
      expect(stdout, contains('Daemon stopped.'));
      expect(result.exitCode, equals(0));
    }, timeout: const Timeout(Duration(minutes: 4)));

    test(
      'starts the CLI gateway on --gateway-addr when config disables it',
      () async {
        final cliGatewayPort = await freePort();
        final result = await runDaemon(
          marker: 'RPC API running at:',
          gatewayPort: cliGatewayPort,
          config: <String, dynamic>{
            'offline': true,
            'customConfig': <String, dynamic>{},
          },
        );
        final stdout = result.stdout as String;
        expect(
          stdout,
          contains('Gateway running at: http://127.0.0.1:$cliGatewayPort'),
        );
        expect(stdout, isNot(contains('Gateway already running')));
        expect(stdout, contains('Daemon stopped.'));
        expect(result.exitCode, equals(0));
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });
}
