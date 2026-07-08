import 'dart:async';
import 'dart:io';

import 'package:dart_ipfs/src/core/config/gateway_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/platform/http_server.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_server.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_tls_manager.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'gateway_server_test.dart';

class _MockIpfsHttpServerInstance implements IpfsHttpServerInstance {
  _MockIpfsHttpServerInstance({String host = 'localhost', int port = 8080})
    : _host = host,
      _port = port;

  bool closed = false;
  final String _host;
  final int _port;

  @override
  Future<void> close({bool force = false}) async {
    closed = true;
  }

  @override
  String get host => _host;

  @override
  int get port => _port;
}

class _MockHttpServerAdapter implements HttpServerAdapter {
  _MockHttpServerAdapter({int securePort = 8443, int plainPort = 8080})
    : _securePort = securePort,
      _plainPort = plainPort;

  Handler? lastHandler;
  String? lastAddress;
  int? lastPort;
  Handler? lastSecureHandler;
  String? lastSecureAddress;
  int? lastSecurePort;
  SecurityContext? lastSecureContext;
  final _secureCompleter = Completer<IpfsHttpServerInstance>();
  final _plainCompleter = Completer<IpfsHttpServerInstance>();
  bool failSecure = false;
  bool failPlain = false;
  final int _securePort;
  final int _plainPort;

  @override
  Future<IpfsHttpServerInstance> serve(
    Handler handler,
    String address,
    int port,
  ) async {
    lastHandler = handler;
    lastAddress = address;
    lastPort = port;
    if (failPlain) throw Exception('plain serve failed');
    _plainCompleter.complete(_MockIpfsHttpServerInstance(port: _plainPort));
    return _plainCompleter.future;
  }

  @override
  Future<IpfsHttpServerInstance> serveSecure(
    Handler handler,
    String address,
    int port,
    covariant SecurityContext context,
  ) async {
    lastSecureHandler = handler;
    lastSecureAddress = address;
    lastSecurePort = port;
    lastSecureContext = context;
    if (failSecure) throw Exception('secure serve failed');
    _secureCompleter.complete(_MockIpfsHttpServerInstance(port: _securePort));
    return _secureCompleter.future;
  }
}

class _FixedAutoTlsProvider implements AutoTlsProvider {
  _FixedAutoTlsProvider(this.context, {this.expiry});

  final SecurityContext context;
  final DateTime? expiry;
  AutoTlsState _state = AutoTlsState.idle;
  bool _acceptedTos = false;

  @override
  AutoTlsState get state => _state;

  @override
  Future<SecurityContext> obtainCertificate(GatewayConfig config) async {
    if (!config.autoTlsAcceptTos) {
      throw StateError('AutoTLS ToS not accepted');
    }
    _acceptedTos = true;
    _state = AutoTlsState.validating;
    _state = AutoTlsState.active;
    return context;
  }

  @override
  Future<DateTime?> certificateExpiry() async => expiry;

  @override
  Future<void> dispose() async {
    _state = AutoTlsState.idle;
  }

  bool get acceptedTos => _acceptedTos;
}

void main() {
  group('GatewayConfig TLS fields', () {
    test('round-trip through JSON', () {
      const config = GatewayConfig(
        enabled: true,
        port: 8080,
        enableTls: true,
        certificatePath: '/etc/dart_ipfs/cert.pem',
        privateKeyPath: '/etc/dart_ipfs/key.pem',
        certificatePassword: 'secret',
        autoTls: true,
        autoTlsDomain: 'gateway.example.com',
        autoTlsEmail: 'admin@example.com',
        autoTlsProvider: 'letsencrypt',
        autoTlsAcceptTos: true,
        autoTlsSANs: ['www.example.com'],
        tlsPort: 443,
        redirectHttpToHttps: true,
      );
      final json = config.toJson();
      final parsed = GatewayConfig.fromJson(json);
      expect(parsed.enabled, isTrue);
      expect(parsed.enableTls, isTrue);
      expect(parsed.certificatePath, equals('/etc/dart_ipfs/cert.pem'));
      expect(parsed.privateKeyPath, equals('/etc/dart_ipfs/key.pem'));
      expect(parsed.certificatePassword, equals('secret'));
      expect(parsed.autoTls, isTrue);
      expect(parsed.autoTlsDomain, equals('gateway.example.com'));
      expect(parsed.autoTlsEmail, equals('admin@example.com'));
      expect(parsed.autoTlsProvider, equals('letsencrypt'));
      expect(parsed.autoTlsAcceptTos, isTrue);
      expect(parsed.autoTlsSANs, equals(['www.example.com']));
      expect(parsed.tlsPort, equals(443));
      expect(parsed.redirectHttpToHttps, isTrue);
    });

    test('defaults are off', () {
      const config = GatewayConfig();
      expect(config.enableTls, isFalse);
      expect(config.autoTls, isFalse);
      expect(config.autoTlsAcceptTos, isFalse);
      expect(config.tlsPort, equals(443));
      expect(config.redirectHttpToHttps, isFalse);
    });
  });

  group('GatewayTlsManager', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('gateway_tls_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('throws when TLS is not enabled', () async {
      final manager = GatewayTlsManager(const GatewayConfig());
      await expectLater(
        manager.loadSecurityContext(),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when certificate files are missing', () async {
      final manager = GatewayTlsManager(
        const GatewayConfig(
          enableTls: true,
          certificatePath: '/nonexistent/cert.pem',
          privateKeyPath: '/nonexistent/key.pem',
        ),
      );
      await expectLater(
        manager.loadSecurityContext(),
        throwsA(isA<StateError>()),
      );
    });

    test('loads SecurityContext from PEM files and extracts expiry', () async {
      final cert = await _generateSelfSignedCertificate(tempDir.path);
      if (cert == null) {
        // OpenSSL not available; skip this test.
        return;
      }

      final manager = GatewayTlsManager(
        GatewayConfig(
          enableTls: true,
          certificatePath: cert.certPath,
          privateKeyPath: cert.keyPath,
        ),
      );
      final context = await manager.loadSecurityContext();
      expect(context, isNotNull);
      expect(manager.isContextLoaded, isTrue);
      expect(manager.certificateExpiry, isNotNull);
      expect(manager.certificateExpiry!.isAfter(DateTime.now()), isTrue);
      expect(manager.isActive, isTrue);
    });

    test('refuses AutoTLS without ToS acceptance', () async {
      final context = _createMinimalSecurityContext();
      final provider = _FixedAutoTlsProvider(context);
      final manager = GatewayTlsManager(
        const GatewayConfig(autoTls: true),
        provider: provider,
      );
      await expectLater(
        manager.loadSecurityContext(),
        throwsA(isA<StateError>()),
      );
      expect(manager.isContextLoaded, isFalse);
    });

    test('obtains AutoTLS certificate when ToS is accepted', () async {
      final context = _createMinimalSecurityContext();
      final expiry = DateTime.now().add(const Duration(days: 90));
      final provider = _FixedAutoTlsProvider(context, expiry: expiry);
      final manager = GatewayTlsManager(
        const GatewayConfig(
          autoTls: true,
          autoTlsDomain: 'gateway.example.com',
          autoTlsAcceptTos: true,
        ),
        provider: provider,
      );
      final loaded = await manager.loadSecurityContext();
      expect(loaded, same(context));
      expect(manager.isContextLoaded, isTrue);
      expect(manager.certificateExpiry, equals(expiry));
      expect(provider.acceptedTos, isTrue);
      expect(manager.autoTlsState, equals(AutoTlsState.active));
    });
  });

  group('GatewayServer TLS', () {
    late _MockHttpServerAdapter mockAdapter;
    late GatewayServer server;
    late Directory tempDir;
    late BlockStore blockStore;

    setUp(() {
      mockAdapter = _MockHttpServerAdapter();
      blockStore = MockBlockStore();
      tempDir = Directory.systemTemp.createTempSync('gateway_tls_server_test');
    });

    tearDown(() async {
      try {
        await server.stop();
      } catch (_) {}
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('binds HTTPS when enableTls is true', () async {
      final cert = await _generateSelfSignedCertificate(tempDir.path);
      if (cert == null) return;

      server = GatewayServer(
        blockStore: blockStore,
        httpAdapter: mockAdapter,
        gatewayConfig: GatewayConfig(
          enableTls: true,
          certificatePath: cert.certPath,
          privateKeyPath: cert.keyPath,
          tlsPort: 8443,
        ),
      );
      await server.start();

      expect(mockAdapter.lastSecureAddress, equals('localhost'));
      expect(mockAdapter.lastSecurePort, equals(8443));
      expect(mockAdapter.lastSecureContext, isNotNull);
      expect(mockAdapter.lastHandler, isNotNull);
      expect(server.isRunning, isTrue);
      expect(await server.isTlsActive(), isTrue);
      expect(await server.certificateExpiry(), isNotNull);
      expect(server.url, startsWith('https://'));
    });

    test(
      'starts HTTP redirect server when redirectHttpToHttps is true',
      () async {
        final cert = await _generateSelfSignedCertificate(tempDir.path);
        if (cert == null) return;

        server = GatewayServer(
          blockStore: blockStore,
          httpAdapter: mockAdapter,
          gatewayConfig: GatewayConfig(
            enableTls: true,
            certificatePath: cert.certPath,
            privateKeyPath: cert.keyPath,
            tlsPort: 8443,
            redirectHttpToHttps: true,
            port: 8080,
          ),
        );
        await server.start();

        expect(mockAdapter.lastSecurePort, equals(8443));
        expect(mockAdapter.lastPort, equals(8080));
        expect(mockAdapter.lastHandler, isNotNull);

        final redirectHandler = mockAdapter.lastHandler!;
        final request = Request(
          'GET',
          Uri.parse('http://localhost/ipfs/QmSomeCid'),
          headers: {'host': 'gateway.example.com'},
        );
        final response = await redirectHandler(request);
        expect(response.statusCode, equals(301));
        expect(
          response.headers['location'],
          equals('https://gateway.example.com/ipfs/QmSomeCid'),
        );
      },
    );

    test('binds plain HTTP when TLS is disabled', () async {
      server = GatewayServer(
        blockStore: blockStore,
        httpAdapter: mockAdapter,
        gatewayConfig: const GatewayConfig(),
      );
      await server.start();

      expect(mockAdapter.lastSecureHandler, isNull);
      expect(mockAdapter.lastPort, equals(8080));
      expect(server.url, equals('http://localhost:8080'));
      expect(await server.isTlsActive(), isFalse);
    });

    test('uses AutoTLS provider when autoTls is true', () async {
      final context = _createMinimalSecurityContext();
      final provider = _FixedAutoTlsProvider(
        context,
        expiry: DateTime.now().add(const Duration(days: 90)),
      );
      final manager = GatewayTlsManager(
        const GatewayConfig(
          autoTls: true,
          autoTlsDomain: 'gateway.example.com',
          autoTlsAcceptTos: true,
          tlsPort: 8443,
        ),
        provider: provider,
      );
      server = GatewayServer(
        blockStore: blockStore,
        httpAdapter: mockAdapter,
        gatewayConfig: const GatewayConfig(
          autoTls: true,
          autoTlsDomain: 'gateway.example.com',
          autoTlsAcceptTos: true,
          tlsPort: 8443,
        ),
        tlsManager: manager,
      );
      await server.start();

      expect(mockAdapter.lastSecureContext, same(context));
      expect(mockAdapter.lastSecurePort, equals(8443));
      expect(await server.isTlsActive(), isTrue);
      expect(await server.certificateExpiry(), isNotNull);
    });

    test('WSS route requires upgrade headers', () async {
      server = GatewayServer(
        blockStore: blockStore,
        httpAdapter: mockAdapter,
        gatewayConfig: const GatewayConfig(),
      );
      await server.start();
      final handler = mockAdapter.lastHandler!;

      final request = Request('GET', Uri.parse('http://localhost/ws'));
      final response = await handler(request);
      expect(response.statusCode, equals(426));
    });
  });
}

SecurityContext _createMinimalSecurityContext() {
  // A real SecurityContext needs valid PEM files. We return a fresh context
  // and let callers inject it through a mock AutoTlsProvider.
  return SecurityContext();
}

class _GeneratedCertificate {
  _GeneratedCertificate({required this.certPath, required this.keyPath});

  final String certPath;
  final String keyPath;
}

Future<_GeneratedCertificate?> _generateSelfSignedCertificate(
  String directory,
) async {
  final certPath = '$directory/cert.pem';
  final keyPath = '$directory/key.pem';

  try {
    final result = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-keyout',
      keyPath,
      '-out',
      certPath,
      '-days',
      '1',
      '-nodes',
      '-subj',
      '/CN=localhost',
      '-addext',
      'subjectAltName=DNS:localhost',
    ]);
    if (result.exitCode != 0) return null;
    return _GeneratedCertificate(certPath: certPath, keyPath: keyPath);
  } on ProcessException {
    return null;
  }
}
