import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:dart_ipfs/dart_ipfs.dart';
import '../services/node_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E1B4B),
                  Color(0xFF0F172A),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Panel: Status & Controls
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              _StatusCard(),
                              const SizedBox(height: 16),
                              Expanded(child: _TerminalView()),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Panel: File Manager
                        const Expanded(
                          flex: 6,
                          child: _MainContentPanel(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(LucideIcons.globe,
                color: Theme.of(context).colorScheme.primary, size: 32)
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 2000.ms, color: Colors.cyanAccent),
        const SizedBox(width: 16),
        Text(
          'dart_ipfs',
          style: GoogleFonts.firaCode(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        // Gateway Selector
        Consumer<NodeService>(
          builder: (context, node, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<GatewayMode>(
                value: node.gatewayMode,
                dropdownColor: const Color(0xFF0F172A),
                icon: const Icon(LucideIcons.chevronDown,
                    color: Colors.white70, size: 16),
                style: GoogleFonts.firaCode(color: Colors.white, fontSize: 12),
                items: GatewayMode.values.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(mode.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (GatewayMode? newMode) {
                  if (newMode != null) {
                    if (newMode == GatewayMode.custom) {
                      _showCustomGatewayDialog(context, node);
                    } else {
                      node.setGatewayMode(newMode);
                    }
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Consumer<NodeService>(
                builder: (context, node, _) => CircleAvatar(
                  radius: 4,
                  backgroundColor:
                      node.isOnline ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
              const SizedBox(width: 8),
              Consumer<NodeService>(
                builder: (context, node, _) => Text(
                  node.isOnline ? 'ONLINE' : 'OFFLINE',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showCustomGatewayDialog(
      BuildContext context, NodeService node) async {
    final controller =
        TextEditingController(text: 'http://my-gateway:8080/ipfs');
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Custom Gateway URL',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Gateway Base URL',
            hintText: 'http://127.0.0.1:8080/ipfs',
            labelStyle: TextStyle(color: Colors.white54),
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            child: const Text('Set', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty) {
      node.setGatewayMode(GatewayMode.custom, customUrl: url);
    }
  }
}

class _StatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final node = context.watch<NodeService>();
    final isOnline = node.isOnline;

    return GlassmorphicContainer(
      width: double.infinity,
      height: 200,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFffffff).withValues(alpha: 0.1),
          const Color(0xFFFFFFFF).withValues(alpha: 0.05),
        ],
        stops: const [0.1, 1],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFffffff).withValues(alpha: 0.5),
          const Color((0xFFFFFFFF)).withValues(alpha: 0.5),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('NODE STATUS',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12)),
                Switch(
                  value: isOnline,
                  onChanged: (val) => val ? node.startNode() : node.stopNode(),
                  activeTrackColor: Colors.cyanAccent,
                  inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                ),
              ],
            ),
            const Spacer(),
            if (isOnline) ...[
              Text('PEER ID',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12)),
              const SizedBox(height: 4),
              SelectableText(
                node.peerId,
                style: GoogleFonts.firaCode(color: Colors.white, fontSize: 14),
              ),
            ] else
              Center(
                child: Text(
                  'Node is offline',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _TerminalView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final logs = context.select<NodeService, List<String>>((s) => s.logs);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.terminal,
                  size: 16, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text('TERMINAL',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    logs[index],
                    style: GoogleFonts.firaCode(
                        fontSize: 12,
                        color: Colors.greenAccent.withValues(alpha: 0.8)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FileManager extends StatefulWidget {
  const _FileManager();

  @override
  State<_FileManager> createState() => _FileManagerState();
}

class _FileManagerState extends State<_FileManager> {
  final List<String> _cids = [];
  bool _isUploading = false;

  Future<void> _pickFile() async {
    final node = context.read<NodeService>();
    if (!node.isOnline) return;

    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() => _isUploading = true);
      // On macOS/Desktop the 'path' is available.
      final path = result.files.single.path;
      if (path != null) {
        final cid = await node.addFile(path);
        if (cid != null) {
          setState(() => _cids.insert(0, cid));
        }
      }
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: double.infinity,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFffffff).withValues(alpha: 0.1),
          const Color(0xFFFFFFFF).withValues(alpha: 0.05),
        ],
        stops: const [0.1, 1],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFffffff).withValues(alpha: 0.5),
          const Color((0xFFFFFFFF)).withValues(alpha: 0.5),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('FILE MANAGER',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12)),
                ElevatedButton.icon(
                  onPressed:
                      context.watch<NodeService>().isOnline ? _pickFile : null,
                  icon: const Icon(LucideIcons.uploadCloud, size: 16),
                  label: const Text('Add File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.cyanAccent,
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isUploading)
              const LinearProgressIndicator(color: Colors.cyanAccent),
            Expanded(
              child: _cids.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.hardDrive,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.1)),
                          const SizedBox(height: 16),
                          Text(
                            'No files added yet',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _cids.length,
                      itemBuilder: (context, index) {
                        return _FileItem(cid: _cids[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileItem extends StatelessWidget {
  final String cid;
  const _FileItem({required this.cid});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.file, color: Colors.indigoAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text(
                  cid,
                  style: GoogleFonts.firaCode(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.download,
                size: 16, color: Colors.cyanAccent),
            tooltip: 'Download',
            onPressed: () => _downloadFile(context),
          ),
          IconButton(
            icon: const Icon(LucideIcons.share2,
                size: 16, color: Colors.purpleAccent),
            tooltip: 'Copy Public Link',
            onPressed: () {
              final url = 'https://ipfs.io/ipfs/$cid';
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Public link copied to clipboard')),
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.copy, size: 16, color: Colors.white54),
            tooltip: 'Copy CID',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: cid));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CID copied to clipboard')),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn().slideX();
  }

  Future<void> _downloadFile(BuildContext context) async {
    try {
      final node = context.read<NodeService>();
      if (!node.isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Node is offline')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retrieving file...')),
      );

      final bytes = await node.cat(cid);
      if (bytes == null || bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to retrieve content')),
          );
        }
        return;
      }

      String? savePath;

      // On Web, handle download differently (not implemented for demo).
      // On Desktop/Mobile, use FilePicker or save to Downloads.

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save File',
        fileName: '$cid.bin',
        bytes: bytes, // Web only
      );

      if (result != null) {
        savePath = result;
      } else {
        // User canceled
        return;
      }

      // FilePicker.saveFile returns path on Desktop but doesn't write bytes automatically?
      // "If [bytes] is provided, the file will be saved with the provided bytes (Web only)."
      // On desktop we must write it ourselves.

      final file = File(savePath);
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $savePath')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
// ... _FileItem code ...

class _MainContentPanel extends StatefulWidget {
  const _MainContentPanel();

  @override
  State<_MainContentPanel> createState() => _MainContentPanelState();
}

class _MainContentPanelState extends State<_MainContentPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom Tab Bar
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
            ),
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.hardDrive, size: 16),
                    SizedBox(width: 8),
                    Text('FILES'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.network, size: 16),
                    SizedBox(width: 8),
                    Text('NETWORK'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.messageCircle, size: 16),
                    SizedBox(width: 8),
                    Text('CHAT'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.wrench, size: 16),
                    SizedBox(width: 8),
                    Text('TOOLS'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              const _FileManager(),
              const _NetworkView(),
              const _ChatView(),
              const _ToolsView(),
            ],
          ),
        ),
      ],
    );
  }
}

class _NetworkView extends StatefulWidget {
  const _NetworkView();

  @override
  State<_NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends State<_NetworkView> {
  List<String> _peers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshPeers();
  }

  Future<void> _refreshPeers() async {
    final node = context.read<NodeService>();
    if (!node.isOnline) return;

    setState(() => _isLoading = true);
    final peers = await node.getPeers();
    if (mounted) {
      setState(() {
        _peers = peers;
        _isLoading = false;
      });
    }
  }

  Future<void> _connectPeer() async {
    final controller = TextEditingController();
    final shouldConnect = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Connect to Peer',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Multiaddress',
            labelStyle: TextStyle(color: Colors.white54),
            hintText: '/ip4/1.2.3.4/tcp/4001/p2p/Qm...',
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            child: const Text('Connect', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (shouldConnect == true && controller.text.isNotEmpty && mounted) {
      await context.read<NodeService>().connectPeer(controller.text);
      _refreshPeers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: double.infinity,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFffffff).withValues(alpha: 0.1),
          const Color(0xFFFFFFFF).withValues(alpha: 0.05),
        ],
        stops: const [0.1, 1],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFffffff).withValues(alpha: 0.5),
          const Color((0xFFFFFFFF)).withValues(alpha: 0.5),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('CONNECTED PEERS',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_peers.length}',
                        style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.refreshCw,
                          size: 16, color: Colors.white54),
                      onPressed: _isLoading ? null : _refreshPeers,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: context.watch<NodeService>().isOnline
                          ? _connectPeer
                          : null,
                      icon: const Icon(LucideIcons.link, size: 16),
                      label: const Text('Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.cyanAccent.withValues(alpha: 0.2),
                        foregroundColor: Colors.cyanAccent,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading && _peers.isEmpty)
              const LinearProgressIndicator(color: Colors.cyanAccent),
            Expanded(
              child: _peers.isEmpty
                  ? Center(
                      child: Text(
                        context.watch<NodeService>().isOnline
                            ? 'No peers connected'
                            : 'Node is offline',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _peers.length,
                      itemBuilder: (context, index) {
                        final peer = _peers[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  peer,
                                  style: GoogleFonts.firaCode(
                                      color: Colors.white70, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.x,
                                    size: 14, color: Colors.redAccent),
                                onPressed: () async {},
                              ),
                            ],
                          ),
                        ).animate().fadeIn().slideX();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final String _topic = 'dart_ipfs_general';

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final node = context.read<NodeService>();
    if (node.isOnline) {
      node.subscribe(_topic);
      node.pubsubEvents.listen((event) {
        if (!mounted) return;
        // Event can be PubSubMessage (native) or Map (web mock)
        String from = 'Unknown';
        String content = '';

        // Reflection/Dynamic Check
        try {
          // Native
          from = event.from;
          content = event.content;
        } catch (_) {
          // Map (Web Mock)
          if (event is Map) {
            from = event['from'] ?? 'Unknown';
            content = event['content'] ?? '';
          }
        }

        setState(() {
          _messages.add({
            'from': from,
            'content': content,
            'time':
                DateTime.now().toIso8601String().split('T')[1].substring(0, 5)
          });
        });
      });
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    context.read<NodeService>().publish(_topic, text);
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: double.infinity,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFffffff).withValues(alpha: 0.1),
          const Color(0xFFFFFFFF).withValues(alpha: 0.05),
        ],
        stops: const [0.1, 1],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFffffff).withValues(alpha: 0.5),
          const Color((0xFFFFFFFF)).withValues(alpha: 0.5),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(LucideIcons.hash,
                    color: Colors.cyanAccent, size: 16),
                const SizedBox(width: 8),
                Text(_topic,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(color: Colors.white24, height: 32),

            // Messages
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe =
                      msg['from'] == context.read<NodeService>().peerId;
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.cyanAccent.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(msg['from']!,
                              style: TextStyle(
                                  color: Colors.cyanAccent, fontSize: 10)),
                          const SizedBox(height: 4),
                          Text(msg['content']!,
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Input
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(LucideIcons.send, color: Colors.cyanAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BandwidthChart extends StatefulWidget {
  const _BandwidthChart();

  @override
  State<_BandwidthChart> createState() => _BandwidthChartState();
}

class _BandwidthChartState extends State<_BandwidthChart> {
  final List<double> _dataPoints = List.filled(30, 0.0); // 30 seconds history
  StreamSubscription? _sub;
  int _lastTotalSent = 0;
  int _lastTotalReceived = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  void _subscribe() {
    final node = context.read<NodeService>();
    // Bandwidth metrics might be null or empty stream depending on implementation
    _sub = node.bandwidthMetrics.listen((data) {
      if (!mounted) return;
      int sent = (data['totalSent'] as num?)?.toInt() ?? 0;
      int recv = (data['totalReceived'] as num?)?.toInt() ?? 0;

      int delta = (sent - _lastTotalSent) + (recv - _lastTotalReceived);

      if (_lastTotalSent == 0 && _lastTotalReceived == 0) {
        delta = 0;
      }
      if (delta < 0) delta = 0;

      _lastTotalSent = sent;
      _lastTotalReceived = recv;

      setState(() {
        _dataPoints.removeAt(0);
        _dataPoints.add(delta.toDouble());
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(_dataPoints),
      size: Size.infinite,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  _SparklinePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.cyanAccent.withValues(alpha: 0.2),
          Colors.cyanAccent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    double maxVal = data.fold(0.0, (p, c) => p > c ? p : c);
    if (maxVal == 0) maxVal = 1.0;

    double stepX = size.width / (data.length - 1);

    path.moveTo(0, size.height - (data[0] / maxVal * size.height));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, size.height - (data[0] / maxVal * size.height));

    for (int i = 1; i < data.length; i++) {
      double x = i * stepX;
      double y = size.height - (data[i] / maxVal * size.height);

      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return true;
  }
}

class _ToolsView extends StatefulWidget {
  const _ToolsView();

  @override
  State<_ToolsView> createState() => _ToolsViewState();
}

class _ToolsViewState extends State<_ToolsView> {
  final _inputController = TextEditingController();
  final List<String> _logs = [];
  bool _isBusy = false;
  List<String> _addresses = [];
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final node = context.read<NodeService>();
    final addrs = await node.getAddresses();
    if (mounted) {
      setState(() {
        _addresses = addrs;
      });
    }
  }

  void _log(String message) {
    if (mounted) {
      setState(() {
        _logs.add(
            '${DateTime.now().toIso8601String().split('T')[1].substring(0, 8)} $message');
      });
    }
  }

  Future<void> _checkRetrieval() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;

    setState(() => _isBusy = true);
    _log('----- Checking Content Retrieval -----');
    _log('Input: $input');

    final node = context.read<NodeService>();
    if (!node.isOnline) {
      _log('Error: Node is offline');
      setState(() => _isBusy = false);
      return;
    }

    try {
      _log('Step 1: Parsing CID...');
      // Simple validation (real parsing would happen in node)
      if (!input.startsWith('Qm') && !input.startsWith('bafy')) {
        _log('Warning: Input might not be a valid CID');
      }

      _log('Step 2: Searching DHT / Fetching...');
      final stopwatch = Stopwatch()..start();

      // We use 'cat' to test retrieval.
      try {
        final bytes = await node.cat(input);
        stopwatch.stop();

        if (bytes != null && bytes.isNotEmpty) {
          _log('SUCCESS: Content found!');
          _log('Size: ${bytes.length} bytes');
          _log('Time: ${stopwatch.elapsedMilliseconds}ms');
        } else {
          _log('FAILURE: Content not found or empty');
          _log('Time: ${stopwatch.elapsedMilliseconds}ms');
        }
      } catch (e) {
        stopwatch.stop();
        _log('FAILURE: Error fetching content');
        _log('Error: $e');
      }
    } catch (e) {
      _log('ERROR: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _checkConnection() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;

    setState(() => _isBusy = true);
    _log('----- Checking Peer Connection -----');
    _log('Input: $input');

    final node = context.read<NodeService>();
    if (!node.isOnline) {
      _log('Error: Node is offline');
      setState(() => _isBusy = false);
      return;
    }

    try {
      _log('Step 1: Parsing Multiaddr...');
      if (!input.contains('/p2p/')) {
        _log('Warning: Input might not be a valid Multiaddr');
      }

      _log('Step 2: Dialing peer...');
      final stopwatch = Stopwatch()..start();

      await node.connectPeer(input);

      stopwatch.stop();
      _log('SUCCESS: Connected to peer');
      _log('Time: ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      _log('FAILURE: Could not connect');
      _log('Error: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = context.watch<NodeService>();

    return GlassmorphicContainer(
      width: double.infinity,
      height: double.infinity,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFffffff).withValues(alpha: 0.1),
          const Color(0xFFFFFFFF).withValues(alpha: 0.05),
        ],
        stops: const [0.1, 1],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFffffff).withValues(alpha: 0.5),
          const Color((0xFFFFFFFF)).withValues(alpha: 0.5),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Icon(LucideIcons.wrench, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 8),
                Text('NETWORK DIAGNOSTICS',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showDetails = !_showDetails;
                      if (_showDetails) _loadAddresses();
                    });
                  },
                  icon: Icon(
                      _showDetails
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                      color: Colors.cyanAccent),
                  label: Text(
                      _showDetails ? 'Hide My Details' : 'Show My Details',
                      style: const TextStyle(color: Colors.cyanAccent)),
                ),
              ],
            ),

            if (_showDetails) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.cyanAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MY NODE IDENTITY',
                        style: GoogleFonts.firaCode(
                            color: Colors.cyanAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Peer ID: ',
                            style: GoogleFonts.firaCode(
                                color: Colors.white70, fontSize: 11)),
                        Expanded(
                            child: SelectableText(node.peerId,
                                style: GoogleFonts.firaCode(
                                    color: Colors.white, fontSize: 11))),
                        IconButton(
                          icon: const Icon(LucideIcons.copy,
                              size: 14, color: Colors.white54),
                          onPressed: () => Clipboard.setData(
                              ClipboardData(text: node.peerId)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 8),
                    Text('LISTENING ADDRESSES:',
                        style: GoogleFonts.firaCode(
                            color: Colors.white70, fontSize: 10)),
                    const SizedBox(height: 4),
                    if (_addresses.isEmpty)
                      Text('Fetching...',
                          style: GoogleFonts.firaCode(
                              color: Colors.white38, fontSize: 10))
                    else
                      ..._addresses.map((addr) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Expanded(
                                    child: SelectableText(addr,
                                        style: GoogleFonts.firaCode(
                                            color: Colors.greenAccent,
                                            fontSize: 10))),
                                IconButton(
                                  icon: const Icon(LucideIcons.copy,
                                      size: 12, color: Colors.white24),
                                  onPressed: () => Clipboard.setData(
                                      ClipboardData(text: addr)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Input Area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _inputController,
                    style:
                        GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'CID or Multiaddr',
                      labelStyle: TextStyle(color: Colors.white54),
                      hintText: 'bafy... or /ip4/...',
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isBusy ? null : _checkRetrieval,
                          icon: const Icon(LucideIcons.search, size: 16),
                          label: const Text('Check Content'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.blueAccent.withValues(alpha: 0.2),
                            foregroundColor: Colors.blueAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isBusy ? null : _checkConnection,
                          icon: const Icon(LucideIcons.network, size: 16),
                          label: const Text('Check Peer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.purpleAccent.withValues(alpha: 0.2),
                            foregroundColor: Colors.purpleAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Console Output
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DIAGNOSTIC LOG',
                        style: GoogleFonts.firaCode(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _logs[index],
                              style: GoogleFonts.firaCode(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
