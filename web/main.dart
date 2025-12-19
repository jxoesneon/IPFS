import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_web_node.dart';
import 'package:web/web.dart' as web;

/// Global web IPFS node instance.
IPFSWebNode? _node;
String? _lastCid;

/// Entry point for web IPFS node.
void main() async {
  _log('IPFS Web Node initializing...');

  try {
    _node = IPFSWebNode();
    await _node!.start();

    _log('✓ IPFS Web Node started successfully!');
    _log('Node ID: ${_node!.peerID}');
    _log('Mode: Offline (local storage only)');
    _log('');
    _log('Available commands in console:');
    _log('  addTestContent() - Add test data');
    _log('  getTestContent() - Retrieve last added data');
  } catch (e, st) {
    _log('✗ Failed to start node: $e');
    _log('Stack trace: $st');
  }
}

/// Test function to add content to IPFS.
void addTestContent() async {
  if (_node == null) {
    _log('Node not started yet!');
    return;
  }

  try {
    _log('Adding test content...');
    final testData = 'Hello from IPFS Web! Timestamp: ${DateTime.now()}';
    final bytes = Uint8List.fromList(testData.codeUnits);

    final cid = await _node!.add(bytes);
    _lastCid = cid.encode();

    _log('✓ Content added!');
    _log('CID: $_lastCid');
  } catch (e) {
    _log('✗ Failed to add content: $e');
  }
}

/// Test function to get content from IPFS.
void getTestContent() async {
  if (_node == null) {
    _log('Node not started yet!');
    return;
  }

  if (_lastCid == null) {
    _log('No content added yet! Call addTestContent() first.');
    return;
  }

  try {
    _log('Retrieving content for CID: $_lastCid');
    final result = await _node!.get(_lastCid!);

    if (result != null) {
      final content = String.fromCharCodes(result);
      _log('✓ Content retrieved: $content');
    } else {
      _log('Content not found');
    }
  } catch (e) {
    _log('✗ Failed to get content: $e');
  }
}

/// Logs a message to the browser console.
void _log(String message) {
  web.console.log('[IPFS] $message'.toJS);
}
