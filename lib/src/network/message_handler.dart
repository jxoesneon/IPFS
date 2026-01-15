// src/network/message_handler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/proto/generated/base_messages.pb.dart' as pb_base;
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart' as pb_cid;
import 'package:dart_ipfs/src/proto/generated/google/protobuf/timestamp.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/services/gateway/content_type_handler.dart';
import 'package:dart_ipfs/src/services/gateway/lazy_preview_handler.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:fixnum/fixnum.dart';

/// Handles IPFS message processing and content operations.
///
/// Processes CID messages, stores content, notifies listeners,
/// and coordinates with Bitswap for block retrieval.
class MessageHandler {
  /// Creates a handler with config, router, and optional PubSub.
  MessageHandler(this.config, this._router, [this._pubSubClient]) {
    _blockStore = BlockStore(path: config.blockStorePath);
  }
  final StreamController<pb_base.NetworkEvent> _eventController =
      StreamController<pb_base.NetworkEvent>.broadcast();
  final PubSubClient? _pubSubClient;

  /// The IPFS configuration.
  final IPFSConfig config;

  final RouterInterface _router;
  late final BlockStore _blockStore;
  final _logger = Logger('MessageHandler');

  /// Handles an incoming CID message.
  Future<void> handleCIDMessage(pb_cid.IPFSCIDProto protoMessage) async {
    final cid = CID.fromProto(protoMessage);
    // Add handling logic here, for example:
    await processContent(cid);
    // or
    await storeCID(cid);
    // or
    notifyListeners(cid);
  }

  /// Processes content associated with a CID.
  Future<void> processContent(CID cid) async {
    try {
      // Get the block data associated with the CID
      final block = await getBlock(cid);
      if (block == null) {
        throw Exception('Block not found for CID: ${cid.encode()}');
      }

      // Create a content type handler instance
      final contentHandler = ContentTypeHandler();

      // Detect content type
      final contentType = contentHandler.detectContentType(block);

      // Process the content based on its type
      final processedData = contentHandler.processContent(block, contentType);

      // Handle the processed data (e.g., store it, send it, etc.)
      await handleProcessedData(cid, processedData, contentType);
    } catch (e) {
      // print('Error processing content for CID ${cid.encode()}: $e');
      rethrow;
    }
  }

  /// Stores a CID's block in the local blockstore.
  Future<void> storeCID(CID cid) async {
    try {
      _logger.verbose('Attempting to store CID: ${cid.encode()}');

      final block = await getBlock(cid);
      if (block == null) {
        _logger.warning('Block not found for CID: ${cid.encode()}');
        throw Exception('Block not found for CID: ${cid.encode()}');
      }

      _logger.debug(
        'Retrieved block for CID: ${cid.encode()}, size: ${block.data.length} bytes',
      );

      final blockStore = _blockStore;
      final response = await blockStore.putBlock(block);

      if (!response.success) {
        _logger.error('Failed to store block: ${response.message}');
        throw Exception('Failed to store block: ${response.message}');
      }

      _logger.debug('Successfully stored CID: ${cid.encode()}');
      notifyListeners(cid);
    } catch (e) {
      _logger.error('Error storing CID ${cid.encode()}', e);
      rethrow;
    }
  }

  /// Notifies listeners about a CID update.
  void notifyListeners(CID cid) {
    try {
      // Create a network event for content update
      final now = DateTime.now();
      final timestamp = Timestamp()
        ..seconds = Int64(now.millisecondsSinceEpoch ~/ 1000)
        ..nanos = (now.millisecondsSinceEpoch % 1000) * 1000000;

      final event = pb_base.NetworkEvent()
        ..timestamp = timestamp
        ..eventType = 'CONTENT_UPDATED'
        ..data = utf8.encode(cid.encode());

      // Broadcast the event to all subscribers
      _eventController.add(event);

      // If using PubSub, publish to a dedicated topic for content updates
      final message = {
        'type': 'content_update',
        'cid': cid.encode(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Convert the message to JSON and publish to the content updates topic
      final messageJson = jsonEncode(message);
      _pubSubClient?.publish('content_updates', messageJson);

      // print('Notified listeners about new content: ${cid.encode()}');
    } catch (e) {
      // print('Error notifying listeners about CID ${cid.encode()}: $e');
    }
  }

  /// Retrieves a block by CID from local store or network.
  Future<Block?> getBlock(CID cid) async {
    try {
      // First try to get from local blockstore
      final blockStore = _blockStore;
      final response = await blockStore.getBlock(cid.encode());

      if (response.found && response.hasBlock()) {
        return Block.fromProto(response.block);
      }

      // If not found locally, try to get from network via bitswap
      final bitswap = BitswapHandler(config, blockStore, _router);
      return await bitswap.wantBlock(cid.encode());
    } catch (e) {
      _logger.error('Error retrieving block for CID ${cid.encode()}', e);
      return null;
    }
  }

  /// Handles processed content data.
  Future<void> handleProcessedData(
    CID cid,
    Uint8List data,
    String contentType,
  ) async {
    try {
      // Create a new block with the processed data
      final block = await Block.fromData(data, format: 'raw');

      // Store the block in the datastore
      final blockStore = _blockStore;
      final storeResponse = await blockStore.putBlock(block);

      if (!storeResponse.success) {
        throw Exception(
          'Failed to store processed data: ${storeResponse.message}',
        );
      }

      // Cache the content type mapping for future reference
      final contentHandler = ContentTypeHandler();
      await contentHandler.cacheContentType(cid.encode(), contentType);

      // If this is a directory listing or markdown content,
      // generate and cache preview
      if (contentType == 'text/html' || contentType == 'text/markdown') {
        final previewHandler = LazyPreviewHandler();
        previewHandler.generateLazyPreview(block, contentType);
      }

      // Notify subscribers about the new processed content
      final now = DateTime.now();
      final timestamp = Timestamp()
        ..seconds = Int64(now.millisecondsSinceEpoch ~/ 1000)
        ..nanos = (now.millisecondsSinceEpoch % 1000) * 1000000;

      final event = pb_base.NetworkEvent()
        ..timestamp = timestamp
        ..eventType = 'CONTENT_PROCESSED'
        ..data = utf8.encode(
          jsonEncode({
            'cid': cid.encode(),
            'contentType': contentType,
            'size': data.length,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );

      _eventController.add(event);

      // If using PubSub, publish to content updates topic
      if (_pubSubClient != null) {
        await _pubSubClient.publish(
          'content_updates',
          jsonEncode({
            'type': 'content_processed',
            'cid': cid.encode(),
            'contentType': contentType,
            'size': data.length,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
      }

      // print('Successfully handled processed data for CID: ${cid.encode()}');
    } catch (e) {
      // print('Error handling processed data for CID ${cid.encode()}: $e');
      rethrow;
    }
  }

  /// Prepares a CID for network transmission.
  pb_cid.IPFSCIDProto prepareCIDMessage(CID cid) {
    return cid.toProto();
  }
}
