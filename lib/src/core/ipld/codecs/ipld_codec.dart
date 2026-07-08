// src/core/ipld/codecs/ipld_codec.dart
import 'dart:typed_data';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

/// Interface for all IPLD codecs in dart_ipfs.
///
/// This is the unified interface from `COUNCIL_DECISION_IPLDCODEC_RECONCILIATION.md`:
/// every codec self-declares its multicodec [name] and [code], and operates
/// asynchronously on [IPLDNode] values.
abstract class IPLDCodec {
  /// Multicodec name and the registry key (e.g., 'dag-cbor').
  String get name;

  /// Multicodec integer code (e.g., `0x0129` for DAG-JSON).
  int get code;

  /// Backward-compatible alias that returns [name].
  @Deprecated('Use name instead')
  String get identifier => name;

  /// Encodes an [IPLDNode] into bytes.
  Future<Uint8List> encode(IPLDNode node);

  /// Decodes bytes into an [IPLDNode].
  Future<IPLDNode> decode(Uint8List data);
}
