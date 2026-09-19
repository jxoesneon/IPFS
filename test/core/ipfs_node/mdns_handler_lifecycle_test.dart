@TestOn('vm')
import 'dart:async';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/ipfs_node/mdns_handler.dart';
import 'package:dart_ipfs/src/network/mdns_client.dart';
import 'package:test/test.dart';

/// Hand-written [MDnsClient] fake for lifecycle tests.
class _FakeMDnsClient implements MDnsClient {
  List<PtrResourceRecord> ptrRecords = [];
  String txtPeerId = 'QmPZ9gcCEpqKToayWi97p8H586jN4UuTo2Ddfy9y5uUnT7';
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> start() async {
    startCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  bool get isRunning => startCount > stopCount;

  @override
  Stream<T> lookup<T extends ResourceRecord>(
    ResourceRecordQuery query, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    if (T == PtrResourceRecord) {
      return Stream<T>.fromIterable(ptrRecords.cast<T>());
    }
    if (T == SrvResourceRecord) {
      return Stream<T>.fromIterable(<T>[
        SrvResourceRecord(
              query.name,
              const Duration(seconds: 120),
              'localhost',
              4001,
            )
            as T,
      ]);
    }
    if (T == TxtResourceRecord) {
      return Stream<T>.fromIterable(<T>[
        TxtResourceRecord(query.name, const Duration(seconds: 120), [txtPeerId])
            as T,
      ]);
    }
    return Stream<T>.empty();
  }

  @override
  Future<void> startServer({
    required String serviceType,
    required String instanceName,
    required int port,
    required List<String> txt,
  }) async {}

  @override
  Future<void> announce(
    String serviceType,
    String instanceName,
    int port,
    List<String> txt,
  ) async {}
}

PtrResourceRecord _ptr(String name) => PtrResourceRecord(
  '_ipfs-discovery._udp.local',
  const Duration(seconds: 120),
  name,
);

void main() {
  late _FakeMDnsClient mdnsClient;
  late MDNSHandler handler;

  setUp(() {
    mdnsClient = _FakeMDnsClient();
    handler = MDNSHandler(IPFSConfig(), mdnsClient: mdnsClient);
  });

  tearDown(() async {
    await handler.stop();
  });

  group('MDNSHandler lifecycle', () {
    test('peerDiscovery stream stays live across stop/start restart', () async {
      mdnsClient.ptrRecords = [_ptr('peer1.local')];

      // Subscribe once — the discovery stream must survive a full restart
      // cycle. Previously stop() closed the controller, so discovery was
      // silently dead after a restart.
      final peers = <Peer>[];
      handler.peerDiscovery.listen(peers.add);

      await handler.start();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(peers, hasLength(1));

      await handler.stop();
      await handler.start();

      // The discovered set was cleared on stop, so the still-present peer is
      // re-announced on the same stream after restart.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(peers, hasLength(2));
    });

    test(
      '_discoveredPeers stays bounded under many unique PTR names',
      () async {
        // A hostile LAN can announce unbounded unique PTR names; the dedup set
        // must evict the oldest entries once it hits its cap.
        mdnsClient.ptrRecords = List.generate(
          300,
          (i) => _ptr('peer-$i.local'),
        );

        await handler.start();
        await Future<void>.delayed(const Duration(milliseconds: 500));

        final status = await handler.getStatus();
        expect(status['discovered_peers'], equals(256));
      },
    );
  });
}
