import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'impl/node_interface.dart';
import 'impl/node_stub.dart'
    if (dart.library.io) 'impl/node_native.dart'
    if (dart.library.html) 'impl/node_web.dart';

import 'package:dart_ipfs/dart_ipfs.dart';

/// Service managing the IPFS Node life-cycle and state.
///
/// Acts as a bridge between the Flutter UI and the underlying [IPFSNode] implementation.
class NodeService extends ChangeNotifier {
  final INodeImplementation _impl = getImplementation();
  final List<String> _logs = [];
  GatewayMode _gatewayMode = GatewayMode.internal;

  // Bandwidth Tracking
  double _uploadRate = 0;
  double _downloadRate = 0;
  int _lastSent = 0;
  int _lastReceived = 0;
  DateTime _lastMetricTime = DateTime.now();

  String _username = '';

  NodeService() {
    _username =
        'Peer_${peerId.length > 6 ? peerId.substring(peerId.length - 6) : "User"}';
    _setupMetricsListener();
    startNode();
  }

  double get uploadRate => _uploadRate;
  double get downloadRate => _downloadRate;
  String get username => _username;

  void setUsername(String name) {
    if (name.isNotEmpty) {
      _username = name;
      notifyListeners();
    }
  }

  void _setupMetricsListener() {
    bandwidthMetrics.listen((data) {
      if (!isOnline) return;

      final now = DateTime.now();
      final duration = now.difference(_lastMetricTime).inMilliseconds / 1000.0;
      if (duration < 0.5) return; // Ignore too frequent updates

      final sent = (data['totalSent'] as num?)?.toInt() ?? 0;
      final received = (data['totalReceived'] as num?)?.toInt() ?? 0;

      if (_lastSent > 0) {
        _uploadRate = (sent - _lastSent) / duration;
        _downloadRate = (received - _lastReceived) / duration;
      }

      _lastSent = sent;
      _lastReceived = received;
      _lastMetricTime = now;
      notifyListeners();
    });
  }

  /// Whether the node is currently running (`online`).
  bool get isOnline => _impl.isOnline;

  /// The Peer ID of the running node.
  String get peerId => _impl.peerId;

  /// Current Gateway Mode.
  GatewayMode get gatewayMode => _gatewayMode;

  /// Logs from the node service.
  List<String> get logs => List.unmodifiable(_logs);

  /// Updates the Gateway Mode for content retrieval.
  ///
  /// [mode] The new mode to switch to.
  /// [customUrl] Optional URL for [GatewayMode.custom].
  void setGatewayMode(GatewayMode mode, {String? customUrl}) {
    _gatewayMode = mode;
    _impl.setGatewayMode(mode.index, customUrl);
    _log('Switched to ${mode.name} mode');
    // notifyListeners is called by _log, but let's ensure it updates
    notifyListeners();
  }

  /// Starts the IPFS node with platform-specific configuration.
  Future<void> startNode() async {
    try {
      _log('Initializing node...');

      String dataPath = './ipfs_data';
      // path_provider only works on mobile/desktop, not web (or behaves differently)
      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        dataPath = '${appDir.path}/ipfs_data';
      }

      await _impl.start({'dataPath': dataPath, 'offline': false});

      if (_impl.isOnline) {
        _log('Node started! Peer ID: $peerId');
        if (kIsWeb) {
          _log('⚠️ RUNNING IN WEB DEMO MODE (Mock Node)');
        } else {
          _log('Swarm listening on addresses...');
        }
      }

      notifyListeners();
    } catch (e) {
      _log('Error starting node: $e');
      notifyListeners();
    }
  }

  /// Stops the running node.
  Future<void> stopNode() async {
    if (isOnline) {
      _log('Stopping node...');
      await _impl.stop();
      _log('Node stopped.');
      notifyListeners();
    }
  }

  Future<String?> addFile(dynamic pathOrBytes) async {
    if (!isOnline) return null;
    try {
      dynamic content;
      if (kIsWeb) {
        // file_picker on web returns bytes directly usually, or we handle it in UI
        // For simplicity in this demo, we assume the UI passed bytes or we handle it
        _log('Adding file from Web... (Simulation)');
        // In web, we might get bytes or a customized object.
        // For the mock, we just pass what we get or a dummy.
        content = Uint8List(10); // Dummy for mock
      } else {
        _log('Adding file: $pathOrBytes');
        final file = File(pathOrBytes);
        content = await file.readAsBytes();
      }

      final cid = await _impl.addFile(content);
      _log('File added. CID: $cid');
      return cid;
    } catch (e) {
      _log('Error adding file: $e');
      return null;
    }
  }

  Future<Uint8List?> cat(String cidStr) async {
    if (!isOnline) return null;
    try {
      _log('Retrieving CID: $cidStr');
      final data = await _impl.cat(cidStr);
      if (data != null) {
        // data should be Uint8List
        if (data is Uint8List) {
          _log('Retrieved ${data.length} bytes.');
          return data;
        } else {
          _log('Retrieved content (Mock)');
          return Uint8List(0);
        }
      } else {
        _log('Content not found.');
      }
      return data as Uint8List?;
    } catch (e) {
      _log('Error retrieving content: $e');
      return null;
    }
  }

  Future<List<String>> getPeers() async {
    if (!isOnline) return [];
    try {
      return await _impl.getPeers();
    } catch (e) {
      _log('Error listing peers: $e');
      return [];
    }
  }

  Future<List<String>> getAddresses() async {
    if (!isOnline) return [];
    try {
      return await _impl.getAddresses();
    } catch (e) {
      _log('Error getting addresses: $e');
      return [];
    }
  }

  Future<void> connectPeer(String addr) async {
    try {
      _log('Connecting to $addr...');
      await _impl.connect(addr);
      _log('Connected to peer.');
      notifyListeners();
    } catch (e) {
      _log('Error connecting: $e');
    }
  }

  Future<void> disconnectPeer(String peerId) async {
    try {
      _log('Disconnecting $peerId...');
      await _impl.disconnect(peerId);
      _log('Disconnected peer.');
      notifyListeners();
    } catch (e) {
      _log('Error disconnecting: $e');
    }
  }

  // PubSub Methods

  Stream<dynamic> get pubsubEvents => _impl.pubsubEvents;
  Stream<Map<String, dynamic>> get bandwidthMetrics => _impl.bandwidthMetrics;

  Future<void> subscribe(String topic) async {
    if (!isOnline) return;
    try {
      _log('Subscribing to $topic...');
      await _impl.subscribe(topic);
    } catch (e) {
      _log('Error subscribing: $e');
    }
  }

  Future<void> unsubscribe(String topic) async {
    if (!isOnline) return;
    try {
      _log('Unsubscribing from $topic...');
      await _impl.unsubscribe(topic);
    } catch (e) {
      _log('Error unsubscribing: $e');
    }
  }

  Future<void> publish(String topic, String message) async {
    if (!isOnline) return;
    try {
      _log('Publishing to $topic...');
      await _impl.publish(topic, message);
    } catch (e) {
      _log('Error publishing: $e');
    }
  }

  Future<void> pin(String cid) async {
    if (!isOnline) return;
    try {
      _log('Pinning CID: $cid...');
      await _impl.pin(cid);
      _log('Pinned: $cid');
    } catch (e) {
      _log('Error pinning: $e');
    }
  }

  Future<void> unpin(String cid) async {
    if (!isOnline) return;
    try {
      _log('Unpinning CID: $cid...');
      await _impl.unpin(cid);
      _log('Unpinned: $cid');
    } catch (e) {
      _log('Error unpinning: $e');
    }
  }

  Future<List<String>> getPinnedCids() async {
    if (!isOnline) return [];
    try {
      return await _impl.getPinnedCids();
    } catch (e) {
      _log('Error listing pins: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> ls(String cid) async {
    if (!isOnline) return [];
    try {
      _log('Listing directory: $cid');
      return await _impl.ls(cid);
    } catch (e) {
      _log('Error listing CID $cid: $e');
      return [];
    }
  }

  void _log(String msg) {
    if (kDebugMode) print(msg);
    final time = DateTime.now().toIso8601String().split('T')[1].substring(0, 8);
    _logs.insert(0, "[$time] $msg");
    if (_logs.length > 50) _logs.removeLast();
    Future.microtask(() => notifyListeners());
  }
}
