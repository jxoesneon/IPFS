// ignore_for_file: avoid_print, prefer_single_quotes, unawaited_futures
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_console/dart_console.dart';
import 'package:dart_ipfs/dart_ipfs.dart';

void main() {
  final dashboard = Dashboard();
  dashboard.run();
}

enum DashboardMode { home, peers, chat, files, explorer }

class Dashboard {
  final Console console = Console();
  IPFSNode? node;
  bool isRunning = false;
  String statusMessage = "Ready to start...";
  final List<String> logs = [];
  Timer? _refreshTimer; // UI Refresh
  Timer? _statsTimer; // Bandwidth stats update
  int _spinnerIndex = 0;
  final List<String> _spinner = ['|', '/', '-', '\\'];

  // State
  DashboardMode _mode = DashboardMode.home;
  GatewayMode _gatewayMode = GatewayMode.internal;
  String _customUrl = '';

  // Bandwidth Stats
  double _inRate = 0.0;
  double _outRate = 0.0;
  int _lastInBytes = 0;
  int _lastOutBytes = 0;
  int _lastTimestamp = 0;

  Dashboard() {
    // console.rawMode = true;
  }

  Future<void> run() async {
    console.clearScreen();
    console.hideCursor();

    // Start auto-start if possible (or just wait for user)
    // _toggleNode();

    // Refresh Loop (UI)
    _refreshTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _draw();
      _spinnerIndex = (_spinnerIndex + 1) % _spinner.length;
    });

    // Stats Loop (1s)
    _statsTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateStats();
    });

    _draw();

    // Input Loop
    while (true) {
      final key = console.readKey();

      if (key.controlChar == ControlCharacter.ctrlC) {
        _shutdown();
        break;
      }

      // Global Keys
      if (key.char == 'q') {
        _shutdown();
        break;
      }

      // Mode Switching
      if (key.char == 'h') {
        _mode = DashboardMode.home;
        _log("Mode: Home");
      }
      if (key.char == 'p') {
        _mode = DashboardMode.peers;
        _log("Mode: Peers");
      }
      if (key.char == 'c') {
        _mode = DashboardMode.chat;
        _log("Mode: Chat");
      }
      if (key.char == 'f') {
        _mode = DashboardMode.files;
        _log("Mode: Files");
      }
      if (key.char == 'e') {
        _mode = DashboardMode.explorer;
        _log("Mode: Explorer");
      }

      // Mode Specific Handling
      switch (_mode) {
        case DashboardMode.home:
          _handleHomeInput(key);
          break;
        case DashboardMode.peers:
          _handlePeersInput(key);
          break;
        case DashboardMode.chat:
          _handleChatInput(key);
          break;
        case DashboardMode.files:
          _handleFilesInput(key);
          break;
        case DashboardMode.explorer:
          _handleExplorerInput(key);
          break;
      }
    }
  }

  Future<void> _updateStats() async {
    if (node != null && isRunning) {
      try {
        _peersCache = await node!.connectedPeers;
        _pinsCache = await node!.pinnedCids;
      } catch (_) {}
    }
  }

  void _handleHomeInput(Key key) {
    if (key.char == 's') _toggleNode();
    if (key.char == 'a') _addDemoContent();
    if (key.char == 'm') _toggleGatewayMode();
  }

  Future<void> _handlePeersInput(Key key) async {
    if (key.char == 'a') {
      // Add Peer
      _refreshTimer?.cancel();
      console.cursorPosition = Coordinate(8, 2);
      console.showCursor();
      console.write("Enter Multiaddr to connect: ");
      final input = console.readLine();
      if (input != null && input.isNotEmpty) {
        try {
          await node?.connectToPeer(input);
          _log("Connected to $input");
        } catch (e) {
          _log("Connection failed: $e");
        }
      }
      console.hideCursor();
      _refreshTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
        _draw();
        _spinnerIndex = (_spinnerIndex + 1) % _spinner.length;
      });
    }
    if (key.char == 'd') {
      // Disconnect Peer
      _refreshTimer?.cancel();
      console.cursorPosition = Coordinate(8, 2);
      console.showCursor();
      console.write("Enter Peer ID or Multiaddr to disconnect: ");
      final input = console.readLine();
      if (input != null && input.isNotEmpty) {
        try {
          await node?.disconnectFromPeer(input);
          _log("Disconnected from $input");
        } catch (e) {
          _log("Disconnection failed: $e");
        }
      }
      console.hideCursor();
      _refreshTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
        _draw();
        _spinnerIndex = (_spinnerIndex + 1) % _spinner.length;
      });
    }
  }

  void _handleFilesInput(Key key) async {
    if (key.char == 'p') {
      _refreshTimer?.cancel();
      console.cursorPosition = Coordinate(8, 2);
      console.showCursor();
      console.write("Enter CID to Pin: ");
      final input = console.readLine();
      if (input != null && input.isNotEmpty) {
        try {
          await node?.pin(input);
          _log("Pinned $input");
        } catch (e) {
          _log("Pin failed: $e");
        }
      }
      console.hideCursor();
      _refreshTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
        _draw();
        _spinnerIndex = (_spinnerIndex + 1) % _spinner.length;
      });
    }
    if (key.char == 'u') {
      _refreshTimer?.cancel();
      console.cursorPosition = Coordinate(8, 2);
      console.showCursor();
      console.write("Enter CID to Unpin: ");
      final input = console.readLine();
      if (input != null && input.isNotEmpty) {
        try {
          await node?.unpin(input);
          _log("Unpinned $input");
        } catch (e) {
          _log("Unpin failed: $e");
        }
      }
      console.hideCursor();
      _refreshTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
        _draw();
        _spinnerIndex = (_spinnerIndex + 1) % _spinner.length;
      });
    }
    if (key.char == 'l') {
      // List/Refresh happens in draw but we can force log
      final pins = await node?.pinnedCids;
      _log("Pins refreshed: ${pins?.length ?? 0} items");
    }
  }

  void _handleExplorerInput(Key key) async {
    if (key.char == 'g') {
      _refreshTimer?.cancel();
      console.cursorPosition = Coordinate(8, 2);
      console.showCursor();
      console.write("Enter CID to Explore: ");
      final input = console.readLine();
      if (input != null && input.isNotEmpty) {
        _explorerCid = input;
        _log("Exploring $input...");
        try {
          // Fetch data
          final data = await node?.cat(_explorerCid);
          _explorerData = data != null
              ? String.fromCharCodes(data.take(100)) + "..."
              : "No Data";
          // Fetch links
          _explorerLinks = await node?.ls(_explorerCid) ?? [];
        } catch (e) {
          _explorerData = "Error: $e";
          _explorerLinks = [];
        }
      }
      console.hideCursor();
      _refreshTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
        _draw();
        _spinnerIndex = (_spinnerIndex + 1) % _spinner.length;
      });
    }
    if (key.char == 'b') {
      // Back not implemented yet (needs stack)
      _log("History not implemented");
    }
  }

  String _explorerCid = "";
  String _explorerData = "";
  List<dynamic> _explorerLinks = []; // List<Link>

  void _drawFiles(int height) {
    console.cursorPosition = Coordinate(3, 2);
    console.setForegroundColor(ConsoleColor.cyan);
    console.write("FILES & PINNING");
    console.resetColorAttributes();

    if (node == null || !isRunning) {
      console.cursorPosition = Coordinate(5, 2);
      console.write("Node offline.");
      return;
    }

    console.cursorPosition = Coordinate(4, 2);
    console.write("[P] Pin CID   [U] Unpin CID   [L] Refresh List");

    console.cursorPosition = Coordinate(6, 2);
    console.write("Pinned Items:");

    // We need to async fetch pins. In draw loop we can't.
    // We rely on cache or just show "Press L to log count".
    // Or we can fetch in _updateStats loop like we did for peers.
    // Let's optimize later. For now just show "See logs for list" or rely on a cache.
    // I'll add _pinsCache and update it in _updateStats.

    if (_pinsCache.isEmpty) {
      console.cursorPosition = Coordinate(7, 2);
      console.write("(No pins or not fetched yet)");
    } else {
      int row = 7;
      for (var p in _pinsCache) {
        if (row >= height - 2) break;
        console.cursorPosition = Coordinate(row, 2);
        console.write("* $p");
        row++;
      }
    }
  }

  List<String> _pinsCache = [];

  void _drawExplorer(int height) {
    console.cursorPosition = Coordinate(3, 2);
    console.setForegroundColor(ConsoleColor.yellow);
    console.write("IPLD EXPLORER");
    console.resetColorAttributes();

    console.cursorPosition = Coordinate(4, 2);
    console.write("[G] Go to CID   [B] Back");

    if (_explorerCid.isEmpty) {
      console.cursorPosition = Coordinate(6, 2);
      console.write("No CID selected.");
      return;
    }

    console.cursorPosition = Coordinate(6, 2);
    console.write("Current CID: $_explorerCid");

    console.cursorPosition = Coordinate(7, 2);
    console.write("Data Preview: $_explorerData");

    console.cursorPosition = Coordinate(9, 2);
    console.write("Links:");
    int row = 10;
    for (var l in _explorerLinks) {
      if (row >= height - 2) break;
      // assuming l has name, cid, size
      // If l is Link object from dart_ipfs
      console.cursorPosition = Coordinate(row, 2);
      console.write("> ${l.toString()}");
      row++;
    }
  }

  Future<void> _toggleNode() async {
    if (isRunning) {
      statusMessage = "Stopping node...";
      _log("Stopping IPFS node...");
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
          dataPath: './cli_ipfs_data',
        );
        node = await IPFSNode.create(config);

        // Listen to bandwidth
        node!.bandwidthMetrics.listen((metrics) {
          // metrics has totalSent, totalReceived
          final now = DateTime.now().millisecondsSinceEpoch;
          final inBytes = metrics['totalReceived'] as int;
          final outBytes = metrics['totalSent'] as int;

          if (_lastTimestamp > 0) {
            final dt = (now - _lastTimestamp) / 1000.0;
            if (dt > 0) {
              _inRate = (inBytes - _lastInBytes) / 1024.0 / dt; // KB/s
              _outRate = (outBytes - _lastOutBytes) / 1024.0 / dt; // KB/s
            }
          }
          _lastInBytes = inBytes;
          _lastOutBytes = outBytes;
          _lastTimestamp = now;
        });

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

  void _log(String msg) {
    // Keep logs for global view or home view
    final time = DateTime.now().toIso8601String().split('T')[1].substring(0, 8);
    logs.insert(0, "[$time] $msg");
    if (logs.length > 50) logs.removeLast();
  }

  void _shutdown() {
    _refreshTimer?.cancel();
    _statsTimer?.cancel();
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

    // 1. Header (Global)
    console.cursorPosition = Coordinate(0, 0);
    console.setBackgroundColor(ConsoleColor.blue);
    console.setForegroundColor(ConsoleColor.white);

    String headerTitle =
        " dart_ipfs CLI [${_mode.name.toUpperCase()}] ".padRight(width - 40);
    String stats =
        " IN: ${_inRate.toStringAsFixed(1)} KB/s | OUT: ${_outRate.toStringAsFixed(1)} KB/s ";
    console.write(headerTitle + stats.padLeft(40));
    console.resetColorAttributes();

    // 2. Navigation Bar
    console.cursorPosition = Coordinate(1, 0);
    console.setBackgroundColor(ConsoleColor.white);
    console.setForegroundColor(ConsoleColor.black);
    console.write(" [H]ome | [P]eers | [C]hat | [F]iles | [E]xplorer | [Q]uit "
        .padRight(width));
    console.resetColorAttributes();

    // 3. Main Content Area
    // Clear area
    for (int i = 2; i < height; i++) {
      console.cursorPosition = Coordinate(i, 0);
      console.eraseLine();
    }

    // Draw specific mode content
    switch (_mode) {
      case DashboardMode.home:
        _drawHome(height);
        break;
      case DashboardMode.peers:
        _drawPeers(height);
        break;
      case DashboardMode.chat:
        _drawChat(height);
        break;
      case DashboardMode.files:
        _drawFiles(height);
        break;
      case DashboardMode.explorer:
        _drawExplorer(height);
        break;
    }
  }

  void _drawHome(int height) {
    // Status Pane
    console.cursorPosition = Coordinate(3, 2);
    console.setForegroundColor(ConsoleColor.green);
    console.write("STATUS: ");
    if (isRunning) {
      console.setForegroundColor(ConsoleColor.brightGreen);
      console.write("ONLINE ${_spinner[_spinnerIndex]}");
    } else {
      console.setForegroundColor(ConsoleColor.red);
      console.write("OFFLINE");
    }

    console.cursorPosition = Coordinate(4, 2);
    console.setForegroundColor(ConsoleColor.green);
    console.write("PEER ID: ");
    console.setForegroundColor(ConsoleColor.white);
    console.write(node?.peerID ?? "N/A");

    console.cursorPosition = Coordinate(5, 2);
    console.setForegroundColor(ConsoleColor.green);
    console.write("MSG: ");
    console.setForegroundColor(ConsoleColor.yellow);
    console.write(statusMessage);

    // Controls Help
    console.cursorPosition = Coordinate(7, 2);
    console.resetColorAttributes();
    console.write(
        "[S] Start/Stop   [A] Add File   [M] Mode: ${_gatewayMode.name.toUpperCase()}");

    // Logs
    console.cursorPosition = Coordinate(9, 0);
    console.write("-" * console.windowWidth);
    console.cursorPosition = Coordinate(10, 2);
    console.setForegroundColor(ConsoleColor.cyan);
    console.write("SYSTEM LOGS");

    int row = 11;
    for (var log in logs) {
      if (row >= height - 1) break;
      console.cursorPosition = Coordinate(row, 2);
      console.setForegroundColor(ConsoleColor.white);
      console.writeLine(log);
      row++;
    }
  }

  void _drawPeers(int height) {
    console.cursorPosition = Coordinate(3, 2);
    console.setForegroundColor(ConsoleColor.yellow);
    console.write("CONNECTED PEERS");
    console.resetColorAttributes();

    if (node == null || !isRunning) {
      console.cursorPosition = Coordinate(5, 2);
      console.write("Node is offline.");
      return;
    }

    // Controls
    console.cursorPosition = Coordinate(4, 2);
    console.write("[A] Connect Peer   [D] Disconnect Peer");

    // We can't await here in _draw, so we assume node.getPeers() is fast or we cache it.
    // _draw is called every 100ms. Calling async getPeers() might be tricky.
    // For now, let's display a cached list or "Fetching..."
    // Better: update peers list in the stats loop or a separate slow loop.

    // For this simple CLI, we'll just say "Peers require async fetch" or fetch in stats loop.
    // Let's add _peersCache to Dashboard state and update it in _updateStats.

    if (_peersCache.isEmpty) {
      console.cursorPosition = Coordinate(6, 2);
      console.write("No peers connected.");
    } else {
      int row = 6;
      for (var peer in _peersCache) {
        if (row >= height - 2) break;
        console.cursorPosition = Coordinate(row, 2);
        console.write("- $peer");
      }
    }
  }

  List<String> _peersCache = [];

  String _chatInput = "";
  List<String> _chatMessages = [];
  bool _subscribedToChat = false;
  String _activeTopic = "general";

  Future<void> _handleChatInput(Key key) async {
    // Enter to send
    if (key.controlChar == ControlCharacter.ctrlJ || key.char == '\n') {
      // Enter
      if (_chatInput.isNotEmpty) {
        final msg = _chatInput;
        _chatInput = ""; // Clear immediately
        try {
          // If not subscribed, subscribe first?
          if (!_subscribedToChat) {
            await node?.subscribe(_activeTopic);
            _subscribedToChat = true;
          }

          // Add to own UI locally for immediate feedback (optional, or wait for stream?)
          // Usually pubsub echoes back. If not, we add manual echo.
          // Let's assume we want to see it immediately.
          final time =
              DateTime.now().toIso8601String().split('T')[1].substring(0, 5);
          _chatMessages.add("[$time] [ME] $msg");
          if (_chatMessages.length > 50) _chatMessages.removeAt(0);

          await node?.publish(_activeTopic, msg);
        } catch (e) {
          _log("Failed to send: $e");
        }
      }
      return;
    }

    // Backspace
    if (key.controlChar == ControlCharacter.backspace) {
      if (_chatInput.isNotEmpty) {
        _chatInput = _chatInput.substring(0, _chatInput.length - 1);
      }
      return;
    }

    // Typing
    if (key.char.isNotEmpty && key.controlChar == ControlCharacter.none) {
      _chatInput += key.char;
    }
  }

  void _drawChat(int height) {
    // Header
    console.cursorPosition = Coordinate(3, 2);
    console.setForegroundColor(ConsoleColor.magenta);
    console.write("PUBSUB CHAT [Topic: $_activeTopic]");
    console.resetColorAttributes();

    if (node == null || !isRunning) {
      console.cursorPosition = Coordinate(5, 2);
      console.write("Node needs to be online locally to chat.");
      return;
    }

    // Auto-subscribe if entering mode logic, but we do it in draw/update cycle if valid
    // Ideally do it on mode switch but standard switch is simple assignment.
    // For now, lazy subscribe on first message or add a 'Join' button code?
    // Let's Just-In-Time subscribe if we are in this mode?
    if (!_subscribedToChat && isRunning) {
      node!.subscribe(_activeTopic);
      _subscribedToChat = true;

      // Listen once
      node!.pubsubMessages.listen((msg) {
        final time =
            DateTime.now().toIso8601String().split('T')[1].substring(0, 5);
        if (msg.topic == _activeTopic) {
          // Don't echo self if we did manual add, or handle dedup.
          // Simple: just show everything. User might see double if we manually added.
          // Let's NOT manually add in handleInput if we suspect echo.
          // Actually, usually pubsub doesn't echo to self by default in some implementations.
          // Let's stick to: "Received from ${msg.from}"
          final display =
              "[$time] [${msg.from.substring(0, 8)}..] ${msg.content}";
          _chatMessages.add(display);
          if (_chatMessages.length > 50) _chatMessages.removeAt(0);
          // Force refresh if we weren't polling? We are polling.
        }
      });
    }

    // Chat Area ( Scrollable-ish )
    // Area: Y=4 to Y=Height-4
    int chatAreaHeight = height - 8;
    int startY = 4;

    // Show last N messages that fit
    int msgsToShow = chatAreaHeight;
    int startMsgIndex = _chatMessages.length - msgsToShow;
    if (startMsgIndex < 0) startMsgIndex = 0;

    for (int i = 0;
        i < msgsToShow && (startMsgIndex + i) < _chatMessages.length;
        i++) {
      console.cursorPosition = Coordinate(startY + i, 2);
      console.write(_chatMessages[startMsgIndex + i]);
    }

    // Input Area
    console.cursorPosition = Coordinate(height - 2, 0);
    console.write("-" * console.windowWidth);
    console.cursorPosition = Coordinate(height - 1, 2);
    console.write("> $_chatInput"); // Cursor
  }
}
