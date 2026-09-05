import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:flutter/widgets.dart';

import '../cache/ipfs_cache_manager.dart';
import 'ipfs_scope.dart';

/// A declarative Flutter widget that resolves and displays an image from IPFS
/// by CID.
///
/// Features:
/// - In-memory decoded LRU bitmap cache via [IpfsCacheManager] to eliminate redundant network/disk reads.
/// - Progressive loading with customizable [placeholder].
/// - Error handling with customizable [errorWidget].
/// - Pure declarative interface.
class IpfsImage extends StatefulWidget {
  /// Creates an [IpfsImage] widget.
  const IpfsImage({
    super.key,
    required this.cid,
    this.path = '',
    this.node,
    this.cacheManager,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  });

  /// The Content Identifier (CID) of the image.
  final String cid;

  /// Optional subpath within a UnixFS directory.
  final String path;

  /// Explicit [IPFSNode] instance. If null, resolved from [IpfsScope.of(context)].
  final IPFSNode? node;

  /// Custom cache manager. If null, uses [IpfsCacheManager.defaultCache].
  final IpfsCacheManager? cacheManager;

  /// Widget displayed while the image bytes are being fetched.
  final WidgetBuilder? placeholder;

  /// Widget displayed if an error occurs while fetching or decoding the image.
  final Widget Function(BuildContext context, Object error)? errorWidget;

  /// Image display width.
  final double? width;

  /// Image display height.
  final double? height;

  /// How to inscribe the image into the space allocated during layout.
  final BoxFit fit;

  /// How to align the image within its bounds.
  final AlignmentGeometry alignment;

  /// A semantic description of the image.
  final String? semanticLabel;

  /// Whether to exclude this image from semantics.
  final bool excludeFromSemantics;

  @override
  State<IpfsImage> createState() => _IpfsImageState();
}

class _IpfsImageState extends State<IpfsImage> {
  Future<Uint8List?>? _fetchFuture;
  String? _currentKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initFetch();
  }

  @override
  void didUpdateWidget(covariant IpfsImage oldWidget) {
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
      _fetchFuture = Future<Uint8List?>.value(cached);
    } else {
      final node = widget.node ?? IpfsScope.of(context);
      _fetchFuture = node.get(widget.cid, path: widget.path).then((bytes) {
        if (bytes != null) {
          cache.put(cacheKey, bytes);
        }
        return bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _fetchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return widget.errorWidget?.call(context, snapshot.error!) ??
                const SizedBox.shrink();
          }

          final data = snapshot.data;
          if (data == null || data.isEmpty) {
            return widget.errorWidget?.call(
                  context,
                  StateError('No content found for CID: '),
                ) ??
                const SizedBox.shrink();
          }

          return Image.memory(
            data,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
            semanticLabel: widget.semanticLabel,
            excludeFromSemantics: widget.excludeFromSemantics,
            errorBuilder: (context, error, stackTrace) {
              return widget.errorWidget?.call(context, error) ??
                  const SizedBox.shrink();
            },
          );
        }

        return widget.placeholder?.call(context) ??
            SizedBox(
              width: widget.width,
              height: widget.height,
            );
      },
    );
  }
}
