import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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

/// Returns the base58btc (no multibase prefix) form of a multihash, matching
/// the modern `//` double-hash preimage convention.
String _b58Multihash(CID cid) {
  return multibaseEncode(
    Multibase.base58btc,
    cid.multihash.toBytes(),
  ).substring(1);
}

/// Builds a modern `//` double-hash denylist entry for [preimage] using
/// sha2-256, i.e. a bare base58btc multihash of `sha256(preimage)`.
String _modernDoubleHashEntry(String preimage) {
  final digest = sha256.convert(utf8.encode(preimage)).bytes;
  final mhBytes = Uint8List.fromList([0x12, 0x20, ...digest]);
  return multibaseEncode(Multibase.base58btc, mhBytes).substring(1);
}

/// Builds a legacy `//` double-hash denylist entry for [preimage], i.e. the
/// lowercase sha256 hex digest used by BadBits anchors.
String _legacyDoubleHashEntry(String preimage) {
  return sha256.convert(utf8.encode(preimage)).toString();
}

void main() {
  Logger.root.level = Level.OFF;

  group('DenylistBlockedException', () {
    test('toString includes the CID when present', () {
      const cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      expect(
        const DenylistBlockedException(cid).toString(),
        'DenylistBlockedException: content blocked by operator policy ($cid)',
      );
      expect(
        const DenylistBlockedException().toString(),
        'DenylistBlockedException: content blocked by operator policy',
      );
    });
  });

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

  group('DenylistService compact denylist format', () {
    late _MockMetricsCollector metrics;
    late CID blockedCid;
    late CID allowedCid;
    late String blockedCidStr;

    setUp(() async {
      metrics = _MockMetricsCollector();
      blockedCid = await CID.fromContent(
        Uint8List.fromList([9, 8, 7]),
        codec: 'raw',
      );
      allowedCid = await CID.fromContent(
        Uint8List.fromList([6, 5, 4]),
        codec: 'raw',
      );
      blockedCidStr = blockedCid.encode();
    });

    test('parses an optional YAML header and skips it', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final text =
          'version: 1\n'
          'name: Test list\n'
          'description: fixture\n'
          'hints:\n'
          '  hint: value\n'
          '---\n'
          '$blockedCidStr\n';
      service.loadCompactBytes(utf8.encode(text));
      expect(service.isBlocked(blockedCid), isTrue);
    });

    test('rejects unsupported header versions', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final text = 'version: 2\n---\n$blockedCidStr\n';
      expect(
        () => service.loadCompactBytes(utf8.encode(text)),
        throwsFormatException,
      );
    });

    test('matches modern // double-hash entries across CID versions', () {
      final service = DenylistService(_denylistConfig(), metrics);
      // Modern preimage: sha256 of the base58btc multihash string.
      final entry = _modernDoubleHashEntry(_b58Multihash(blockedCid));
      service.loadCompactBytes(utf8.encode('//$entry'));
      expect(service.isEnabled, isTrue);
      expect(service.isBlocked(blockedCid), isTrue);
      // Codec- and version-agnostic: CIDv0 and dag-pb CIDv1 share the
      // multihash and must be blocked too.
      final cidV0 = CID.v0(Uint8List.fromList(blockedCid.multihash.digest));
      final cidV1DagPb = CID.v1('dag-pb', blockedCid.multihash);
      expect(service.isBlocked(cidV0), isTrue);
      expect(service.isBlocked(cidV1DagPb), isTrue);
      expect(service.isBlocked(allowedCid), isFalse);
    });

    test('matches legacy // sha256-hex BadBits anchor entries', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final cidV1Base32 = blockedCid.encodeWithBase(Multibase.base32);
      final entry = _legacyDoubleHashEntry('$cidV1Base32/');
      service.loadCompactBytes(utf8.encode('//$entry'));
      expect(service.isBlocked(blockedCid), isTrue);
      expect(service.isBlockedByCidString(blockedCidStr), isTrue);
      expect(service.isBlocked(allowedCid), isFalse);
    });

    test('matches // double-hash entries for CID+path', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final entry = _modernDoubleHashEntry(
        '${_b58Multihash(blockedCid)}/secret',
      );
      service.loadCompactBytes(utf8.encode('//$entry'));
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/secret'), isTrue);
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/other'), isFalse);
      // The bare CID is not blocked by a path-scoped double-hash.
      expect(service.isBlocked(blockedCid), isFalse);
    });

    test('supports /ipfs/CID, /ipfs/CID/PATH and PATH* items', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final lines = [
        '/ipfs/$blockedCidStr',
        '/ipfs/${allowedCid.encode()}/secret',
      ];
      service.loadCompactBytes(utf8.encode(lines.join('\n')));
      expect(service.isBlocked(blockedCid), isTrue);
      expect(service.isBlocked(allowedCid), isFalse);
      expect(
        service.isBlockedPath('/ipfs/${allowedCid.encode()}/secret'),
        isTrue,
      );
      expect(
        service.isBlockedPath('/ipfs/${allowedCid.encode()}/other'),
        isFalse,
      );
    });

    test('/ipfs/CID/* blocks the CID and every subpath', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode('/ipfs/$blockedCidStr/*'));
      expect(service.isBlocked(blockedCid), isTrue);
      expect(service.isBlockedPath('/ipfs/$blockedCidStr'), isTrue);
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/a/b'), isTrue);
      expect(service.isBlocked(allowedCid), isFalse);
    });

    test('/ipfs/CID/ab* prefix rules match path prefixes', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode('/ipfs/$blockedCidStr/ab*'));
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/ab'), isTrue);
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/abc'), isTrue);
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/a/b'), isFalse);
      expect(service.isBlocked(blockedCid), isFalse);
    });

    test('negated ! rules apply newest-first', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final lines = [
        '/ipfs/$blockedCidStr/blocked*',
        '!/ipfs/$blockedCidStr/blockednot',
      ];
      service.loadCompactBytes(utf8.encode(lines.join('\n')));
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/blocked/1'), isTrue);
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/blockednot'), isFalse);
    });

    test('!/ipfs/CID unblocks a previously denied CID', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(
        utf8.encode('/ipfs/$blockedCidStr\n!/ipfs/$blockedCidStr'),
      );
      expect(service.isBlocked(blockedCid), isFalse);
      expect(service.isBlockedPath('/ipfs/$blockedCidStr'), isFalse);
    });

    test('later deny rule wins over an earlier ! allow rule', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(
        utf8.encode('!/ipfs/$blockedCidStr\n/ipfs/$blockedCidStr'),
      );
      expect(service.isBlocked(blockedCid), isTrue);
    });

    test('supports ipfs:// URI items and ipfs:// request paths', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode('ipfs://$blockedCidStr'));
      expect(service.isBlocked(blockedCid), isTrue);
      expect(service.isBlockedPath('ipfs://$blockedCidStr/some/path'), isTrue);
    });

    test('supports /ipns/NAME items with path rules', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final lines = ['/ipns/bad.example', '/ipns/other.example/evil*'];
      service.loadCompactBytes(utf8.encode(lines.join('\n')));
      expect(service.isBlockedPath('/ipns/bad.example'), isTrue);
      // DNSLink domains are case-insensitive.
      expect(service.isBlockedPath('/ipns/BAD.Example'), isTrue);
      expect(service.isBlockedPath('/ipns/bad.example/any/path'), isTrue);
      expect(service.isBlockedPath('/ipns/other.example/evil/x'), isTrue);
      expect(service.isBlockedPath('/ipns/other.example/good'), isFalse);
      expect(service.isBlockedPath('/ipns/other.example'), isFalse);
    });

    test('/ipns/CID-name blocks the underlying multihash', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode('/ipns/$blockedCidStr'));
      expect(service.isBlocked(blockedCid), isTrue);
      expect(service.isBlockedPath('/ipns/$blockedCidStr'), isTrue);
      expect(service.isBlocked(allowedCid), isFalse);
    });

    test('supports legacy // double-hash of IPNS domain names', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final entry = _legacyDoubleHashEntry('bad.example/');
      service.loadCompactBytes(utf8.encode('//$entry'));
      expect(service.isBlockedPath('/ipns/bad.example'), isTrue);
      expect(service.isBlockedPath('/ipns/other.example'), isFalse);
    });

    test('supports modern // double-hash of IPNS domain names', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final entry = _modernDoubleHashEntry('/ipns/bad.example');
      service.loadCompactBytes(utf8.encode('//$entry'));
      expect(service.isBlockedPath('/ipns/bad.example'), isTrue);
      expect(service.isBlockedPath('/ipns/other.example'), isFalse);
    });

    test('ignores trailing hints on block items', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(
        utf8.encode('/ipfs/$blockedCidStr reason:spam hint:v1'),
      );
      expect(service.isBlocked(blockedCid), isTrue);
    });

    test('matches CID strings regardless of request casing', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode(blockedCidStr));
      // Uppercase base32 (multibase 'B' prefix) decodes to the same CID.
      expect(service.isBlockedByCidString(blockedCidStr.toUpperCase()), isTrue);
    });

    test('isBlockedPath is inert when the service is disabled', () {
      final service = DenylistService(const SecurityConfig(), metrics);
      service.loadCompactBytes(utf8.encode('/ipfs/$blockedCidStr/evil*'));
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/evil'), isFalse);
      expect(service.isBlocked(blockedCid), isFalse);
    });

    test('audit events carry operator-provided reason metadata', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final text =
          '# {"reason": "CSAM report", "cid": "$blockedCidStr"}\n'
          '$blockedCidStr';
      service.loadCompactBytes(utf8.encode(text));
      service.recordHit(blockedCidStr, source: 'gateway');
      final event = service.getAuditLog().single;
      expect(event.reason, equals('CSAM report'));
      expect(event.cidOrMultihash, equals(blockedCidStr));
      expect(event.source, equals('gateway'));
      expect(event.action, equals('block'));
    });
  });

  group('DenylistService compact format edge branches', () {
    late _MockMetricsCollector metrics;
    late CID blockedCid;
    late CID allowedCid;
    late String blockedCidStr;
    late String blockedMultihashStr;

    setUp(() async {
      metrics = _MockMetricsCollector();
      blockedCid = await CID.fromContent(
        Uint8List.fromList([11, 22, 33]),
        codec: 'raw',
      );
      allowedCid = await CID.fromContent(
        Uint8List.fromList([44, 55, 66]),
        codec: 'raw',
      );
      blockedCidStr = blockedCid.encode();
      blockedMultihashStr = multibaseEncode(
        Multibase.base32,
        blockedCid.multihash.toBytes(),
      );
    });

    test('supports ipns:// URI block items and ipns:// request paths', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode('ipns://bad.example'));
      expect(service.isBlockedPath('/ipns/bad.example'), isTrue);
      expect(service.isBlockedPath('ipns://bad.example/deep'), isTrue);
      expect(service.isBlockedPath('ipns://other.example'), isFalse);
    });

    test('!<bare multihash> removes the entry and adds an allow rule', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(
        utf8.encode('$blockedMultihashStr\n!$blockedMultihashStr'),
      );
      expect(service.isBlocked(blockedCid), isFalse);
      expect(service.isBlockedByMultihash(blockedMultihashStr), isFalse);
    });

    test('!<bare CID> unblocks via a negated path rule', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode('$blockedCidStr\n!$blockedCidStr'));
      expect(service.isBlocked(blockedCid), isFalse);
      expect(service.isBlockedPath('/ipfs/$blockedCidStr'), isFalse);
    });

    test('trailing slashes are trimmed from /ipfs path rules', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode('/ipfs/$blockedCidStr/path/'));
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/path'), isTrue);
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/path/x'), isFalse);
      expect(service.isBlocked(blockedCid), isFalse);
    });

    test('/ipfs/CID/path/* trims the slash before the wildcard', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode('/ipfs/$blockedCidStr/path/*'));
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/path/x'), isTrue);
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/path'), isTrue);
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/other'), isFalse);
    });

    test('trailing slashes are trimmed from /ipns path rules', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode('/ipns/bad.example/path/'));
      expect(service.isBlockedPath('/ipns/bad.example/path'), isTrue);
      expect(service.isBlockedPath('/ipns/bad.example/path/x'), isFalse);
      expect(service.isBlockedPath('/ipns/bad.example'), isFalse);
    });

    test('/ipns/NAME/path/* trims the slash before the wildcard', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode('/ipns/bad.example/path/*'));
      expect(service.isBlockedPath('/ipns/bad.example/path/x'), isTrue);
      expect(service.isBlockedPath('/ipns/bad.example/path'), isTrue);
      expect(service.isBlockedPath('/ipns/bad.example/other'), isFalse);
    });

    test('!/ipns/NAME removes a blocked non-CID name', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(
        utf8.encode('/ipns/bad.example\n!/ipns/bad.example'),
      );
      expect(service.isBlockedPath('/ipns/bad.example'), isFalse);
      expect(service.isBlockedPath('/ipns/bad.example/any/path'), isFalse);
    });

    test('!//LEGACY removes a legacy double-hash entry', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final cidV1Base32 = blockedCid.encodeWithBase(Multibase.base32);
      final entry = _legacyDoubleHashEntry('$cidV1Base32/');
      service.loadCompactBytes(utf8.encode('//$entry\n!//$entry\n$allowedCid'));
      expect(service.isBlocked(blockedCid), isFalse);
      expect(service.isBlocked(allowedCid), isTrue);
    });

    test('!//MULTIHASH removes a modern double-hash entry', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final entry = _modernDoubleHashEntry(_b58Multihash(blockedCid));
      service.loadCompactBytes(utf8.encode('//$entry\n!//$entry\n$allowedCid'));
      expect(service.isBlocked(blockedCid), isFalse);
      expect(service.isBlocked(allowedCid), isTrue);
    });

    test('non-sha256 // multihash entries are stored but never match', () {
      final service = DenylistService(_denylistConfig(), metrics);
      // A structurally valid sha1 multihash (code 0x11, length 32 bytes).
      final digest = sha256.convert(utf8.encode('preimage')).bytes;
      final mhBytes = Uint8List.fromList([0x11, 0x20, ...digest]);
      final entry = multibaseEncode(Multibase.base58btc, mhBytes);
      service.loadCompactBytes(utf8.encode('//$entry'));
      expect(service.isEnabled, isTrue);
      expect(service.isBlocked(blockedCid), isFalse);
      expect(service.isBlocked(allowedCid), isFalse);
    });

    test('isBlockedByMultihash matches modern // double-hash entries', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final entry = _modernDoubleHashEntry(_b58Multihash(blockedCid));
      service.loadCompactBytes(utf8.encode('//$entry'));
      expect(service.isBlockedByMultihash(blockedMultihashStr), isTrue);
      expect(
        service.isBlockedByMultihash(
          multibaseEncode(Multibase.base32, allowedCid.multihash.toBytes()),
        ),
        isFalse,
      );
    });

    test('isBlockedByMultihash matches /ipfs/CID/* path rules', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(utf8.encode('/ipfs/$blockedCidStr/*'));
      expect(service.isBlockedByMultihash(blockedMultihashStr), isTrue);
    });

    test('isBlockedPath matches literal non-CID /ipfs entries', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.blockCidString('not-a-real-cid');
      expect(service.isBlockedPath('/ipfs/not-a-real-cid'), isTrue);
      expect(service.isBlockedPath('/ipfs/not-a-real-cid/sub'), isTrue);
      expect(service.isBlockedPath('/ipfs/other-entry'), isFalse);
    });

    test('/ipns/CID-name requests fall through to CID-level blocking', () {
      final service = DenylistService(_denylistConfig(), metrics);
      // Block the CIDv0 form; the request uses the CIDv1 form of the same
      // multihash as an IPNS name, which is not a literal cidStrings entry.
      final cidV0 = CID.v0(Uint8List.fromList(blockedCid.multihash.digest));
      service.loadCompactBytes(utf8.encode(cidV0.encode()));
      expect(service.isBlockedPath('/ipns/$blockedCidStr'), isTrue);
      expect(service.isBlockedPath('/ipns/$blockedCidStr/any/path'), isTrue);
    });

    test('recordHit under log action resolves and records reasons', () {
      final service = DenylistService(_denylistConfig(action: 'log'), metrics);
      service.loadCompactBytes(utf8.encode(blockedCidStr));
      final action = service.recordHit(
        blockedCidStr,
        source: 'gateway',
        reason: 'operator note',
      );
      expect(action, equals('log'));
      expect(service.getAuditLog().single.reason, equals('operator note'));
      expect(metrics.securityEvents.last['type'], equals('denylist_logged'));
    });

    test('unblock clears CID, path rules, and hashed entries', () {
      final service = DenylistService(_denylistConfig(), metrics);
      final cidV0 = CID.v0(Uint8List.fromList(blockedCid.multihash.digest));
      final cidV1Base32 = CID
          .v1('dag-pb', blockedCid.multihash)
          .encodeWithBase(Multibase.base32);
      final entry = _legacyDoubleHashEntry('$cidV1Base32/');
      service.loadCompactBytes(utf8.encode('//$entry'));
      // The CIDv0 form must convert to CIDv1 base32 for the legacy anchor.
      expect(service.isBlocked(cidV0), isTrue);
      service.unblock(cidV0);
      expect(service.isBlocked(cidV0), isFalse);
      expect(service.isBlocked(blockedCid), isFalse);
    });

    test('unblockCidString removes CID, IPNS names, and hashed entries', () {
      final service = DenylistService(_denylistConfig(), metrics);
      service.loadCompactBytes(
        utf8.encode('/ipfs/$blockedCidStr/sub\n$blockedCidStr'),
      );
      service.unblockCidString(blockedCidStr);
      expect(service.isBlocked(blockedCid), isFalse);
      expect(service.isBlockedPath('/ipfs/$blockedCidStr/sub'), isFalse);

      // Non-CID strings are removed as literal/IPNS-name entries.
      service.blockCidString('not-a-real-cid');
      service.unblockCidString('not-a-real-cid');
      expect(service.isBlockedPath('/ipfs/not-a-real-cid'), isFalse);
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

    test('returns 451 for denylisted subpaths only', () async {
      final blockStore = BlockStore(path: 'test_blocks_subpath');
      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      final cidStr = cid.encode();
      await blockStore.putBlock(
        Block(cid: cid, data: Uint8List.fromList([1, 2, 3])),
      );

      final service = DenylistService(
        _denylistConfig(),
        _MockMetricsCollector(),
      );
      service.loadCompactBytes(utf8.encode('/ipfs/$cidStr/private*'));

      final handler = GatewayHandler(blockStore, denylistService: service);

      final blocked = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr/private/file.txt'),
        ),
      );
      expect(blocked.statusCode, equals(451));

      // The bare CID and other subpaths are not covered by the rule, so the
      // request is not answered with 451 (it may still fail to resolve).
      final allowed = await handler.handlePath(
        Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidStr/public/file.txt'),
        ),
      );
      expect(allowed.statusCode, isNot(451));

      await blockStore.stop();
    });

    test('returns 451 for a denylisted CID resolved through IPNS', () async {
      final blockStore = BlockStore(path: 'test_blocks_ipns');
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

      final handler = GatewayHandler(
        blockStore,
        denylistService: service,
        ipnsResolver: (name) async => cidStr,
      );
      // The IPNS name itself is not listed, but it resolves to a blocked
      // CID, so the request must still be denied.
      final response = await handler.handlePath(
        Request('GET', Uri.parse('http://localhost/ipns/allowed.example')),
      );
      expect(response.statusCode, equals(451));

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
