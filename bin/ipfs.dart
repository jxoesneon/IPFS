// bin/ipfs.dart
// CLI entry point for dart_ipfs. Intended to be compiled with
// `dart compile exe bin/ipfs.dart -o build/ipfs`.

// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_server.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_server.dart';
import 'package:dart_ipfs/src/version.dart';

Future<void> main(List<String> args) async {
  final command = args.isEmpty ? 'daemon' : args.first;
  final commandArgs = args.skip(1).toList();

  switch (command) {
    case 'version':
    case '--version':
    case '-v':
      print('ipfs version $packageVersion');
    case 'daemon':
      await _runDaemon(commandArgs);
    case 'id':
      await _printId();
    case 'healthcheck':
      await _runHealthcheck();
    case 'help':
    case '--help':
    case '-h':
    default:
      _printUsage();
  }
}

void _printUsage() {
  print('''
Usage: ipfs <command> [options]

Commands:
  daemon       Run the IPFS daemon (default command)
  version      Print the version
  id           Print the node identity
  healthcheck  Query the daemon RPC API /api/v0/id
  help         Print this help message

Daemon options:
  --api-addr <multiaddr>       RPC API bind address (default: /ip4/127.0.0.1/tcp/5001)
  --gateway-addr <multiaddr>   Gateway bind address (default: /ip4/0.0.0.0/tcp/8080)

Environment variables:
  IPFS_DATA_DIR       Base directory for IPFS repository (default: ./ipfs_data)
  IPFS_CONFIG_PATH    Optional path to a JSON/YAML config file
  IPFS_JSON_LOGS      Set to "true" for structured JSON logging
  IPFS_API_ADDR       Default RPC API multiaddr (overridden by --api-addr)
  IPFS_GATEWAY_ADDR   Default gateway multiaddr (overridden by --gateway-addr)
''');
}

Future<void> _printId() async {
  final config = await _buildConfig();
  final node = await IPFSNode.create(config);
  final publicKey = await node.publicKey;
  print(
    jsonEncode({
      'ID': node.peerID,
      'PublicKey': publicKey,
      'Addresses': node.addresses,
      'AgentVersion': agentVersion,
    }),
  );
  await node.stop();
}

Future<void> _runHealthcheck() async {
  final apiAddr =
      Platform.environment['IPFS_API_ADDR'] ?? '/ip4/127.0.0.1/tcp/5001';
  final endpoint = _parseMultiaddrTcp(apiAddr);
  if (endpoint == null) {
    stderr.writeln('Invalid IPFS_API_ADDR: $apiAddr');
    exit(1);
  }

  final client = HttpClient();
  try {
    final request = await client.post('127.0.0.1', endpoint.port, '/api/v0/id');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode == 200) {
      stdout.write(body);
      exit(0);
    } else {
      stderr.writeln('Health check failed: ${response.statusCode}');
      exit(1);
    }
  } on SocketException catch (e) {
    stderr.writeln('Health check failed: $e');
    exit(1);
  } finally {
    client.close();
  }
}

Future<void> _runDaemon(List<String> args) async {
  final enableStructuredLogging =
      Platform.environment['IPFS_JSON_LOGS'] == 'true';

  final apiAddr =
      _parseAddrArg(args, '--api-addr') ??
      Platform.environment['IPFS_API_ADDR'] ??
      '/ip4/127.0.0.1/tcp/5001';
  final gatewayAddr =
      _parseAddrArg(args, '--gateway-addr') ??
      Platform.environment['IPFS_GATEWAY_ADDR'] ??
      '/ip4/0.0.0.0/tcp/8080';

  final apiEndpoint = _parseMultiaddrTcp(apiAddr);
  final gatewayEndpoint = _parseMultiaddrTcp(gatewayAddr);

  if (apiEndpoint == null) {
    stderr.writeln('Invalid --api-addr: $apiAddr');
    exit(1);
  }
  if (gatewayEndpoint == null) {
    stderr.writeln('Invalid --gateway-addr: $gatewayAddr');
    exit(1);
  }

  if (apiEndpoint.address == '0.0.0.0' || apiEndpoint.address == '::') {
    stderr.writeln(
      'WARNING: RPC API bound to all interfaces (${apiEndpoint.address}:${apiEndpoint.port}).',
    );
    stderr.writeln('         Use only in trusted networks.');
  }

  final config = await _buildConfig();

  print('Starting dart_ipfs daemon v$packageVersion');
  final node = await IPFSNode.create(config);
  await node.start();

  print('Node started with Peer ID: ${node.peerID}');
  print('Listening addresses:');
  for (final addr in node.addresses) {
    print('  $addr');
  }

  // Start HTTP Gateway
  final gateway = GatewayServer(
    blockStore: node.blockStore,
    node: node,
    address: gatewayEndpoint.address,
    port: gatewayEndpoint.port,
    corsOrigins: ['*'],
  );
  await gateway.start();
  print('Gateway running at: ${gateway.url}');

  // Start RPC API
  final rpc = RPCServer(
    node: node,
    address: apiEndpoint.address,
    port: apiEndpoint.port,
    corsOrigins: ['*'],
  );
  await rpc.start();
  print('RPC API running at: ${rpc.url}');

  if (enableStructuredLogging) {
    print(
      jsonEncode({
        'level': 'info',
        'message': 'daemon ready',
        'peer_id': node.peerID,
        'gateway_url': gateway.url,
        'rpc_url': rpc.url,
      }),
    );
  }

  // Wait for SIGTERM / SIGINT
  final exitCompleter = Completer<void>();
  ProcessSignal.sigterm.watch().listen((_) {
    if (!exitCompleter.isCompleted) exitCompleter.complete();
  });
  ProcessSignal.sigint.watch().listen((_) {
    if (!exitCompleter.isCompleted) exitCompleter.complete();
  });
  await exitCompleter.future;

  print('Shutting down...');
  await rpc.stop();
  await gateway.stop();
  await node.stop();
  print('Daemon stopped.');
}

String? _parseAddrArg(List<String> args, String flag) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == flag) {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $flag');
        exit(1);
      }
      return args[i + 1];
    }
    if (arg.startsWith('$flag=')) {
      return arg.substring(flag.length + 1);
    }
  }
  return null;
}

({String address, int port})? _parseMultiaddrTcp(String multiaddr) {
  final parts = multiaddr.split('/').where((s) => s.isNotEmpty).toList();
  if (parts.length < 3) return null;

  var ipIndex = parts.indexOf('ip4');
  if (ipIndex == -1) {
    ipIndex = parts.indexOf('ip6');
  }
  if (ipIndex == -1 || ipIndex + 2 >= parts.length) return null;

  if (parts[ipIndex + 2] != 'tcp') return null;
  final ip = parts[ipIndex + 1];
  final port = int.tryParse(parts[ipIndex + 3]);
  if (port == null || port < 1 || port > 65535) return null;

  return (address: ip, port: port);
}

Future<IPFSConfig> _buildConfig() async {
  final dataDir = Platform.environment['IPFS_DATA_DIR'] ?? './ipfs_data';
  final configPath = Platform.environment['IPFS_CONFIG_PATH'];
  final enableStructuredLogging =
      Platform.environment['IPFS_JSON_LOGS'] == 'true';

  IPFSConfig baseConfig;
  if (configPath != null) {
    baseConfig = await IPFSConfig.fromFile(configPath);
  } else {
    baseConfig = IPFSConfig();
  }

  // Merge environment overrides with file-provided config.
  return IPFSConfig.fromJson({
    ...baseConfig.toJson(),
    'dataPath': dataDir,
    'datastorePath': '$dataDir/datastore',
    'blockStorePath': '$dataDir/blocks',
    'keystorePath': '$dataDir/keystore',
    'enableStructuredLogging': enableStructuredLogging,
  });
}
