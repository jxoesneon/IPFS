// src/core/ipld/codecs/standard_codecs.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cbor/enhanced_cbor_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/ipld_codec.dart';
import 'package:dart_ipfs/src/core/ipld/dag_json_handler.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';

/// Codec for 'raw' data.
class RawCodec implements IPLDCodec {
  @override
  String get identifier => 'raw';

  @override
  Future<Uint8List> encode(IPLDNode node) async {
    if (node.kind != Kind.BYTES) {
      throw ArgumentError('Raw codec requires bytes data');
    }
    return Uint8List.fromList(node.bytesValue);
  }

  @override
  Future<IPLDNode> decode(Uint8List data) async {
    return IPLDNode()
      ..kind = Kind.BYTES
      ..bytesValue = data;
  }
}

/// Codec for 'dag-pb' (Protobuf).
class DagPbCodec implements IPLDCodec {
  @override
  String get identifier => 'dag-pb';

  @override
  Future<Uint8List> encode(IPLDNode node) async {
    final dagNode = await _convertToMerkleDAGNode(node);
    return dagNode.toBytes();
  }

  @override
  Future<IPLDNode> decode(Uint8List data) async {
    final dagNode = MerkleDAGNode.fromBytes(data);
    return EnhancedCBORHandler.convertFromMerkleDAGNode(dagNode);
  }

  Future<MerkleDAGNode> _convertToMerkleDAGNode(IPLDNode node) async {
    if (node.kind != Kind.MAP) {
      throw ArgumentError('Cannot convert non-map to MerkleDAGNode');
    }

    final data = node.mapValue.entries
        .firstWhere((e) => e.key == 'Data', orElse: () => MapEntry())
        .value
        .bytesValue;

    final linkEntries = node.mapValue.entries
        .firstWhere((e) => e.key == 'Links', orElse: () => MapEntry())
        .value
        .listValue
        .values;

    final List<Link> links = linkEntries.map((linkNode) {
      if (linkNode.kind != Kind.MAP) {
        throw ArgumentError('Invalid link format');
      }
      return EnhancedCBORHandler.convertToMerkleLink(linkNode);
    }).toList();

    return MerkleDAGNode(
      links: links,
      data: Uint8List.fromList(data),
      mtime: DateTime.now().millisecondsSinceEpoch,
      isDirectory: false,
    );
  }
}

/// Codec for 'dag-cbor' (CBOR).
class DagCborCodec implements IPLDCodec {
  @override
  String get identifier => 'dag-cbor';

  @override
  Future<Uint8List> encode(IPLDNode node) async {
    return await EnhancedCBORHandler.encodeCbor(node);
  }

  @override
  Future<IPLDNode> decode(Uint8List data) async {
    return await EnhancedCBORHandler.decodeCborWithTags(data);
  }
}

/// Codec for 'dag-json' (JSON).
class DagJsonCodec implements IPLDCodec {
  @override
  String get identifier => 'dag-json';

  @override
  Future<Uint8List> encode(IPLDNode node) async {
    return Uint8List.fromList(utf8.encode(DAGJsonHandler.encode(node)));
  }

  @override
  Future<IPLDNode> decode(Uint8List data) async {
    return DAGJsonHandler.decode(utf8.decode(data));
  }
}
