// Bootstrap script for the dart_ipfs / Kubo interop network.
// This script is executed by the CI workflow before the tagged test suite runs.
//
// TODO: Implement actual peer discovery / bootstrap connectivity checks once the
// RPC clients and Docker network plumbing are stable. For now it just verifies
// that the test harness can be loaded and the required endpoints are reachable.

import 'dart:io';

// ignore: avoid_relative_lib_imports
import '../lib/dart_ipfs_client.dart';
// ignore: avoid_relative_lib_imports
import '../lib/kubo_client.dart';

const kKuboApiHost = 'kubo';
const kKuboApiPort = 5001;
const kDartIpfsApiHost = 'dart_ipfs';
const kDartIpfsApiPort = 5001;
const kMaxRetries = 30;
const kRetryDelay = Duration(seconds: 2);

Future<void> main() async {
  final kubo = KuboClient(host: kKuboApiHost, port: kKuboApiPort);
  final dartIpfs =
      DartIpfsClient(host: kDartIpfsApiHost, port: kDartIpfsApiPort);

  await _waitForPeer('Kubo', () => kubo.id());
  await _waitForPeer('dart_ipfs', () => dartIpfs.id());

  // Attempt to bootstrap mutual connectivity. This is best-effort; if the
  // underlying swarm connect command is not yet stable, the tests can still
  // proceed and the failure will be visible in the logs.
  try {
    final kuboId = await kubo.id();
    final dartIpfsId = await dartIpfs.id();
    final kuboPeerId = kuboId['ID'] as String;
    final dartIpfsPeerId = dartIpfsId['ID'] as String;

    await kubo.swarmConnect('/dns4/dart_ipfs/tcp/4001/p2p/$dartIpfsPeerId');
    await dartIpfs.swarmConnect('/dns4/kubo/tcp/4001/p2p/$kuboPeerId');
    stdout.writeln('Bootstrap swarm connect attempted.');
  } catch (e) {
    stderr.writeln('Best-effort bootstrap failed: $e');
  }

  stdout.writeln('Interop network bootstrap complete.');
}

Future<void> _waitForPeer(String name, Future<dynamic> Function() probe) async {
  for (var i = 0; i < kMaxRetries; i++) {
    try {
      await probe();
      stdout.writeln('$name is reachable.');
      return;
    } catch (e) {
      stderr.writeln('Waiting for $name... ($i/$kMaxRetries)');
      await Future<void>.delayed(kRetryDelay);
    }
  }
  throw StateError(
      '$name did not become reachable within the bootstrap window.');
}
