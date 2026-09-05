import 'dart:convert';

import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:flutter/widgets.dart';

import '../cache/ipfs_cache_manager.dart';
import 'ipfs_scope.dart';

/// A declarative Flutter widget that resolves and displays text content from IPFS by CID.
class IpfsText extends StatefulWidget {
  /// Creates an [IpfsText] widget.
  const IpfsText({
    super.key,
    required this.cid,
    this.path = '',
    this.node,
    this.cacheManager,
    this.placeholder,
    this.errorWidget,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  /// The Content Identifier (CID) of the text content.
  final String cid;

  /// Optional subpath within a UnixFS directory.
  final String path;

  /// Explicit [IPFSNode] instance. If null, resolved from [IpfsScope.of(context)].
  final IPFSNode? node;

  /// Custom cache manager. If null, uses [IpfsCacheManager.defaultCache].
  final IpfsCacheManager? cacheManager;

  /// Widget displayed while fetching text.
  final WidgetBuilder? placeholder;

  /// Widget displayed if an error occurs.
  final Widget Function(BuildContext context, Object error)? errorWidget;

  /// Text style.
  final TextStyle? style;

  /// Text alignment.
  final TextAlign? textAlign;

  /// Maximum lines to display.
  final int? maxLines;

  /// Text overflow strategy.
  final TextOverflow? overflow;

  @override
  State<IpfsText> createState() => _IpfsTextState();
}

class _IpfsTextState extends State<IpfsText> {
  Future<String?>? _fetchFuture;
  String? _currentKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initFetch();
  }

  @override
  void didUpdateWidget(covariant IpfsText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cid != oldWidget.cid ||
        widget.path != oldWidget.path ||
        widget.node != oldWidget.node) {
      _initFetch();
    }
  }

  void _initFetch() {
    final cacheKey = widget.path.isEmpty ? widget.cid : '/';
    if (_currentKey == cacheKey && _fetchFuture != null) return;

    _currentKey = cacheKey;
    final cache = widget.cacheManager ?? IpfsCacheManager.defaultCache;
    final cached = cache.get(cacheKey);

    if (cached != null) {
      _fetchFuture = Future<String?>.value(utf8.decode(cached, allowMalformed: true));
    } else {
      final node = widget.node ?? IpfsScope.of(context);
      _fetchFuture = node.get(widget.cid, path: widget.path).then((bytes) {
        if (bytes != null) {
          cache.put(cacheKey, bytes);
          return utf8.decode(bytes, allowMalformed: true);
        }
        return null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _fetchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return widget.errorWidget?.call(context, snapshot.error!) ??
                const SizedBox.shrink();
          }

          final text = snapshot.data;
          if (text == null) {
            return widget.errorWidget?.call(
                  context,
                  StateError('No content found for CID: '),
                ) ??
                const SizedBox.shrink();
          }

          return Text(
            text,
            style: widget.style,
            textAlign: widget.textAlign,
            maxLines: widget.maxLines,
            overflow: widget.overflow,
          );
        }

        return widget.placeholder?.call(context) ?? const SizedBox.shrink();
      },
    );
  }
}
