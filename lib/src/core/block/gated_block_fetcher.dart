// lib/src/core/block/gated_block_fetcher.dart
import 'dart:typed_data';

import '../cid.dart';
import '../data_structures/block.dart';

/// Fetches a block by CID string from the caller's local store(s),
/// returning `null` when it is not present.
typedef LocalBlockGet = Future<Block?> Function(String cid);

/// Writes a network-fetched [block] into the caller's local store.
typedef LocalBlockPut = Future<void> Function(Block block);

/// Fetches a block by CID string from the network (e.g. Bitswap
/// `wantBlock`), returning `null` when retrieval fails.
typedef NetworkBlockFetch = Future<Block?> Function(String cid);

/// Enforces the caller's denylist policy for [cid]. Implementations throw
/// the surface-specific "blocked" exception when the configured action is
/// `block`, and record the audit hit either way.
typedef DenylistGate = void Function(String cid);

/// Shared denylist-gated block fetch pipeline.
///
/// Converges the "denylist gate → identity synthesis → local store →
/// Bitswap → write-back" fetch order that the gateway, the RPC handlers,
/// and the node content manager each implemented separately. The order is
/// fixed:
///
/// 1. [DenylistGate] runs first — a denylisted CID is rejected even when it
///    is an identity CID whose data is inline in the multihash.
/// 2. Identity CIDs (multihash code `0x00`) are synthesized: the digest is
///    the block data, so no store or network access is needed.
/// 3. [LocalBlockGet] answers from the caller's local store(s).
/// 4. [NetworkBlockFetch] fetches from the network unless [localOnly] is
///    requested.
/// 5. A network-fetched block is written back through [LocalBlockPut]; when
///    [rereadAfterFetch] is set the local store is re-read first and the
///    stored copy wins — for surfaces whose network layer already persists
///    received blocks.
class GatedBlockFetcher {
  /// Creates a fetcher over the given backends. All callbacks except
  /// [localGet] are optional.
  const GatedBlockFetcher({
    required LocalBlockGet localGet,
    LocalBlockPut? localPut,
    NetworkBlockFetch? wantBlock,
    DenylistGate? denylistGate,
    this.rereadAfterFetch = false,
  }) : _localGet = localGet,
       _localPut = localPut,
       _wantBlock = wantBlock,
       _denylistGate = denylistGate;

  final LocalBlockGet _localGet;
  final LocalBlockPut? _localPut;
  final NetworkBlockFetch? _wantBlock;
  final DenylistGate? _denylistGate;

  /// When true, a successful network fetch triggers a [LocalBlockGet]
  /// re-read and the stored copy is preferred — used by surfaces whose
  /// Bitswap layer already writes received blocks to the store.
  final bool rereadAfterFetch;

  /// Fetches the block addressed by [cidStr].
  ///
  /// Returns `null` when the block is unavailable locally and either
  /// [localOnly] is set, no network fetcher is configured, or the network
  /// fetch misses. Denylist rejections propagate from [DenylistGate] as the
  /// caller's own exception type.
  Future<Block?> fetch(String cidStr, {bool localOnly = false}) async {
    _denylistGate?.call(cidStr);

    // Identity CIDs carry the block data inside the digest; they are
    // synthesized without touching the store or network.
    final cid = tryDecodeCidLenient(cidStr);
    if (cid != null && cid.multihash.code == 0x00) {
      return Block(
        cid: cid,
        data: Uint8List.fromList(cid.multihash.digest),
        format: cid.codec ?? 'raw',
      );
    }

    final local = await _localGet(cidStr);
    if (local != null) {
      return local;
    }
    if (localOnly) {
      return null;
    }

    final wantBlock = _wantBlock;
    if (wantBlock == null) {
      return null;
    }
    final networkBlock = await wantBlock(cidStr);
    if (networkBlock == null) {
      return null;
    }
    if (rereadAfterFetch) {
      final stored = await _localGet(cidStr);
      if (stored != null) {
        return stored;
      }
    }
    await _localPut?.call(networkBlock);
    return networkBlock;
  }
}
