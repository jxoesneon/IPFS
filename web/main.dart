// ignore_for_file: avoid_print

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_web_node.dart';

/// Global web IPFS node instance.
IPFSWebNode? _node;
String? _lastCid;

// Define JS interop for the helper functions in index.html
// External functions removed in favor of globalContext.callMethod for reliability

/// Entry point for web IPFS node.
void main() async {
  print('Dart main() started'); // Fallback log

  // Export functions to window using JS interop
  print('Exporting global functions...');
  try {
    globalContext.setProperty('startNode'.toJS, (() => startNode()).toJS);
    globalContext.setProperty(
      'addTestContent'.toJS,
      (() => addTestContent()).toJS,
    );
    globalContext.setProperty(
      'getTestContent'.toJS,
      (() => getTestContent()).toJS,
    );
    globalContext.setProperty('addLargeFile'.toJS, (() => addLargeFile()).toJS);
    globalContext.setProperty(
      'toggleOffline'.toJS,
      (() => toggleOffline()).toJS,
    );
    print('Functions exported successfully.');
  } catch (e) {
    print('Failed to export functions: $e');
  }

  _log('Dart application loaded. Ready to start.');

  // Auto-start for convenience, but specific startNode button exists too
  startNode();
}

void startNode() async {
  _setStatus('Initializing...', 'running');
  _log('IPFS Web Node initializing...');

  try {
    if (_node != null) {
      _log('Node already running.');
      return;
    }

    _node = IPFSWebNode();
    await _node!.start();

    _setStatus('Running', 'done');
    _log('✓ IPFS Web Node started successfully!');
    _log('Node ID: ${_node!.peerID}');
    _log('Mode: Offline (local storage only)');
  } catch (e, st) {
    _setStatus('Error', 'error');
    _log('✗ Failed to start node: $e', 'error');
    print(st);
  }
}

/// Test function to add content to IPFS.
void addTestContent() async {
  if (_node == null) {
    _log('Node not started yet!', 'error');
    return;
  }

  try {
    _log('Adding test content...');
    final testData = 'Hello from IPFS Web! Timestamp: ${DateTime.now()}';
    final bytes = Uint8List.fromList(testData.codeUnits);

    final cid = await _node!.add(bytes);
    _lastCid = cid.encode();

    _log('✓ Content added! CID: $_lastCid', 'success');
  } catch (e) {
    _log('✗ Failed to add content: $e', 'error');
  }
}

/// Test function to get content from IPFS.
void getTestContent() async {
  if (_node == null) {
    _log('Node not started yet!', 'error');
    return;
  }

  if (_lastCid == null) {
    _log('No content added yet! Call addTestContent() first.', 'info');
    return;
  }

  try {
    _log('Retrieving content for CID: $_lastCid');
    final result = await _node!.get(_lastCid!);

    if (result != null) {
      final content = String.fromCharCodes(result);
      _log('✓ Content retrieved: $content', 'success');
    } else {
      _log('Content not found', 'error');
    }
  } catch (e) {
    _log('✗ Failed to get content: $e', 'error');
  }
}

/// Generates and adds a 2MB file to verify chunking.
void addLargeFile() async {
  if (_node == null) {
    _log('Node not started yet!', 'error');
    return;
  }

  try {
    _log('Generating 2MB test payload...');
    final size = 2 * 1024 * 1024;
    final bytes = Uint8List(size);
    for (var i = 0; i < size; i++) {
      bytes[i] = i % 256;
    }

    _log('Adding 2MB payload to IPFS... (this may take a moment)');
    final start = DateTime.now();
    final cid = await _node!.add(bytes);
    final elapsed = DateTime.now().difference(start);

    _lastCid = cid.encode();
    _log('✓ Large file added in ${elapsed.inMilliseconds}ms!', 'success');
    _log('CID: $_lastCid');

    // Immediate verification
    _log('Verifying content integrity...');
    final retrieved = await _node!.get(_lastCid!);
    if (retrieved != null && retrieved.length == size) {
      bool valid = true;
      for (var i = 0; i < size; i++) {
        if (retrieved[i] != i % 256) {
          valid = false;
          break;
        }
      }
      if (valid) {
        _log('✓ Integrity verified: 2MB matches exactly.', 'success');
      } else {
        _log('✗ Integrity check failed: Content mismatch.', 'error');
      }
    } else {
      _log('✗ Integrity check failed: Size mismatch or null.', 'error');
    }
  } catch (e) {
    _log('✗ Large file test failed: $e', 'error');
  }
}

/// Simulates offline/online toggling.
void toggleOffline() async {
  if (_node == null) {
    _log('Node not started yet!', 'error');
    return;
  }

  _log('Restarting node to simulate network reset...');
  _setStatus('Restarting...', 'running');

  try {
    await _node!.stop();
    _log('Node stopped.');
    _node = null; // Clear reference

    // Wait a bit
    await Future<void>.delayed(const Duration(milliseconds: 500));

    startNode();
    _log('Node restarted successfully.', 'success');
  } catch (e) {
    _log('✗ Failed to toggle node state: $e', 'error');
    _setStatus('Error', 'error');
  }
}

// Define JS interop for the helper functions in index.html - validation via globalContext below

/// Logs a message to the browser UI via JS interop.
void _log(String message, [String type = 'info']) {
  // Also log to console for debugging
  print('[Dart] $message');
  try {
    final func = globalContext.getProperty('logMessage'.toJS) as JSFunction;
    func.callAsFunction(null, message.toJS, type.toJS);
  } catch (e) {
    print('Failed to call JS log: $e');
  }
}

void _setStatus(String message, String className) {
  try {
    final func = globalContext.getProperty('setAppStatus'.toJS) as JSFunction;
    func.callAsFunction(null, message.toJS, className.toJS);
  } catch (e) {
    print('Failed to call JS setStatus: $e');
  }
}
