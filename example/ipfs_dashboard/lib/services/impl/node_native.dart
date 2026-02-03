import 'dart:async';
import 'package:dart_ipfs/dart_ipfs.dart';
import 'node_interface.dart';

import 'package:flutter/foundation.dart';

class NodeImplementation implements INodeImplementation {
  IPFSNode? _node;
  bool _isOnline = false;

  @override
  bool get isOnline => _isOnline;

  @override
  String get peerId => _node?.peerID ?? '';

  @override
  Future<void> start(Map<String, dynamic> configMap) async {
    final config = IPFSConfig(
      dataPath: configMap['dataPath'],
      offline: configMap['offline'] ?? false,
    );
    _node = await IPFSNode.create(config);
    await _node!.start();
    _isOnline = true;
  }

  @override
  Future<void> stop() async {
    if (_node != null) {
      await _node!.stop();
      _isOnline = false;
    }
  }

  @override
  Future<String?> addFile(dynamic content) async {
    if (_node == null) return null;
    // On native, content is Uint8List
    if (content is Uint8List) {
      final cid = await _node!.addFile(content);
      return cid.toString();
    }
    return null;
  }

  @override
  Future<dynamic> cat(String cid) async {
    if (_node == null) return null;
    return await _node!.cat(cid);
  }

  @override
  Future<List<String>> getPeers() async {
    if (_node == null) return [];
    return await _node!.connectedPeers;
  }

  @override
  Future<void> connect(String multiaddr) async {
    if (_node != null) {
      await _node!.connectToPeer(multiaddr);
    }
  }

  @override
  Future<void> disconnect(String peerIdOrAddr) async {
    if (_node != null) {
      await _node!.disconnectFromPeer(peerIdOrAddr);
    }
  }

  @override
  Future<void> subscribe(String topic) async {
    if (_node != null) {
      await _node!.subscribe(topic);
    }
  }

  @override
  Future<void> unsubscribe(String topic) async {
    if (_node != null) {
      await _node!.unsubscribe(topic);
    }
  }

  @override
  Future<void> publish(String topic, String message) async {
    if (_node != null) {
      await _node!.publish(topic, message);
    }
  }

  @override
  Stream<dynamic> get pubsubEvents {
    if (_node != null) {
      return _node!.pubsubMessages;
    }
    return const Stream.empty();
  }

  @override
  Stream<Map<String, dynamic>> get bandwidthMetrics =>
      _node?.bandwidthMetrics ?? const Stream.empty();

  @override
  Future<List<String>> getAddresses() async {
    return _node?.addresses ?? [];
  }

  @override
  void setGatewayMode(int modeIndex, String? customUrl) {
    if (_node != null) {
      if (modeIndex >= 0 && modeIndex < GatewayMode.values.length) {
        _node!.setGatewayMode(
          GatewayMode.values[modeIndex],
          customUrl: customUrl,
        );
      }
    }
  }

  @override
  Future<void> pin(String cid) async {
    if (_node != null) {
      await _node!.pin(cid);
    }
  }

  @override
  Future<bool> unpin(String cid) async {
    if (_node != null) {
      return await _node!.unpin(cid);
    }
    return false;
  }

  @override
  Future<List<String>> getPinnedCids() async {
    if (_node != null) {
      return await _node!.pinnedCids;
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> ls(String cid) async {
    if (_node != null) {
      // IPFSNode.ls returns List<Link>
      // Link class has name, size, cid
      try {
        final links = await _node!.ls(cid);
        return links
            .map(
              (link) => {
                'name': link.name,
                'cid': link.cid.toString(),
                'size': link.size.toInt(),
              },
            )
            .toList();
      } catch (e) {
        debugPrint('NodeNative ls error: $e');
        return [];
      }
    }
    return [];
  }
}

INodeImplementation getImplementation() => NodeImplementation();

