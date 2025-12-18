import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/node_service.dart';
import 'dart:convert';

class IPLDExplorerScreen extends StatefulWidget {
  const IPLDExplorerScreen({super.key});

  @override
  State<IPLDExplorerScreen> createState() => _IPLDExplorerScreenState();
}

class _IPLDExplorerScreenState extends State<IPLDExplorerScreen> {
  final TextEditingController _cidController = TextEditingController();
  final List<Map<String, String>> _breadcrumbs = [];
  String _currentCid = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _links = [];
  String? _dataPreview;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _explore(String cid, {String? label}) async {
    if (cid.isEmpty) return;

    // Handle path resolution CID/path/to/item
    if (cid.contains('/')) {
      await _explorePath(cid);
      return;
    }

    setState(() {
      _isLoading = true;
      _currentCid = cid;
      _error = null;
      _links = [];
      _dataPreview = null;
    });

    try {
      final node = context.read<NodeService>();

      // 1. Try ls (treat as directory/node with links)
      final links = await node.ls(cid);

      // 2. Try cat (get data)
      Uint8List? data;
      try {
        data = await node.cat(cid);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _links = links;
          if (data != null) {
            try {
              final rawStr = utf8.decode(data);
              try {
                // Try pretty-print if JSON
                final decoded = json.decode(rawStr);
                _dataPreview =
                    const JsonEncoder.withIndent('  ').convert(decoded);
              } catch (_) {
                _dataPreview = rawStr;
              }
            } catch (_) {
              _dataPreview = '<Binary Data: ${data.length} bytes>';
            }
          }

          if (links.isEmpty && data == null) {
            _error = 'Could not resolve CID or empty node.';
          } else {
            // Manage breadcrumbs
            if (label == null) {
              // Manual jump or root
              _breadcrumbs.clear();
              _breadcrumbs.add({'name': 'Root', 'cid': cid});
            } else {
              // Only add if not already the last one (prevents loops)
              if (_breadcrumbs.isEmpty || _breadcrumbs.last['cid'] != cid) {
                _breadcrumbs.add({'name': label, 'cid': cid});
              }
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error exploring CID: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _explorePath(String path) async {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return;

    String currentCid = parts[0];
    _breadcrumbs.clear();
    _breadcrumbs.add({'name': 'Root', 'cid': currentCid});

    final node = context.read<NodeService>();

    for (int i = 1; i < parts.length; i++) {
      final target = parts[i];
      // node already retrieved
      final links = await node.ls(currentCid);

      final link = links.firstWhere(
        (l) => l['name'] == target,
        orElse: () => {},
      );

      if (link.isEmpty || link['cid'] == null) {
        setState(() => _error =
            'Could not resolve path: $target not found in $currentCid');
        return;
      }

      currentCid = link['cid'];
      _breadcrumbs.add({'name': target, 'cid': currentCid});
    }

    _explore(currentCid, label: parts.last);
  }

  void _navigateToBreadcrumb(int index) {
    final target = _breadcrumbs[index];
    final cid = target['cid']!;
    _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
    _explore(cid, label: target['name']);
  }

  Widget _buildMetaTile(String label, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white24, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.firaCode(
                    color: color ?? Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Match Dashboard theme
      appBar: AppBar(
        title: Text('IPLD Explorer',
            style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.arrowLeftCircle,
                      color: Colors.cyanAccent),
                  onPressed: _breadcrumbs.length > 1
                      ? () => _navigateToBreadcrumb(_breadcrumbs.length - 2)
                      : null,
                ),
                Expanded(
                  child: TextField(
                    controller: _cidController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Enter CID',
                      labelStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      prefixIcon:
                          const Icon(LucideIcons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _explore,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _explore(_cidController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                  child: const Text('Go'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Breadcrumbs
            if (_breadcrumbs.isNotEmpty)
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _breadcrumbs.length,
                  separatorBuilder: (context, index) => Icon(
                      LucideIcons.chevronRight,
                      size: 14,
                      color: Colors.white24),
                  itemBuilder: (context, index) {
                    final b = _breadcrumbs[index];
                    final isLast = index == _breadcrumbs.length - 1;
                    return GestureDetector(
                      onTap: isLast ? null : () => _navigateToBreadcrumb(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          b['name']!,
                          style: TextStyle(
                            color: isLast ? Colors.cyanAccent : Colors.white54,
                            fontSize: 12,
                            fontWeight:
                                isLast ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Colors.cyanAccent))
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.redAccent)))
                      : _buildExplorerView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplorerView() {
    if (_currentCid.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.box,
                size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              'Enter a CID to explore the DAG',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.fileDigit, color: Colors.cyanAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    _currentCid,
                    style:
                        GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.copy,
                      size: 16, color: Colors.white54),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _currentCid));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('CID copied!')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Metadata Pane
          Row(
            children: [
              _buildMetaTile('Links', _links.length.toString()),
              const SizedBox(width: 12),
              _buildMetaTile(
                  'Size',
                  _dataPreview?.length != null
                      ? '${(_dataPreview!.length / 1024).toStringAsFixed(1)} KB'
                      : 'N/A'),
              const SizedBox(width: 12),
              FutureBuilder<List<String>>(
                  future: context.read<NodeService>().getPinnedCids(),
                  builder: (context, snapshot) {
                    final isPinned =
                        snapshot.data?.contains(_currentCid) ?? false;
                    return _buildMetaTile('Pinned', isPinned ? 'Yes' : 'No',
                        color: isPinned ? Colors.greenAccent : Colors.white24);
                  }),
            ],
          ),
          const SizedBox(height: 24),

          // Pinned Actions
          FutureBuilder<List<String>>(
              future: context.read<NodeService>().getPinnedCids(),
              builder: (context, snapshot) {
                final isPinned = snapshot.data?.contains(_currentCid) ?? false;
                return Row(
                  children: [
                    Icon(LucideIcons.pin,
                        size: 16,
                        color: isPinned ? Colors.greenAccent : Colors.white24),
                    const SizedBox(width: 8),
                    Text(
                      isPinned ? 'Pinned' : 'Not Pinned',
                      style: TextStyle(
                          color:
                              isPinned ? Colors.greenAccent : Colors.white24),
                    ),
                    if (!isPinned)
                      TextButton(
                          onPressed: () async {
                            await context.read<NodeService>().pin(_currentCid);
                            setState(() {}); // refresh
                          },
                          child: const Text('Pin Now'))
                    else
                      TextButton(
                          onPressed: () async {
                            await context
                                .read<NodeService>()
                                .unpin(_currentCid);
                            setState(() {}); // refresh
                          },
                          child: const Text('Unpin'))
                  ],
                );
              }),
          const SizedBox(height: 16),

          // Data Preview
          if (_dataPreview != null) ...[
            Text('DATA',
                style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                _dataPreview!,
                style:
                    GoogleFonts.firaCode(color: Colors.white70, fontSize: 12),
                maxLines: 10,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Links
          if (_links.isNotEmpty) ...[
            Text('LINKS (${_links.length})',
                style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _links.length,
              itemBuilder: (context, index) {
                final link = _links[index];
                return Card(
                  color: Colors.white.withValues(alpha: 0.05),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(LucideIcons.link,
                        color: Colors.cyanAccent, size: 16),
                    title: Text(link['name'] ?? 'Untitled',
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(link['cid'] ?? '',
                        style: GoogleFonts.firaCode(
                            color: Colors.white38, fontSize: 10)),
                    trailing: const Icon(LucideIcons.chevronRight,
                        color: Colors.white24),
                    onTap: () {
                      _cidController.text = link['cid'];
                      _explore(link['cid'], label: link['name']);
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
