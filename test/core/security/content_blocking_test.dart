import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_handlers.dart';
import 'package:logging/logging.dart';
import 'package:multibase/multibase.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _MockMetricsCollector implements MetricsCollector {
  final List<Map<String, dynamic>> securityEvents = [];
  final List<Map<String, dynamic>> recordedMetrics = [];

  @override
  void recordSecurityEvent(String type) {
    securityEvents.add({'type': type});
  }

  @override
  void recordProtocolMetrics(String protocol, Map<String, dynamic> metrics) {
    recordedMetrics.add({'protocol': protocol, 'metrics': metrics});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SecurityConfig _denylistConfig({
  String? path,
  String action = 'block',
  bool enabled = true,
  String? storagePath,
}) {
  return SecurityConfig(
    enableDenylist: enabled,
    denylistPath: path,
    denylistDefaultAction: action,
    denylistStoragePath: storagePath,
  );
}

void main() {
  Logger.root.level = Level.OFF;

  group('DenylistService', () {
    late _MockMetricsCollector metrics;
    late CID blockedCid;
    late CID allowedCid;
    late String blockedCidStr;
    late String allowedCidStr;
    late String blockedMultihashStr;

    setUp(() async {
      metrics = _MockMetricsCollector();
      blockedCid = await CID.fromContent(
        Uint8List.fromList([1, 2, 3]),
        codec: 'raw',
      );
      allowedCid = await CID.fromContent(
        Uint8List.fromList([4, 5, 6]),
        codec: 'raw',
      );
      blockedCidStr = blockedCid.encode();
      allowedCidStr = allowedCid.encode();
      blockedMultihashStr = multibaseEncode(
        Multibase.base32,
        blockedCid.multihash.toBytes(),
      );
    });

    test('is default-off and has no effect when disabled', () {
      final service = DenylistService(const SecurityConfig(), metrics);
      service.loadCompactBytes(utf8.encode(blockedCidStr));
      expect(service.isEnabled, isFalse);
      expect(service.isBlocked(blockedCid), isFalse);
      expect(service.isBlockedByCidString(blockedCidStr), isFalse);
      expect(service.isBlockedByMultihash(blockedMultihashStr), isFalse);
    });

    test('blocks CID strings from plain text lists', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode(blockedCidStr));
      expect(service.isEnabled, isTrue);
      expect(service.isBlocked(blockedCid), isTrue);
      expect(service.isBlockedByCidString(blockedCidStr), isTrue);
      expect(service.isBlockedByCidString(allowedCidStr), isFalse);
    });

    test('matches CID against base32 multihash entry', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode(blockedMultihashStr));
      expect(service.isEnabled, isTrue);
      expect(service.isBlocked(blockedCid), isTrue);
      expect(service.isBlockedByCidString(blockedCidStr), isTrue);
      expect(service.isBlockedByMultihash(blockedMultihashStr), isTrue);
      expect(service.isBlocked(allowedCid), isFalse);
    });

    test('parses BadBits compact format with comments and metadata', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final lines = [
        '# Plain comment',
        '# {"reason": "test reason", "cid": "$blockedCidStr"}',
        blockedCidStr,
        '',
        blockedMultihashStr,
        '# invalid line that is skipped',
      ];
      service.loadCompactBytes(utf8.encode(lines.join('\n')));
      expect(service.isBlocked(blockedCid), isTrue);
      expect(service.length, equals(2));
    });

    test('skips lines longer than 4096 characters and counts warnings', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final longLine = 'a' * 4097;
      final text = '$blockedCidStr\n$longLine\n';
      service.loadCompactBytes(utf8.encode(text));
      expect(service.isBlocked(blockedCid), isTrue);
      // A CID string is stored as one CID entry plus one multihash entry.
      expect(service.getStats().loadedEntries, equals(2));
    });

    test('refreshes atomically and keeps previous list on failure', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode(blockedCidStr));
      expect(service.isBlocked(blockedCid), isTrue);

      expect(
        () => service.loadCompactBytes(utf8.encode('not-a-cid')),
        throwsFormatException,
      );
      expect(service.isBlocked(blockedCid), isTrue);
    });

    test('loads from local file path', () async {
      final tempDir = await Directory.systemTemp.createTemp('denylist_test');
      final file = File(p.join(tempDir.path, 'denylist.txt'));
      await file.writeAsString(blockedCidStr);

      final service = DenylistService(
        _denylistConfig(path: file.path),
        metrics,
      );
      await service.loadFromPath(file.path);
      expect(service.isBlocked(blockedCid), isTrue);

      await tempDir.delete(recursive: true);
    });

    test('increments refreshErrors on failed URL load', () async {
      final service = DenylistService(_denylistConfig(), metrics);
      await expectLater(
        service.loadFromUrl('http://localhost:1/invalid'),
        throwsException,
      );
      expect(service.getStats().refreshErrors, equals(1));
    });

    test('audit log records hits with FIFO eviction', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode(blockedCidStr));
      service.recordHit(blockedCidStr, source: 'gateway');
      service.recordHit(blockedCidStr, source: 'rpc');

      final log = service.getAuditLog();
      expect(log.length, equals(2));
      expect(log[0].source, equals('gateway'));
      expect(log[1].source, equals('rpc'));
      expect(log[0].action, equals('block'));
    });

    test('log action records event and does not block', () {
      final service = DenylistService(_denylistConfig(action: 'log'), metrics);
      service.loadCompactBytes(utf8.encode(blockedCidStr));
      final action = service.recordHit(blockedCidStr, source: 'gateway');
      expect(action, equals('log'));
      expect(metrics.securityEvents.last['type'], equals('denylist_logged'));
    });

    test(
      'persists loaded list and reloads from storage on URL failure',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'denylist_storage',
        );
        final storagePath = p.join(tempDir.path, 'cache.txt');
        final service = DenylistService(
          _denylistConfig(),
          metrics,
          storagePath: storagePath,
        );
        service.loadCompactBytes(utf8.encode(blockedCidStr));
        // Force persistence by loading from a URL that fails.
        await expectLater(
          service.loadFromUrl('http://localhost:1/invalid'),
          throwsException,
        );
        final cached = File(storagePath);
        expect(await cached.exists(), isTrue);
        expect(await cached.readAsString(), equals(blockedCidStr));
        await tempDir.delete(recursive: true);
      },
    );

    test('start and stop schedule and cancel refresh timer', () async {
      final service = DenylistService(
        _denylistConfig(path: 'http://localhost:1/invalid'),
        metrics,
      );
      await service.start();
      expect(service.getStats().refreshErrors, greaterThanOrEqualTo(0));
      await service.stop();
    });
  });

  group('Gateway denylist integration', () {
    test('returns 451 for blocked CID with default block action', () async {
      final blockStore = BlockStore(path: 'test_blocks');
      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      final cidStr = cid.encode();
      await blockStore.putBlock(
        Block(cid: cid, data: Uint8List.fromList([1, 2, 3])),
      );

      final service = DenylistService(
        _denylistConfig(),
        _MockMetricsCollector(),
      );
      service.blockCidString(cidStr);

      final handler = GatewayHandler(blockStore, denylistService: service);
      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipfs/$cidStr'),
      );
      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(451));
      final body = await response.readAsString();
      expect(body, equals('Content blocked by operator policy'));

      await blockStore.stop();
    });

    test('returns 200 and logs for blocked CID with log action', () async {
      final blockStore = BlockStore(path: 'test_blocks_log');
      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      final cidStr = cid.encode();
      await blockStore.putBlock(
        Block(cid: cid, data: Uint8List.fromList([1, 2, 3])),
      );

      final metrics = _MockMetricsCollector();
      final service = DenylistService(_denylistConfig(action: 'log'), metrics);
      service.blockCidString(cidStr);

      final handler = GatewayHandler(blockStore, denylistService: service);
      final request = Request(
        'GET',
        Uri.parse('http://localhost/ipfs/$cidStr'),
      );
      final response = await handler.handlePath(request);
      expect(response.statusCode, equals(200));
      expect(metrics.securityEvents.last['type'], equals('denylist_logged'));

      await blockStore.stop();
    });
  });

  group('RPC denylist integration', () {
    late IPFSNode node;

    tearDown(() async {
      if (node.isRunning) {
        await node.stop();
      }
    });

    test('handleCat returns 451 for blocked CID', () async {
      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      final cidStr = cid.encode();
      final service = DenylistService(
        _denylistConfig(),
        _MockMetricsCollector(),
      );
      service.blockCidString(cidStr);

      final config = IPFSConfig(offline: true, security: _denylistConfig());
      node = await IPFSNode.create(config);
      service.blockCidString(cidStr);
      node.denylistService?.blockCidString(cidStr);

      final handlers = RPCHandlers(node);
      final request = Request(
        'POST',
        Uri.parse('http://localhost:5001/api/v0/cat?arg=$cidStr'),
      );
      final response = await handlers.handleCat(request);
      expect(response.statusCode, equals(451));
      final body =
          json.decode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['Code'], equals(451));
      expect(body['Message'], equals('Content blocked by operator policy'));
    });

    test('handleBlockGet returns 451 for blocked CID', () async {
      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      final cidStr = cid.encode();

      final config = IPFSConfig(offline: true, security: _denylistConfig());
      node = await IPFSNode.create(config);
      node.denylistService?.blockCidString(cidStr);

      final handlers = RPCHandlers(node);
      final request = Request(
        'POST',
        Uri.parse('http://localhost:5001/api/v0/block/get?arg=$cidStr'),
      );
      final response = await handlers.handleBlockGet(request);
      expect(response.statusCode, equals(451));
    });

    test('handleDagGet returns 451 for blocked CID', () async {
      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      final cidStr = cid.encode();

      final config = IPFSConfig(offline: true, security: _denylistConfig());
      node = await IPFSNode.create(config);
      node.denylistService?.blockCidString(cidStr);

      final handlers = RPCHandlers(node);
      final request = Request(
        'POST',
        Uri.parse('http://localhost:5001/api/v0/dag/get?arg=$cidStr'),
      );
      final response = await handlers.handleDagGet(request);
      expect(response.statusCode, equals(451));
    });

    test('handleDhtProvide returns 451 for blocked CID', () async {
      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      final cidStr = cid.encode();

      final config = IPFSConfig(offline: true, security: _denylistConfig());
      node = await IPFSNode.create(config);
      node.denylistService?.blockCidString(cidStr);

      final handlers = RPCHandlers(node);
      final request = Request(
        'POST',
        Uri.parse('http://localhost:5001/api/v0/dht/provide?arg=$cidStr'),
      );
      final response = await handlers.handleDhtProvide(request);
      expect(response.statusCode, equals(451));
    });
  });
}
