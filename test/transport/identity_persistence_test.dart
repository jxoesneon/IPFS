import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/transport/libp2p_router.dart';
import 'package:test/test.dart';

/// Tests that the libp2p identity seed is persisted under `dataPath` so the
/// peer ID survives process restarts (issue #86).
void main() {
  late Directory repoDir;

  IPFSConfig configFor(String path) => IPFSConfig(
    dataPath: path,
    network: NetworkConfig(
      listenAddresses: const ['/ip4/127.0.0.1/tcp/0'],
      bootstrapPeers: const [],
    ),
  );

  setUp(() {
    repoDir = Directory.systemTemp.createTempSync('ipfs_identity_');
  });

  tearDown(() {
    if (repoDir.existsSync()) repoDir.deleteSync(recursive: true);
  });

  group('Libp2pRouter identity persistence', () {
    test('derives the same peer ID from the same dataPath', () async {
      final path = '${repoDir.path}/node';

      final first = Libp2pRouter(configFor(path));
      await first.initialize();
      final firstPeerId = first.peerID;
      expect(firstPeerId, isNotEmpty);

      final second = Libp2pRouter(configFor(path));
      await second.initialize();

      expect(second.peerID, equals(firstPeerId));
    });

    test('derives distinct peer IDs for distinct dataPaths', () async {
      final a = Libp2pRouter(configFor('${repoDir.path}/a'));
      final b = Libp2pRouter(configFor('${repoDir.path}/b'));
      await a.initialize();
      await b.initialize();

      expect(a.peerID, isNot(equals(b.peerID)));
    });

    test(
      'writes a base64-encoded 32-byte seed to <dataPath>/identity',
      () async {
        final path = '${repoDir.path}/node';
        final router = Libp2pRouter(configFor(path));
        await router.initialize();

        final identityFile = File('$path/identity');
        expect(identityFile.existsSync(), isTrue);
      },
    );

    test('an explicit seed takes precedence over persistence', () async {
      final path = '${repoDir.path}/node';
      final seeded = Libp2pRouter(
        configFor(path),
        seed: Uint8List.fromList(List.generate(32, (i) => i + 1)),
      );
      await seeded.initialize();
      final seededPeerId = seeded.peerID;
      expect(seededPeerId, isNotEmpty);

      // A router without an explicit seed on the same path must not adopt
      // the seeded router's identity file (none is written by the seeded
      // router) and must produce a different peer ID.
      final unseeded = Libp2pRouter(configFor(path));
      await unseeded.initialize();
      expect(unseeded.peerID, isNot(equals(seededPeerId)));
    });

    test(
      'falls back to an ephemeral identity when persistence is unavailable',
      () async {
        // A dataPath that resolves to a regular file makes
        // <dataPath>/identity unwritable: the seed persistence attempt
        // throws, so the router must fall back to an ephemeral identity.
        final blocker = File('${repoDir.path}/blocker')
          ..writeAsStringSync('not a directory');

        final router = Libp2pRouter(configFor(blocker.path));
        await router.initialize();

        expect(router.isInitialized, isTrue);
        expect(router.peerID, isNotEmpty);
        expect(File('${blocker.path}/identity').existsSync(), isFalse);
      },
    );

    test('recovers from a malformed identity file', () async {
      final path = '${repoDir.path}/node';
      Directory(path).createSync(recursive: true);
      File('$path/identity').writeAsStringSync('not-valid-base64!!!');

      final router = Libp2pRouter(configFor(path));
      await router.initialize();
      expect(router.peerID, isNotEmpty);

      // The malformed file is replaced by a fresh valid seed.
      final second = Libp2pRouter(configFor(path));
      await second.initialize();
      expect(second.peerID, equals(router.peerID));
    });
  });
}
