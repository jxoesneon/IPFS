import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

class _MockMetricsCollector implements MetricsCollector {
  @override
  void recordSecurityEvent(String type) {}

  @override
  void recordProtocolMetrics(String protocol, Map<String, dynamic> metrics) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Tests that the encrypted keystore is persisted to [IPFSConfig.keystorePath]
/// so named keys (e.g. IPNS signing keys) survive restarts (issue #86).
void main() {
  Logger.root.level = Level.OFF;

  late Directory repoDir;
  late String keystorePath;
  late SecurityConfig config;

  SecurityManager manager() => SecurityManager(
    config,
    _MockMetricsCollector(),
    keystorePath: keystorePath,
  );

  setUp(() {
    repoDir = Directory.systemTemp.createTempSync('ipfs_keystore_');
    keystorePath = '${repoDir.path}/keystore.json';
    config = const SecurityConfig(enableKeyRotation: false);
  });

  tearDown(() {
    if (repoDir.existsSync()) repoDir.deleteSync(recursive: true);
  });

  group('SecurityManager keystore persistence', () {
    test('persists generated keys across instances', () async {
      final first = manager();
      await first.unlockKeystore('correct horse battery staple');
      await first.secureKeystore.generateKey('ipns-key');
      await first.keystoreWritesIdle;

      expect(File(keystorePath).existsSync(), isTrue);

      final second = manager();
      await second.unlockKeystore('correct horse battery staple');
      expect(second.secureKeystore.keyNames, contains('ipns-key'));
    });

    test('persists imported seeds across instances', () async {
      final first = manager();
      await first.unlockKeystore('pw');
      await first.secureKeystore.importSeed(
        'imported',
        Uint8List.fromList(List.generate(32, (i) => i)),
      );
      await first.keystoreWritesIdle;

      final second = manager();
      await second.unlockKeystore('pw');
      expect(second.secureKeystore.keyNames, contains('imported'));
    });

    test('persists removals across instances', () async {
      final first = manager();
      await first.unlockKeystore('pw');
      await first.secureKeystore.generateKey('ephemeral');
      first.secureKeystore.removeKey('ephemeral');
      await first.keystoreWritesIdle;

      final second = manager();
      await second.unlockKeystore('pw');
      expect(second.secureKeystore.keyNames, isNot(contains('ephemeral')));
    });

    test('wrong password cannot unlock a persisted keystore', () async {
      final first = manager();
      await first.unlockKeystore('right');
      await first.secureKeystore.generateKey('k');
      await first.keystoreWritesIdle;

      final second = manager();
      expect(() => second.unlockKeystore('wrong'), throwsA(anything));
    });

    test('mutations queue sequential writes (last state wins)', () async {
      final first = manager();
      await first.unlockKeystore('pw');
      await first.secureKeystore.generateKey('a');
      await first.secureKeystore.generateKey('b');
      first.secureKeystore.removeKey('a');
      await first.keystoreWritesIdle;

      final second = manager();
      await second.unlockKeystore('pw');
      expect(second.secureKeystore.keyNames, contains('b'));
      expect(second.secureKeystore.keyNames, isNot(contains('a')));
    });
  });
}
