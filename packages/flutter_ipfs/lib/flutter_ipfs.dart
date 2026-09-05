/// Reactive Flutter UI bindings and widgets for [dart_ipfs].
///
/// Provides declarative widgets for embedding content-addressed IPFS assets
/// in Flutter applications:
/// - [IpfsScope] — Ambient provider for an [IPFSNode] instance.
/// - [IpfsImage] — Declarative image widget with progressive placeholders and LRU cache.
/// - [IpfsBuilder] — Reactive future builder for async IPFS calls.
/// - [IpfsStreamBuilder] — Reactive stream builder for IPFS events (PubSub, bandwidth).
/// - [IpfsText] — Declarative text widget.
/// - [IpfsCacheManager] — In-memory LRU cache manager for immutable IPFS content.
library flutter_ipfs;

export 'src/cache/ipfs_cache_manager.dart';
export 'src/widgets/ipfs_builder.dart';
export 'src/widgets/ipfs_image.dart';
export 'src/widgets/ipfs_scope.dart';
export 'src/widgets/ipfs_text.dart';
