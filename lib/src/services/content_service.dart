import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../core/cid.dart';
import '../core/data_structures/block.dart';
import '../core/storage/datastore.dart';
import '../proto/generated/core/cid.pb.dart' as pb_cid;
import '../utils/logger.dart';

/// High-level service for content storage and retrieval.
///
/// ContentService provides a simplified API for IPFS content operations,
/// handling CID generation, block creation, and pin management.
///
/// Example:
/// ```dart
/// final service = ContentService(datastore);
///
/// // Store content
/// final cid = await service.storeContent(fileBytes);
///
/// // Retrieve content
/// final data = await service.getContent(cid);
///
/// // Pin for persistence
/// await service.pinContent(cid);
/// ```
///
/// See also:
/// - [Datastore] for low-level storage
/// - [CID] for content addressing
class ContentService {

  /// Creates a content service backed by [_datastore].
  ContentService(this._datastore);
  final Datastore _datastore;
  final _logger = Logger('ContentService');

  /// Stores content and returns its CID
  Future<CID> storeContent(List<int> content, {String codec = 'raw'}) async {
    final proto = pb_cid.IPFSCIDProto()
      ..version = pb_cid.IPFSCIDVersion.IPFS_CID_VERSION_1
      ..multihash = await computeHash(content)
      ..codec = codec
      ..multibasePrefix = 'base58btc';

    final cid = CID.fromProto(proto);

    // Create block and store raw data
    final block = await Block.fromData(
      Uint8List.fromList(content),
      format: codec,
    );
    final key = Key('/blocks/${cid.encode()}');
    await _datastore.put(key, block.data);

    return cid;
  }

  /// Retrieves content by CID
  Future<Uint8List?> getContent(CID cid) async {
    try {
      final key = Key('/blocks/${cid.encode()}');
      final data = await _datastore.get(key);
      return data;
    } catch (e, stackTrace) {
      _logger.error(
        'Error retrieving content for CID ${cid.encode()}',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Removes content by CID
  Future<bool> removeContent(CID cid) async {
    try {
      // Check if content is pinned
      final pinKey = Key('/pins/${cid.encode()}');
      if (await _datastore.has(pinKey)) {
        return false; // Cannot remove pinned content
      }

      final blockKey = Key('/blocks/${cid.encode()}');
      await _datastore.delete(blockKey);
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Error removing content for CID ${cid.encode()}',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Pins content to prevent garbage collection
  Future<bool> pinContent(CID cid) async {
    try {
      // Verify content exists
      final blockKey = Key('/blocks/${cid.encode()}');
      if (!await _datastore.has(blockKey)) {
        return false;
      }

      final pinKey = Key('/pins/${cid.encode()}');
      await _datastore.put(pinKey, Uint8List.fromList([1]));
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Error pinning content for CID ${cid.encode()}',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Unpins content, making it eligible for garbage collection
  Future<bool> unpinContent(CID cid) async {
    try {
      final pinKey = Key('/pins/${cid.encode()}');
      await _datastore.delete(pinKey);
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Error unpinning content for CID ${cid.encode()}',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Computes the multihash for content
  Future<List<int>> computeHash(List<int> content) async {
    final hash = sha256.convert(content);
    return [
      0x12, // SHA2-256 identifier
      hash.bytes.length,
      ...hash.bytes,
    ];
  }

  /// Checks if content exists
  Future<bool> hasContent(CID cid) async {
    final key = Key('/blocks/${cid.encode()}');
    return await _datastore.has(key);
  }

  /// Lists all pinned content CIDs
  Future<Set<String>> listPinnedContent() async {
    final pinnedCIDs = <String>{};
    final q = Query(prefix: '/pins/', keysOnly: true);

    await for (final entry in _datastore.query(q)) {
      final cidStr = entry.key.toString().substring('/pins/'.length);
      pinnedCIDs.add(cidStr);
    }

    return pinnedCIDs;
  }

  /// Gets the size of stored content
  Future<int?> getContentSize(CID cid) async {
    final data = await getContent(cid);
    return data?.length;
  }
}
