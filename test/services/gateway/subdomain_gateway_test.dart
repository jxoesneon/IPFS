import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/gateway_config.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/platform/http_server.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_server.dart';
import 'package:fixnum/fixnum.dart';
import 'package:multibase/multibase.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _MockMetrics implements MetricsCollector {
  final List<Map<String, dynamic>> securityEvents = [];

  @override
  void recordSecurityEvent(String type) {
    securityEvents.add({'type': type});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryBlockStore implements BlockStore {
  final _blocks = <String, Block>{};

  void add(Block block) => _blocks[block.cid.encode()] = block;

  @override
  Future<GetBlockResponse> getBlock(String cid) async {
    final block = _blocks[cid];
    if (block == null) {
      return GetBlockResponse()..found = false;
    }
    return GetBlockResponse()
      ..found = true
      ..block = block.toProto();
  }

  @override
  Future<bool> hasBlock(String cid) async => _blocks.containsKey(cid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockIpfsHttpServerInstance implements IpfsHttpServerInstance {
  @override
  Future<void> close({bool force = false}) async {}

  @override
  String get host => 'localhost';

  @override
  int get port => 8080;
}

class _MockHttpServerAdapter implements HttpServerAdapter {
  Handler? lastHandler;

  @override
  Future<IpfsHttpServerInstance> serve(
    Handler handler,
    String address,
    int port,
  ) async {
    lastHandler = handler;
    return _MockIpfsHttpServerInstance();
  }

  @override
  Future<IpfsHttpServerInstance> serveSecure(
    Handler handler,
    String address,
    int port,
    covariant SecurityContext context,
  ) async {
    lastHandler = handler;
    return _MockIpfsHttpServerInstance();
  }
}

String _cidV1Base32(String cidV0) {
  final cid = CID.decode(cidV0);
  return CID
      .v1(cid.codec ?? 'dag-pb', cid.multihash, base: Multibase.base32)
      .encode();
}

void main() {
  group('SubdomainGateway', () {
    late _MemoryBlockStore blockStore;
    late GatewayHandler handler;

    final cidV0 = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
    late String cidV1Base32;

    setUp(() {
      blockStore = _MemoryBlockStore();
      cidV1Base32 = _cidV1Base32(cidV0);
      final block = Block(cid: CID.decode(cidV1Base32), data: Uint8List(0));
      blockStore.add(block);
      handler = GatewayHandler(blockStore);
    });

    group('host parsing', () {
      test('localhost ipfs subdomain is detected', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '$cidV1Base32.ipfs.localhost'},
        );
        expect(handler.isSubdomainRequest(request), isTrue);
      });

      test('localhost ipns subdomain is detected', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'docs.ipfs.io.ipns.localhost'},
        );
        expect(handler.isSubdomainRequest(request), isTrue);
      });

      test('configured domain ipfs subdomain is detected', () {
        handler = GatewayHandler(
          blockStore,
          gatewayDomain: 'ipfs.example.com',
          enableSubdomainGateway: true,
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '$cidV1Base32.ipfs.ipfs.example.com'},
        );
        expect(handler.isSubdomainRequest(request), isTrue);
      });

      test('bare configured domain is not a subdomain', () {
        handler = GatewayHandler(
          blockStore,
          gatewayDomain: 'ipfs.example.com',
          enableSubdomainGateway: true,
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'ipfs.example.com'},
        );
        expect(handler.isSubdomainRequest(request), isFalse);
      });

      test('unconfigured production domain is not a subdomain', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '$cidV1Base32.ipfs.example.com'},
        );
        expect(handler.isSubdomainRequest(request), isFalse);
      });
    });

    group('CID validation', () {
      test('valid CIDv1 base32 is accepted', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '$cidV1Base32.ipfs.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
      });

      test('CIDv0 is converted to CIDv1 base32', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '$cidV0.ipfs.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
      });

      test('invalid CID label returns 400', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'not-a-cid.ipfs.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(400));
        expect(
          await response.readAsString(),
          equals('Invalid CID in subdomain'),
        );
        expect(
          response.headers['content-type'],
          equals('text/plain; charset=utf-8'),
        );
      });
    });

    group('IPNS resolution', () {
      test('peer-id ipns subdomain resolves via ipnsResolver', () async {
        handler = GatewayHandler(
          blockStore,
          ipnsResolver: (name) async => cidV1Base32,
          gatewayDomain: 'ipfs.example.com',
          enableSubdomainGateway: true,
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'k51qzi5uqu5dip5q.k.ipns.ipfs.example.com'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['x-ipfs-path'],
          equals('/ipns/k51qzi5uqu5dip5q.k'),
        );
        expect(response.headers['cache-control'], contains('max-age=60'));
      });

      test('DNSLink ipns subdomain resolves via dnsLinkResolver', () async {
        handler = GatewayHandler(
          blockStore,
          dnsLinkResolver: (domain) async {
            if (domain == 'docs.ipfs.io') {
              return DnsLinkResult('/ipfs/$cidV1Base32', ttlSeconds: 120);
            }
            return null;
          },
          gatewayDomain: 'ipfs.example.com',
          enableSubdomainGateway: true,
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'docs.ipfs.io.ipns.ipfs.example.com'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
        expect(response.headers['x-ipfs-path'], equals('/ipns/docs.ipfs.io'));
        expect(response.headers['x-ipfs-dnslink'], equals('docs.ipfs.io'));
      });

      test('DNSLink /ipns path is recursively resolved', () async {
        handler = GatewayHandler(
          blockStore,
          ipnsResolver: (name) async {
            if (name == 'inner') return cidV1Base32;
            throw Exception('not found');
          },
          dnsLinkResolver: (domain) async {
            if (domain == 'docs.ipfs.io') {
              return DnsLinkResult('/ipns/inner', ttlSeconds: 60);
            }
            return null;
          },
          gatewayDomain: 'ipfs.example.com',
          enableSubdomainGateway: true,
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'docs.ipfs.io.ipns.ipfs.example.com'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
      });

      test('missing IPNS resolver for DNS-like name returns 400/502', () async {
        handler = GatewayHandler(
          blockStore,
          gatewayDomain: 'ipfs.example.com',
          enableSubdomainGateway: true,
          subdomainDNSLinkResolver: false,
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'docs.ipfs.io.ipns.ipfs.example.com'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, anyOf(equals(400), equals(502)));
      });
    });

    group('trustless negotiation', () {
      test('?format=raw on subdomain returns raw block', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/?format=raw'),
          headers: {'host': '$cidV1Base32.ipfs.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('application/vnd.ipld.raw'),
        );
      });

      test('Accept car on subdomain returns CAR archive', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {
            'host': '$cidV1Base32.ipfs.localhost',
            'accept': 'application/vnd.ipfs.car',
          },
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          startsWith('application/vnd.ipld.car'),
        );
      });
    });

    group('denylist', () {
      test('blocked CID returns 451', () async {
        final denylist = DenylistService(
          const SecurityConfig(enableDenylist: true),
          _MockMetrics(),
        )..blockCidString(cidV1Base32);
        handler = GatewayHandler(blockStore, denylistService: denylist);
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '$cidV1Base32.ipfs.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(451));
      });

      test('blocked IPNS name returns 451 before resolution', () async {
        final denylist = DenylistService(
          const SecurityConfig(enableDenylist: true),
          _MockMetrics(),
        )..blockCidString('blocked.ipns');
        handler = GatewayHandler(
          blockStore,
          denylistService: denylist,
          ipnsResolver: (name) async => cidV1Base32,
          gatewayDomain: 'ipfs.example.com',
          enableSubdomainGateway: true,
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'blocked.ipns.ipns.ipfs.example.com'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(451));
      });
    });

    group('CORS headers', () {
      test('subdomain response sets Access-Control-Allow-Origin: *', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '$cidV1Base32.ipfs.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
        expect(response.headers['access-control-allow-origin'], equals('*'));
        expect(
          response.headers['access-control-allow-credentials'],
          isNot(equals('true')),
        );
      });
    });

    group('TLS redirect', () {
      test('http request is redirected to HTTPS when enabled', () async {
        handler = GatewayHandler(
          blockStore,
          gatewayDomain: 'ipfs.example.com',
          enableSubdomainGateway: true,
          subdomainTLSRedirect: true,
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/some/path'),
          headers: {'host': '$cidV1Base32.ipfs.ipfs.example.com'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(301));
        expect(
          response.headers['location'],
          equals('https://$cidV1Base32.ipfs.ipfs.example.com/some/path'),
        );
      });

      test('TLS redirect never triggers for localhost', () async {
        handler = GatewayHandler(blockStore, subdomainTLSRedirect: true);
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '$cidV1Base32.ipfs.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
      });
    });

    group('DNS label handling', () {
      test('host with port is detected and served', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '$cidV1Base32.ipfs.localhost:8080'},
        );
        expect(handler.isSubdomainRequest(request), isTrue);
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
      });

      test('uppercase base32 CID label is case-insensitive', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '${cidV1Base32.toUpperCase()}.ipfs.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
        expect(response.headers['x-ipfs-path'], equals('/ipfs/$cidV1Base32'));
      });

      test('trailing FQDN dot is tolerated', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '$cidV1Base32.ipfs.localhost.'},
        );
        expect(handler.isSubdomainRequest(request), isTrue);
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
      });

      test('multi-label ipfs identifier returns 400', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'foo.bar.ipfs.localhost'},
        );
        expect(handler.isSubdomainRequest(request), isTrue);
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(400));
      });

      test('CID label longer than 63 characters returns 400', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '${'b' * 64}.ipfs.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(400));
      });

      test('percent-encoded identifier returns 400', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'docs%2eipfs.io.ipns.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(400));
      });

      test('ipns identifier with empty label returns 400', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'a..b.ipns.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(400));
      });
    });

    group('inlined DNSLink', () {
      test('inlined single-label DNSLink name resolves', () async {
        String? resolvedDomain;
        handler = GatewayHandler(
          blockStore,
          dnsLinkResolver: (domain) async {
            resolvedDomain = domain;
            if (domain == 'docs.ipfs.io') {
              return DnsLinkResult('/ipfs/$cidV1Base32', ttlSeconds: 120);
            }
            return null;
          },
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'docs-ipfs-io.ipns.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
        expect(resolvedDomain, equals('docs.ipfs.io'));
        expect(response.headers['x-ipfs-dnslink'], equals('docs.ipfs.io'));
        expect(response.headers['cache-control'], contains('max-age=120'));
      });

      test('double-dash escapes survive de-inlining', () async {
        String? resolvedDomain;
        handler = GatewayHandler(
          blockStore,
          dnsLinkResolver: (domain) async {
            resolvedDomain = domain;
            if (domain == 'en.wikipedia-on-ipfs.org') {
              return DnsLinkResult('/ipfs/$cidV1Base32');
            }
            return null;
          },
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': 'en-wikipedia--on--ipfs-org.ipns.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
        expect(resolvedDomain, equals('en.wikipedia-on-ipfs.org'));
      });
    });

    group('content sub-paths', () {
      test('URL path resolves below the content root', () async {
        // Build a small UnixFS directory containing hello.txt.
        final fileBytes = Uint8List.fromList(utf8.encode('hello ipfs'));
        final fileNode = PBNode()
          ..data =
              (Data()
                    ..type = Data_DataType.File
                    ..data = fileBytes)
                  .writeToBuffer();
        final fileCid = CID.computeForDataSync(
          fileNode.writeToBuffer(),
          codec: 'dag-pb',
        );
        blockStore.add(Block(cid: fileCid, data: fileNode.writeToBuffer()));

        final dirNode = PBNode()
          ..data = (Data()..type = Data_DataType.Directory).writeToBuffer()
          ..links.add(
            PBLink()
              ..name = 'hello.txt'
              ..hash = fileCid.toBytes()
              ..size = Int64(fileNode.writeToBuffer().length),
          );
        final dirCid = CID.computeForDataSync(
          dirNode.writeToBuffer(),
          codec: 'dag-pb',
        );
        blockStore.add(Block(cid: dirCid, data: dirNode.writeToBuffer()));

        final request = Request(
          'GET',
          Uri.parse('http://localhost/hello.txt'),
          headers: {'host': '${dirCid.encode()}.ipfs.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
        expect(await response.readAsString(), equals('hello ipfs'));
      });

      test('HEAD returns headers without a body', () async {
        final request = Request(
          'HEAD',
          Uri.parse('http://localhost/'),
          headers: {'host': '$cidV1Base32.ipfs.localhost'},
        );
        final response = await handler.handleSubdomain(request);
        expect(response.statusCode, equals(200));
        expect(await response.readAsString(), isEmpty);
      });
    });

    group('path to subdomain migration', () {
      test('ipfs path on configured domain redirects to subdomain', () async {
        handler = GatewayHandler(
          blockStore,
          gatewayDomain: 'ipfs.example.com',
          enableSubdomainGateway: true,
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidV0'),
          headers: {'host': 'ipfs.example.com'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(301));
        // CIDv0 must be rewritten to CIDv1 base32 in the Location host.
        expect(
          response.headers['location'],
          equals('http://$cidV1Base32.ipfs.ipfs.example.com/'),
        );
      });

      test('redirect preserves path and query', () async {
        handler = GatewayHandler(blockStore, enableSubdomainGateway: true);
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidV1Base32/dir/file.txt?x=1'),
          headers: {'host': 'localhost:8080'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(301));
        expect(
          response.headers['location'],
          equals('http://$cidV1Base32.ipfs.localhost:8080/dir/file.txt?x=1'),
        );
      });

      test('ipns DNSLink path redirects to inlined subdomain', () async {
        handler = GatewayHandler(blockStore, enableSubdomainGateway: true);
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipns/en.wikipedia-on-ipfs.org'),
          headers: {'host': 'localhost'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(301));
        expect(
          response.headers['location'],
          equals('http://en-wikipedia--on--ipfs-org.ipns.localhost/'),
        );
      });

      test('base58btc peer id redirects to base36 subdomain', () async {
        handler = GatewayHandler(blockStore, enableSubdomainGateway: true);
        final base36 = PeerId.fromBase58(cidV0).toBase36();
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipns/$cidV0'),
          headers: {'host': 'localhost'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(301));
        expect(
          response.headers['location'],
          equals('http://$base36.ipns.localhost/'),
        );
      });

      test('X-Forwarded-Proto selects the redirect scheme', () async {
        handler = GatewayHandler(
          blockStore,
          gatewayDomain: 'dweb.link',
          enableSubdomainGateway: true,
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidV1Base32'),
          headers: {'host': 'dweb.link', 'x-forwarded-proto': 'https'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(301));
        expect(
          response.headers['location'],
          equals('https://$cidV1Base32.ipfs.dweb.link/'),
        );
      });

      test('X-Forwarded-Host selects the redirect domain', () async {
        handler = GatewayHandler(
          blockStore,
          gatewayDomain: 'dweb.link',
          enableSubdomainGateway: true,
        );
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidV1Base32'),
          headers: {
            'host': 'dweb.link',
            'x-forwarded-proto': 'https',
            'x-forwarded-host': 'example.com',
          },
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(301));
        expect(
          response.headers['location'],
          equals('https://$cidV1Base32.ipfs.example.com/'),
        );
      });

      test('no redirect when subdomain gateway is disabled', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidV1Base32'),
          headers: {'host': 'localhost'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
      });

      test('no redirect for unknown hosts', () async {
        handler = GatewayHandler(blockStore, enableSubdomainGateway: true);
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/$cidV1Base32'),
          headers: {'host': 'example.org'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(200));
      });

      test('invalid CID path does not redirect', () async {
        handler = GatewayHandler(blockStore, enableSubdomainGateway: true);
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/not-a-cid'),
          headers: {'host': 'localhost'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(400));
      });
    });

    group('URI router', () {
      test('ipfs uri redirects to the equivalent content path', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/?uri=ipfs%3A%2F%2F$cidV1Base32'),
          headers: {'host': 'localhost:8080'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(301));
        expect(
          response.headers['location'],
          equals('http://localhost:8080/ipfs/$cidV1Base32'),
        );
      });

      test('ipns uri preserves the nested path', () async {
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/ipns/?uri=ipns%3A%2F%2Fdocs.ipfs.io%2Fsome%2Ffile',
          ),
          headers: {'host': 'localhost'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(301));
        expect(
          response.headers['location'],
          equals('http://localhost/ipns/docs.ipfs.io/some/file'),
        );
      });

      test('non-ipfs uri scheme returns 400', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/?uri=https%3A%2F%2Fexample.com'),
          headers: {'host': 'localhost'},
        );
        final response = await handler.handlePath(request);
        expect(response.statusCode, equals(400));
      });
    });

    group('GatewayServer integration', () {
      test('subdomain request is routed before path gateway', () async {
        final adapter = _MockHttpServerAdapter();
        final server = GatewayServer(
          blockStore: blockStore,
          httpAdapter: adapter,
          gatewayConfig: const GatewayConfig(
            enabled: true,
            gatewayDomain: 'ipfs.example.com',
            enableSubdomainGateway: true,
          ),
        );
        await server.start();
        final pipeline = adapter.lastHandler!;

        final request = Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'host': '$cidV1Base32.ipfs.ipfs.example.com'},
        );
        final response = await pipeline(request);
        expect(response.statusCode, equals(200));
        expect(response.headers['x-ipfs-path'], equals('/ipfs/$cidV1Base32'));
        expect(response.headers['access-control-allow-origin'], equals('*'));
        await server.stop();
      });

      test('bare gateway domain falls back to path gateway', () async {
        final adapter = _MockHttpServerAdapter();
        final server = GatewayServer(
          blockStore: blockStore,
          httpAdapter: adapter,
          gatewayConfig: const GatewayConfig(
            enabled: true,
            gatewayDomain: 'ipfs.example.com',
            enableSubdomainGateway: true,
          ),
        );
        await server.start();
        final pipeline = adapter.lastHandler!;

        final request = Request(
          'GET',
          Uri.parse('http://localhost/health'),
          headers: {'host': 'ipfs.example.com'},
        );
        final response = await pipeline(request);
        expect(response.statusCode, equals(200));
        await server.stop();
      });
    });
  });
}
