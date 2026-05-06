// src/core/ipld/codecs/ipld_codec.dart
import 'dart:typed_data';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

/// Interface for IPLD codecs.
abstract class IPLDCodec {
  /// The identifier for this codec (e.g., 'dag-cbor').
  String get identifier;

  /// Encodes an [IPLDNode] into bytes.
  Future<Uint8List> encode(IPLDNode node);

  /// Decodes bytes into an [IPLDNode].
  Future<IPLDNode> decode(Uint8List data);
}
