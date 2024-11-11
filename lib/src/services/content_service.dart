import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../proto/generated/core/cid.pb.dart' as pb_cid;
import '../core/cid.dart';
import '../core/data_structures/block.dart';
import '../storage/datastore.dart';

/// Service for handling IPFS content operations
class ContentService {
  final Datastore _datastore;

  ContentService(this._datastore);

  /// Stores content and returns its CID
  Future<CID> storeContent(List<int> content) async {
    final proto = pb_cid.IPFSCIDProto()
      ..version = pb_cid.IPFSCIDVersion.IPFS_CID_VERSION_1
      ..multihash = await computeHash(content)
      ..codec = 'raw'
      ..multibasePrefix = 'base58btc';

    final cid = CID.fromProto(proto);

    // Create and store block
    final block = await Block.fromData(Uint8List.fromList(content));
    await _datastore.put(cid.encode(), block);

    return cid;
  }

  /// Retrieves content by CID
  Future<Uint8List?> getContent(CID cid) async {
    try {
      final block = await _datastore.get(cid.encode());
      return block?.data;
    } catch (e) {
      print('Error retrieving content for CID ${cid.encode()}: $e');
      return null;
    }
  }

  /// Removes content by CID
  Future<bool> removeContent(CID cid) async {
    try {
      // Check if content is pinned
      if (await _datastore.isPinned(cid.encode())) {
        return false;
      }

      await _datastore.delete(cid.encode());
      return true;
    } catch (e) {
      print('Error removing content for CID ${cid.encode()}: $e');
      return false;
    }
  }

  /// Pins content to prevent garbage collection
  Future<bool> pinContent(CID cid) async {
    try {
      // Verify content exists
      if (!await _datastore.has(cid.encode())) {
        return false;
      }

      await _datastore.pin(cid.encode());
      return true;
    } catch (e) {
      print('Error pinning content for CID ${cid.encode()}: $e');
      return false;
    }
  }

  /// Unpins content, making it eligible for garbage collection
  Future<bool> unpinContent(CID cid) async {
    try {
      await _datastore.unpin(cid.encode());
      return true;
    } catch (e) {
      print('Error unpinning content for CID ${cid.encode()}: $e');
      return false;
    }
  }

  /// Computes the multihash for content
  Future<List<int>> computeHash(List<int> content) async {
    final hash = sha256.convert(content);
    return [
      0x12, // SHA2-256 identifier
      hash.bytes.length,
      ...hash.bytes
    ];
  }

  /// Checks if content exists
  Future<bool> hasContent(CID cid) async {
    return await _datastore.has(cid.encode());
  }

  /// Lists all pinned content CIDs
  Future<Set<String>> listPinnedContent() async {
    return await _datastore.loadPinnedCIDs();
  }

  /// Gets the size of stored content
  Future<int?> getContentSize(CID cid) async {
    final data = await getContent(cid);
    return data?.length;
  }
}
