// Web-only IPFS functionality that avoids p2plib dependencies.
//
// This provides a subset of IPFS functionality for web browsers
// without requiring the full P2P networking stack.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/platform/platform.dart';

/// A minimal IPFS node for web browsers.
///
/// This provides offline IPFS functionality without P2P networking:
/// - Add content and get CID
/// - Retrieve content by CID
/// - Local storage via IndexedDB
///
/// For full P2P functionality, run on native platforms (iOS, Android, desktop).
class IPFSWebNode {
  /// Creates a new web IPFS node.
  IPFSWebNode() {
    _platform = getPlatform();
  }

  late final IpfsPlatform _platform;
  final _store = <String, Uint8List>{};
  bool _started = false;
  String _nodeId = '';

  /// The node's peer ID (generated locally for web).
  String get peerID => _nodeId;

  /// Whether the node is running.
  bool get isRunning => _started;

  /// Starts the web node.
  Future<void> start() async {
    // Generate a random node ID for web
    final random = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      random[i] = DateTime.now().microsecond % 256;
    }
    _nodeId = 'web-${sha256.convert(random).toString().substring(0, 12)}';
    _started = true;
  }

  /// Stops the web node.
  Future<void> stop() async {
    _started = false;
  }

  /// Adds data and returns its CID.
  Future<CID> add(Uint8List data) async {
    // Create a CID using the fromContent factory
    final cid = await CID.fromContent(
      data,
      codec: 'raw',
      hashType: 'sha2-256',
      version: 1,
    );

    // Store the block
    final cidStr = cid.encode();
    _store[cidStr] = data;

    // Persist to IndexedDB
    await _platform.writeBytes('blocks/$cidStr', data);

    return cid;
  }

  /// Gets data by CID string.
  Future<Uint8List?> get(String cidString) async {
    // Try memory cache first
    if (_store.containsKey(cidString)) {
      return _store[cidString];
    }

    // Try IndexedDB
    final data = await _platform.readBytes('blocks/$cidString');
    if (data != null) {
      _store[cidString] = data;
      return data;
    }

    return null;
  }

  /// Gets data by CID object.
  Future<Uint8List?> cat(CID cid) async {
    return get(cid.encode());
  }

  /// Pins a CID (marks it as persistent).
  Future<void> pin(CID cid) async {
    await _platform.writeBytes('pins/${cid.encode()}', Uint8List(0));
  }

  /// Unpins a CID.
  Future<void> unpin(CID cid) async {
    await _platform.delete('pins/${cid.encode()}');
  }

  /// Lists all pinned CIDs.
  Future<List<String>> listPins() async {
    return _platform.listDirectory('pins');
  }
}
