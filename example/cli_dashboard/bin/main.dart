import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_console/dart_console.dart';
import 'package:dart_ipfs/dart_ipfs.dart';

void main() {
  final dashboard = Dashboard();
  dashboard.run();
}

class Dashboard {
  final Console console = Console();
  IPFSNode? node;
  bool isRunning = false;
  String statusMessage = "Ready to start...";
  final List<String> logs = [];
  Timer? _refreshTimer;
  int _spinnerIndex = 0;
  final List<String> _spinner = ['|', '/', '-', '\\'];

  Dashboard() {
    // console.rawMode = true;
  }

  void run() {
    console.clearScreen();
    console.hideCursor();

    // Start refresh loop
    _refreshTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _draw();
      _spinnerIndex = (_spinnerIndex + 1) % _spinner.length;
    });

    _draw(); // Initial draw

    // Input loop - blocking read is fine for this simple demo if run in separate isolate,
    // but here we just block main thread. Ideally we'd scan keys.
    // Console.readKey blocks.
    while (true) {
      final key = console.readKey();

      if (key.controlChar == ControlCharacter.ctrlC || key.char == 'q') {
        _shutdown();
        break;
      }

      if (key.char == 's') {
        _toggleNode();
      } else if (key.char == 'a') {
        _addDemoContent();
      } else if (key.char == 'm') {
        _toggleGatewayMode();
      }
    }
  }

  Future<void> _toggleNode() async {
    if (isRunning) {
      statusMessage = "Stopping node...";
      _log("Stopping IPFS node...");
      // Stop is async, but we are in sync loop.
      // We trigger it and let future complete.
      await node?.stop();
      node = null;
      isRunning = false;
      statusMessage = "Node stopped.";
      _log("Node stopped.");
    } else {
      statusMessage = "Starting node...";
      _log("Initializing IPFS node...");
      try {
        final config = IPFSConfig(
          offline: false,
          // Distinct path for CLI demo
          dataPath: './cli_ipfs_data',
        );
        node = await IPFSNode.create(config);
        await node!.start();
        isRunning = true;
        statusMessage = "Node Online";
        _log("Node started! PeerID: ${node!.peerID}");
      } catch (e) {
        statusMessage = "Error starting node";
        _log("Error: $e");
        isRunning = false;
      }
    }
  }

  Future<void> _addDemoContent() async {
    if (!isRunning) {
      statusMessage = "Node must be running!";
      return;
    }

    statusMessage = "Adding content...";
    final content = "Hello from CLI Dashboard ${DateTime.now()}";
    final bytes = Uint8List.fromList(content.codeUnits);
    try {
      final cid = await node!.addFile(bytes);
      _log("Added content: '$content'");
      _log("CID: $cid");
      statusMessage = "Content added!";
    } catch (e) {
      _log("Error adding content: $e");
    }
  }

  void _log(String msg) {
    final time = DateTime.now().toIso8601String().split('T')[1].substring(0, 8);
    logs.insert(0, "[$time] $msg");
    if (logs.length > 20) logs.removeLast();
  }

  void _shutdown() {
    _refreshTimer?.cancel();
    console.clearScreen();
    console.resetColorAttributes();
    console.showCursor();
    print("Dashboard closed.");
    exit(0);
  }

  void _draw() {
    console.hideCursor();
    console.resetColorAttributes();

    final width = console.windowWidth;
    final height = console.windowHeight;

    // Draw Header
    console.cursorPosition = Coordinate(0, 0);
    console.setBackgroundColor(ConsoleColor.blue);
    console.setForegroundColor(ConsoleColor.white);
    console.write(" dart_ipfs CLI DASHBOARD ".padRight(width));
    console.resetColorAttributes();

    // Draw Status Pane
    console.cursorPosition = Coordinate(2, 2);
    console.setForegroundColor(ConsoleColor.green);
    console.write("STATUS: ");
    if (isRunning) {
      console.setForegroundColor(ConsoleColor.brightGreen);
      console.write("ONLINE ${_spinner[_spinnerIndex]}");
    } else {
      console.setForegroundColor(ConsoleColor.red);
      console.write("OFFLINE");
    }

    console.cursorPosition = Coordinate(3, 2);
    console.setForegroundColor(ConsoleColor.green);
    console.write("PEER ID: ");
    console.setForegroundColor(ConsoleColor.white);
    console.write(node?.peerID ?? "N/A");

    console.cursorPosition = Coordinate(4, 2);
    console.setForegroundColor(ConsoleColor.green);
    console.write("MSG: ");
    console.setForegroundColor(ConsoleColor.yellow);
    console.write(statusMessage.padRight(40));

    // Draw Controls Help
    console.cursorPosition = Coordinate(6, 0);
    console.write("═" * width);
    console.cursorPosition = Coordinate(7, 2);
    console.write(
        "[S] Start/Stop   [A] Add File   [M] Mode: ${_gatewayMode.name.toUpperCase()}   [Q] Quit");

    // Draw Logs Box
    console.cursorPosition = Coordinate(9, 0);
    console.write("═" * width);
    console.cursorPosition = Coordinate(10, 2);
    console.setForegroundColor(ConsoleColor.cyan);
    console.write("LOGS");

    int row = 11;
    for (var log in logs) {
      if (row >= height - 1) break;
      console.cursorPosition = Coordinate(row, 2);
      console.setForegroundColor(ConsoleColor.white);
      console.writeLine(log.padRight(width - 4));
      row++;
    }
  }

  GatewayMode _gatewayMode = GatewayMode.internal;
  String _customUrl = '';

  void _toggleGatewayMode() {
    // Cycle through modes
    final nextIndex = (_gatewayMode.index + 1) % GatewayMode.values.length;
    _gatewayMode = GatewayMode.values[nextIndex];

    if (_gatewayMode == GatewayMode.custom) {
      // Pause spinner/draw loop to get input
      _refreshTimer?.cancel();
      console.cursorPosition = Coordinate(8, 2);
      console.showCursor();
      console.write("Enter Custom URL: ");
      final input = console.readLine();
      if (input != null && input.isNotEmpty) {
        _customUrl = input;
        _log("Custom URL set to: $_customUrl");
      } else {
        _log("Invalid URL, reverting to Internal");
        _gatewayMode = GatewayMode.internal;
      }
      console.hideCursor();
      // Restart loop
      _refreshTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
        _draw();
        _spinnerIndex = (_spinnerIndex + 1) % _spinner.length;
      });
    }

    if (node != null) {
      node!.setGatewayMode(_gatewayMode,
          customUrl: _gatewayMode == GatewayMode.custom ? _customUrl : null);
      _log("Switched mode to ${_gatewayMode.name}");
    } else {
      _log("Mode set to ${_gatewayMode.name} (will apply on start)");
    }
  }
}
