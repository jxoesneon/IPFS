// bin/ipfs.dart
// CLI entry point for dart_ipfs. Intended to be compiled with
// `dart compile exe bin/ipfs.dart -o build/ipfs`.

// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_server.dart';
import 'package:dart_ipfs/src/services/rpc/rpc_server.dart';
import 'package:dart_ipfs/src/version.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>('ipfs', 'dart_ipfs command-line interface')
    ..argParser.addOption(
      'config',
      help: 'Path to a JSON or YAML configuration file',
    )
    ..addCommand(DaemonCommand())
    ..addCommand(VersionCommand())
    ..addCommand(IdCommand())
    ..addCommand(HealthcheckCommand())
    ..addCommand(AddCommand())
    ..addCommand(CatCommand())
    ..addCommand(LsCommand())
    ..addCommand(PinCommand())
    ..addCommand(UnpinCommand())
    ..addCommand(SwarmCommand())
    ..addCommand(ConfigCommand());

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    exit(1);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

abstract class IpfsCommand extends Command<void> {
  String? get configPath => globalResults?['config'] as String?;

  Future<IPFSConfig> buildConfig() => _buildConfig(configPath: configPath);

  String? get effectiveConfigPath =>
      configPath ?? Platform.environment['IPFS_CONFIG_PATH'];

  void printJson(Object? value) {
    print(jsonEncode(value));
  }
}

class DaemonCommand extends IpfsCommand {
  DaemonCommand() {
    argParser
      ..addOption(
        'api-addr',
        help: 'RPC API bind address',
        defaultsTo: Platform.environment['IPFS_API_ADDR'] ??
            '/ip4/127.0.0.1/tcp/5001',
      )
      ..addOption(
        'gateway-addr',
        help: 'Gateway bind address',
        defaultsTo: '/ip4/0.0.0.0/tcp/8080',
      )
      ..addOption(
        'swarm-addr',
        help: 'Swarm listen address',
        defaultsTo: '/ip4/0.0.0.0/tcp/4001',
      );
  }

  @override
  final String name = 'daemon';

  @override
  final String description = 'Run the IPFS daemon';

  @override
  Future<void> run() async {
    final enableStructuredLogging =
        Platform.environment['IPFS_JSON_LOGS'] == 'true';

    final apiAddr = argResults!['api-addr'] as String;
    final gatewayAddr = argResults!['gateway-addr'] as String;
    final swarmAddr = argResults!['swarm-addr'] as String;

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
    if (_parseMultiaddrTcp(swarmAddr) == null) {
      stderr.writeln('Invalid --swarm-addr: $swarmAddr');
      exit(1);
    }

    if (!_isLocalhost(apiEndpoint.address)) {
      stderr.writeln(
        'WARNING: RPC API bound to ${apiEndpoint.address}:${apiEndpoint.port}.',
      );
      stderr.writeln('         Remote RPC access is dangerous; use with care.');
    }

    final config = await buildConfig();
    final configJson = config.toJson();
    configJson['libp2pListenAddress'] = swarmAddr;

    final mergedConfig = IPFSConfig.fromJson(configJson);

    print('Starting dart_ipfs daemon v$packageVersion');
    final node = await IPFSNode.create(mergedConfig);
    await node.start();

    print('Node started with Peer ID: ${node.peerID}');
    print('Listening addresses:');
    for (final addr in node.addresses) {
      print('  $addr');
    }

    final gateway = GatewayServer(
      blockStore: node.blockStore,
      node: node,
      address: gatewayEndpoint.address,
      port: gatewayEndpoint.port,
      corsOrigins: ['*'],
    );
    await gateway.start();
    print('Gateway running at: ${gateway.url}');

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

    final exitCompleter = Completer<void>();
    _listenForSignal(ProcessSignal.sigterm, exitCompleter);
    _listenForSignal(ProcessSignal.sigint, exitCompleter);
    await exitCompleter.future;

    print('Shutting down...');
    await rpc.stop();
    await gateway.stop();
    await node.stop();
    print('Daemon stopped.');
  }
}

void _listenForSignal(ProcessSignal signal, Completer<void> completer) {
  try {
    signal.watch().listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
  } catch (e) {
    // Signal may be unsupported on the current platform.
  }
}

class VersionCommand extends IpfsCommand {
  @override
  final String name = 'version';

  @override
  final String description = 'Print the version';

  @override
  Future<void> run() async {
    print('ipfs version $packageVersion');
  }
}

class IdCommand extends IpfsCommand {
  @override
  final String name = 'id';

  @override
  final String description = 'Print the node identity';

  @override
  Future<void> run() async {
    final config = await buildConfig();
    final node = await IPFSNode.create(config);
    try {
      printJson({
        'ID': node.peerID,
        'PublicKey': await node.publicKey,
        'Addresses': node.addresses,
        'AgentVersion': agentVersion,
        'ProtocolVersion': 'ipfs/0.1.0',
        'Protocols': ['/ipfs/kad/1.0.0', '/ipfs/bitswap/1.2.0'],
      });
    } finally {
      await node.stop();
    }
  }
}

class HealthcheckCommand extends IpfsCommand {
  @override
  final String name = 'healthcheck';

  @override
  final String description = 'Query the daemon RPC API /api/v0/id';

  @override
  Future<void> run() async {
    final apiAddr =
        Platform.environment['IPFS_API_ADDR'] ?? '/ip4/127.0.0.1/tcp/5001';
    final endpoint = _parseMultiaddrTcp(apiAddr);
    if (endpoint == null) {
      stderr.writeln('Invalid IPFS_API_ADDR: $apiAddr');
      exit(1);
    }

    final client = HttpClient();
    try {
      final request = await client.post(
        '127.0.0.1',
        endpoint.port,
        '/api/v0/id',
      );
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
}

class AddCommand extends IpfsCommand {
  AddCommand() {
    argParser
      ..addFlag(
        'recursive',
        abbr: 'r',
        help: 'Add directory contents recursively',
        defaultsTo: false,
      )
      ..addFlag(
        'wrap-with-directory',
        help: 'Wrap files in a directory',
        defaultsTo: false,
      )
      ..addFlag('pin', help: 'Pin the added content', defaultsTo: true)
      ..addFlag(
        'quieter',
        abbr: 'q',
        help: 'Only print the CID',
        defaultsTo: false,
      );
  }

  @override
  final String name = 'add';

  @override
  final String description = 'Add a file or directory to IPFS';

  @override
  Future<void> run() async {
    final paths = argResults!.rest;
    if (paths.isEmpty) {
      stderr.writeln('Usage: ipfs add <path>');
      exit(1);
    }
    if (paths.length > 1) {
      stderr.writeln('Only a single path is supported');
      exit(1);
    }

    final path = paths.first;
    final wrap = argResults!['wrap-with-directory'] as bool;
    final pin = argResults!['pin'] as bool;
    final recursive = argResults!['recursive'] as bool;
    final quieter = argResults!['quieter'] as bool;

    final config = await buildConfig();
    final node = await IPFSNode.create(config);
    try {
      final file = File(path);
      final directory = Directory(path);

      final String cid;
      if (await file.exists()) {
        final data = await file.readAsBytes();
        if (wrap) {
          cid = await node.addDirectory({p.basename(path): data});
        } else {
          cid = await node.addFile(data);
        }
      } else if (await directory.exists()) {
        if (!recursive) {
          stderr.writeln(
            'Error: $path is a directory; use --recursive to add it',
          );
          exit(1);
        }
        final map = await _readDirectory(directory);
        cid = await node.addDirectory(map);
      } else {
        stderr.writeln('Error: path not found: $path');
        exit(1);
      }

      if (pin) {
        await node.pin(cid);
      }

      if (quieter) {
        print(cid);
      } else {
        printJson({'Name': p.basename(path), 'Hash': cid, 'Size': '0'});
      }
    } finally {
      await node.stop();
    }
  }
}

Future<Map<String, dynamic>> _readDirectory(Directory dir) async {
  final result = <String, dynamic>{};
  await for (final entity in dir.list(recursive: false, followLinks: false)) {
    final name = p.basename(entity.path);
    if (entity is File) {
      result[name] = await entity.readAsBytes();
    } else if (entity is Directory) {
      result[name] = await _readDirectory(entity);
    }
  }
  return result;
}

class CatCommand extends IpfsCommand {
  CatCommand() {
    argParser.addOption('output', abbr: 'o', help: 'Write output to a file');
  }

  @override
  final String name = 'cat';

  @override
  final String description = 'Retrieve raw content for a CID';

  @override
  Future<void> run() async {
    final cids = argResults!.rest;
    if (cids.isEmpty) {
      stderr.writeln('Usage: ipfs cat <cid>');
      exit(1);
    }

    final cid = cids.first;
    final output = argResults!['output'] as String?;

    final config = await buildConfig();
    final node = await IPFSNode.create(config);
    try {
      final content = await node.cat(cid);
      if (content == null) {
        stderr.writeln('Error: CID not found: $cid');
        exit(1);
      }
      final bytes = Uint8List.fromList(content);
      if (output != null) {
        await File(output).writeAsBytes(bytes);
      } else {
        stdout.add(bytes);
      }
    } finally {
      await node.stop();
    }
  }
}

class LsCommand extends IpfsCommand {
  @override
  final String name = 'ls';

  @override
  final String description = 'List directory links for a CID';

  @override
  Future<void> run() async {
    final cids = argResults!.rest;
    if (cids.isEmpty) {
      stderr.writeln('Usage: ipfs ls <cid>');
      exit(1);
    }

    final cid = cids.first;
    final config = await buildConfig();
    final node = await IPFSNode.create(config);
    try {
      final entries = await node.ls(cid);
      final links = entries
          .map(
            (e) => {
              'Name': e.name,
              'Hash': e.cid.toString(),
              'Size': e.size.toInt(),
              'Type': 'file',
            },
          )
          .toList();
      printJson({
        'Objects': [
          {'Hash': cid, 'Links': links},
        ],
      });
    } finally {
      await node.stop();
    }
  }
}

class PinCommand extends IpfsCommand {
  @override
  final String name = 'pin';

  @override
  final String description = 'Pin a CID';

  @override
  Future<void> run() async {
    final cids = argResults!.rest;
    if (cids.isEmpty) {
      stderr.writeln('Usage: ipfs pin <cid>');
      exit(1);
    }

    final config = await buildConfig();
    final node = await IPFSNode.create(config);
    await node.start();
    try {
      for (final cid in cids) {
        await node.pin(cid);
      }
      printJson({'Pins': cids});
    } finally {
      await node.stop();
    }
  }
}

class UnpinCommand extends IpfsCommand {
  @override
  final String name = 'unpin';

  @override
  final String description = 'Unpin a CID';

  @override
  Future<void> run() async {
    final cids = argResults!.rest;
    if (cids.isEmpty) {
      stderr.writeln('Usage: ipfs unpin <cid>');
      exit(1);
    }

    final config = await buildConfig();
    final node = await IPFSNode.create(config);
    await node.start();
    try {
      final removed = <String>[];
      for (final cid in cids) {
        if (await node.unpin(cid)) {
          removed.add(cid);
        }
      }
      printJson({'Pins': removed});
    } finally {
      await node.stop();
    }
  }
}

class SwarmCommand extends Command<void> {
  SwarmCommand() {
    addSubcommand(SwarmPeersCommand());
    addSubcommand(SwarmConnectCommand());
    addSubcommand(SwarmDisconnectCommand());
  }

  @override
  final String name = 'swarm';

  @override
  final String description = 'Manage swarm peers';

  @override
  Future<void> run() async {
    // Subcommands handle execution.
  }
}

abstract class _SwarmBaseCommand extends IpfsCommand {
  @override
  Command<void> get parent => super.parent!;

  @override
  String? get configPath => parent.globalResults?['config'] as String?;
}

class SwarmPeersCommand extends _SwarmBaseCommand {
  @override
  final String name = 'peers';

  @override
  final String description = 'List connected peers';

  @override
  Future<void> run() async {
    final config = await buildConfig();
    final node = await IPFSNode.create(config);
    try {
      final peers = await node.connectedPeers;
      final peerList = peers.map((p) => {'Peer': p, 'Addr': ''}).toList();
      printJson({'Peers': peerList});
    } finally {
      await node.stop();
    }
  }
}

class SwarmConnectCommand extends _SwarmBaseCommand {
  @override
  final String name = 'connect';

  @override
  final String description = 'Connect to a peer';

  @override
  Future<void> run() async {
    final addrs = argResults!.rest;
    if (addrs.isEmpty) {
      stderr.writeln('Usage: ipfs swarm connect <multiaddr>');
      exit(1);
    }

    final config = await buildConfig();
    final node = await IPFSNode.create(config);
    try {
      for (final addr in addrs) {
        await node.connectToPeer(addr);
      }
      printJson({'Strings': addrs.map((a) => 'connect $a success').toList()});
    } finally {
      await node.stop();
    }
  }
}

class SwarmDisconnectCommand extends _SwarmBaseCommand {
  @override
  final String name = 'disconnect';

  @override
  final String description = 'Disconnect from a peer';

  @override
  Future<void> run() async {
    final addrs = argResults!.rest;
    if (addrs.isEmpty) {
      stderr.writeln('Usage: ipfs swarm disconnect <multiaddr>');
      exit(1);
    }

    final config = await buildConfig();
    final node = await IPFSNode.create(config);
    try {
      for (final addr in addrs) {
        await node.disconnectFromPeer(addr);
      }
      printJson({
        'Strings': addrs.map((a) => 'disconnect $a success').toList(),
      });
    } finally {
      await node.stop();
    }
  }
}

class ConfigCommand extends IpfsCommand {
  @override
  final String name = 'config';

  @override
  final String description = 'Get or set configuration values';

  @override
  Future<void> run() async {
    final args = argResults!.rest;
    if (args.isEmpty) {
      final config = await buildConfig();
      printJson(config.toJson());
      return;
    }

    final key = args.first;
    if (args.length == 1) {
      final config = await buildConfig();
      final value = _getConfigValue(config.toJson(), key);
      if (value == null) {
        stderr.writeln('Error: config key not found: $key');
        exit(1);
      }
      printJson(value);
      return;
    }

    final value = args.sublist(1).join(' ');
    final configPath = effectiveConfigPath;
    if (configPath == null) {
      stderr.writeln(
        'Error: --config or IPFS_CONFIG_PATH required to set values',
      );
      exit(1);
    }

    final file = File(configPath);
    if (!await file.exists()) {
      stderr.writeln('Error: config file not found: $configPath');
      exit(1);
    }

    final content = await file.readAsString();
    final jsonMap = json.decode(content) as Map<String, dynamic>;
    _setConfigValue(jsonMap, key, _parseValue(value));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonMap),
    );
    printJson({'Key': key, 'Value': _parseValue(value)});
  }
}

dynamic _getConfigValue(Map<String, dynamic> config, String key) {
  final parts = key.split('.');
  dynamic current = config;
  for (final part in parts) {
    if (current is! Map<String, dynamic>) return null;
    current = current[part];
  }
  return current;
}

void _setConfigValue(Map<String, dynamic> config, String key, dynamic value) {
  final parts = key.split('.');
  dynamic current = config;
  for (var i = 0; i < parts.length - 1; i++) {
    final part = parts[i];
    if (current is! Map<String, dynamic>) return;
    current[part] ??= <String, dynamic>{};
    current = current[part];
  }
  if (current is Map<String, dynamic>) {
    current[parts.last] = value;
  }
}

dynamic _parseValue(String value) {
  if (value == 'true') return true;
  if (value == 'false') return false;
  final number = num.tryParse(value);
  if (number != null) return number;
  try {
    return json.decode(value);
  } catch (_) {
    return value;
  }
}

Future<IPFSConfig> _buildConfig({String? configPath}) async {
  final dataDir = Platform.environment['IPFS_DATA_DIR'] ?? './ipfs_data';
  final envConfigPath = Platform.environment['IPFS_CONFIG_PATH'];
  final enableStructuredLogging =
      Platform.environment['IPFS_JSON_LOGS'] == 'true';

  final effectiveConfigPath = configPath ?? envConfigPath;

  IPFSConfig baseConfig;
  if (effectiveConfigPath != null) {
    final configFile = File(effectiveConfigPath);
    if (!await configFile.exists()) {
      // Auto-initialize a minimal default config so CLI commands can run
      // even when the expected config file has not been created yet.
      await configFile.parent.create(recursive: true);
      await configFile.writeAsString(
        jsonEncode(<String, dynamic>{
          'offline': true,
          'customConfig': <String, dynamic>{},
        }),
      );
    }
    baseConfig = await IPFSConfig.fromFile(effectiveConfigPath);
  } else {
    baseConfig = IPFSConfig();
  }

  return IPFSConfig.fromJson({
    ...baseConfig.toJson(),
    'dataPath': dataDir,
    'datastorePath': '$dataDir/datastore',
    'blockStorePath': '$dataDir/blocks',
    'keystorePath': '$dataDir/keystore',
    'enableStructuredLogging': enableStructuredLogging,
  });
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

bool _isLocalhost(String address) {
  return address == '127.0.0.1' || address == '::1' || address == 'localhost';
}
