import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:path/path.dart' as p;

/// Shared helpers for end-to-end tests that run real [IPFSNode] instances
/// against temporary on-disk repositories.
///
/// Each node carries its own node-scoped `ServiceContainer`, so lazily-
/// resolved getters (`addresses`, `dhtHandler`, `securityManager`, keys,
/// `pinnedCids`, `datastore`, `blockStore`) always return that node's own
/// services regardless of how many nodes exist or in which order they were
/// created.

/// Creates a fresh temporary repo directory for a test.
Future<Directory> makeRepoDir(String tag) {
  return Directory.systemTemp.createTemp('ipfs_e2e_${tag}_');
}

/// An offline node config rooted at [repoDir]: no networking is started,
/// storage paths live under the temp dir.
IPFSConfig offlineConfig(String repoDir) {
  return IPFSConfig(
    offline: true,
    dataPath: p.join(repoDir, 'repo'),
    datastorePath: p.join(repoDir, 'repo', 'datastore'),
    keystorePath: p.join(repoDir, 'repo', 'keystore'),
    blockStorePath: p.join(repoDir, 'repo', 'blocks'),
  );
}

/// An online node config rooted at [repoDir]: loopback-only libp2p on an
/// ephemeral port, no bootstrap/mDNS/NAT so tests stay deterministic and
/// hermetic.
IPFSConfig onlineConfig(String repoDir, {String? rpcApiKey}) {
  return IPFSConfig(
    offline: false,
    debug: false,
    dataPath: p.join(repoDir, 'repo'),
    datastorePath: p.join(repoDir, 'repo', 'datastore'),
    keystorePath: p.join(repoDir, 'repo', 'keystore'),
    blockStorePath: p.join(repoDir, 'repo', 'blocks'),
    rpcApiKey: rpcApiKey,
    network: NetworkConfig(
      listenAddresses: const ['/ip4/127.0.0.1/tcp/0'],
      bootstrapPeers: const [],
      enableMDNS: false,
      enableNatTraversal: false,
    ),
  );
}

/// Stops [node] if it is running; errors from a not-started or already
/// stopped node are ignored.
Future<void> stopQuietly(IPFSNode? node) async {
  try {
    await node?.stop();
  } catch (_) {
    // Already stopped or failed to start.
  }
}

/// Deletes [dir] with retries — background file handles (Hive boxes, log
/// files) can briefly outlive `node.stop()` on some platforms.
Future<void> deleteRepo(Directory dir) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  for (var attempt = 0; attempt < 20; attempt++) {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}

/// Polls [check] until it returns a non-null value or [timeout] elapses.
///
/// [check] should return `null` (or `false`) while the condition is unmet
/// and a non-null value once satisfied; that value is returned.
Future<T> waitFor<T>(
  FutureOr<T?> Function() check, {
  Duration timeout = const Duration(seconds: 15),
  Duration interval = const Duration(milliseconds: 100),
  String description = 'condition',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final value = await check();
    if (value != null && value != false) return value;
    await Future<void>.delayed(interval);
  }
  throw TimeoutException('Timed out waiting for $description', timeout);
}

/// Builds a dialable multiaddr for [node]: its first TCP listen address
/// with the `/p2p/` peer suffix appended.
String dialAddress(IPFSNode node) {
  final addr = node.addresses.firstWhere(
    (a) => a.contains('/tcp/'),
    orElse: () =>
        throw StateError('Node has no TCP listen address: ${node.addresses}'),
  );
  return '$addr/p2p/${node.peerID}';
}

/// Finds a free TCP port on loopback.
Future<int> freePort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

Uint8List utf8Bytes(String s) => Uint8List.fromList(s.codeUnits);
