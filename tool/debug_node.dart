// Debug harness: start a node with stdout logging for interop diagnosis.
// Usage: dart run tool/debug_node.dart <swarm-port> [topic]
import 'dart:async';
import 'dart:io';

import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:logging/logging.dart' as logging;

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 4001 : int.parse(args[0]);
  final topic = args.length > 1 ? args[1] : null;
  final repo = Directory.systemTemp.createTempSync('ipfs-debug-node-');
  stderr.writeln('repo: ${repo.path}');

  logging.hierarchicalLoggingEnabled = true;
  logging.Logger.root.level = logging.Level.ALL;
  logging.Logger.root.onRecord.listen((r) {
    stderr.writeln(
      '${r.level.name} ${r.loggerName}: ${r.message}'
      '${r.error != null ? ' | ${r.error}' : ''}',
    );
  });

  final json = IPFSConfig().toJson();
  json['network'] = {
    'listenAddresses': ['/ip4/0.0.0.0/tcp/$port'],
    'enableMDNS': false,
    'bootstrapPeers': <String>[],
  };
  json['dataPath'] = repo.path;
  const swarmKey = String.fromEnvironment('SWARM_KEY');
  if (swarmKey.isNotEmpty) json['swarmKeyPath'] = swarmKey;
  final node = await IPFSNode.create(IPFSConfig.fromJson(json));
  await node.start();
  stderr.writeln('PEER_ID=${node.peerId}');
  stderr.writeln('ADDRS=${node.addresses}');

  if (topic != null) {
    await node.subscribe(topic);
    node.pubsubMessages.listen(
      (m) => stderr.writeln('MSGSTREAM topic=${m.topic} data=${m.content}'),
    );
    stderr.writeln('SUBSCRIBED=$topic');
    Timer.periodic(const Duration(seconds: 5), (_) async {
      final peers = await node.pubsubPeers(topic);
      stderr.writeln('TOPIC-PEERS=$peers');
    });
    if (args.length > 2 && args[2] == '--pub') {
      Timer.periodic(const Duration(seconds: 7), (_) async {
        try {
          await node.publish(
            topic,
            'hello-from-dart-${DateTime.now().millisecondsSinceEpoch}',
          );
          stderr.writeln('PUBLISHED');
        } catch (e) {
          stderr.writeln('PUB-ERR $e');
        }
      });
    }
  }

  // stdin commands: "pub <topic> <msg>"
  stdin.transform(const SystemEncoding().decoder).listen((line) {
    final parts = line.trim().split(' ');
    if (parts.length >= 3 && parts[0] == 'pub') {
      node
          .publish(parts[1], parts.sublist(2).join(' '))
          .then((_) => stderr.writeln('PUBLISHED'))
          .catchError((Object e) => stderr.writeln('PUB-ERR $e'));
    }
  });

  await Future<void>.delayed(const Duration(hours: 1));
}
