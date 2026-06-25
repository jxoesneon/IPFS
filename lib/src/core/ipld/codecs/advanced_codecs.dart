// src/core/ipld/codecs/advanced_codecs.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cbor/enhanced_cbor_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/ipld_codec.dart';
import 'package:dart_ipfs/src/core/ipld/jose_cose_handler.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';
import 'package:dart_multihash/dart_multihash.dart' as multihash_lib;

/// Codec for 'dag-jose'.
class DagJoseCodec implements IPLDCodec {
  /// Creates a [DagJoseCodec] with the given providers.
  DagJoseCodec(this.privateKeyProvider, this.recipientKeyProvider);

  /// Provider for the private key used for signing/encryption.
  final Future<IPFSPrivateKey> Function() privateKeyProvider;

  /// Provider for recipient public keys.
  final Future<List<int>> Function(IPLDNode) recipientKeyProvider;

  @override
  String get name => 'dag-jose';

  @override
  int get code => 0x85;

  @override
  Future<Uint8List> encode(IPLDNode node) async {
    if (node.kind != Kind.MAP) {
      throw ArgumentError('JOSE encoding requires a map structure');
    }

    final headerEntry = node.mapValue.entries.firstWhere(
      (e) => e.key == 'header',
      orElse: () => throw ArgumentError('Missing header in JOSE node'),
    );

    final algorithm = headerEntry.value.mapValue.entries
        .firstWhere(
          (e) => e.key == 'alg',
          orElse: () => throw ArgumentError('Missing algorithm in JOSE header'),
        )
        .value
        .stringValue;

    final privateKey = await privateKeyProvider();

    switch (algorithm) {
      case 'JWS':
        return await JoseCoseHandler.encodeJWS(node, privateKey);
      case 'JWE':
        final recipientKey = await recipientKeyProvider(node);
        return await JoseCoseHandler.encodeJWE(node, recipientKey);
      case 'COSE':
        return await JoseCoseHandler.encodeCOSE(node, privateKey);
      default:
        throw UnsupportedError('Unsupported JOSE algorithm: $algorithm');
    }
  }

  @override
  Future<IPLDNode> decode(Uint8List data) async {
    final joseData = json.decode(utf8.decode(data)) as Map<String, dynamic>;

    final header = json.decode(
      utf8.decode(base64Url.decode(joseData['protected'] as String)),
    ) as Map<String, dynamic>;
    final payload = base64Url.decode(joseData['payload'] as String);

    return IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = (IPLDMap()
        ..entries.addAll([
          MapEntry()
            ..key = 'header'
            ..value = (IPLDNode()
              ..kind = Kind.MAP
              ..mapValue = (IPLDMap()
                ..entries.addAll([
                  MapEntry()
                    ..key = 'alg'
                    ..value = (IPLDNode()
                      ..kind = Kind.STRING
                      ..stringValue = header['alg'] as String),
                ]))),
          MapEntry()
            ..key = 'payload'
            ..value = (IPLDNode()
              ..kind = Kind.BYTES
              ..bytesValue = payload),
        ]));
  }
}

/// Non-standard legacy codec for 'car'.
///
/// This class is deprecated and will be removed once the standard CAR v1/v2
/// implementation in `lib/src/core/data_structures/car.dart` is complete.
@Deprecated('Use the standard CarReader/CarWriter API instead')
class CarCodec implements IPLDCodec {
  /// Creates a [CarCodec] with the given [blockStore] and [decoder].
  CarCodec(this.blockStore, this.decoder);

  /// The blockstore to retrieve linked blocks from.
  final BlockStore blockStore;

  /// The decoder used for linked blocks.
  final Future<IPLDNode> Function(Uint8List, String) decoder;

  @override
  String get name => 'car';

  @override
  int get code => 0x0202;

  @override
  Future<Uint8List> encode(IPLDNode node) async {
    final output = BytesBuilder();

    // Write CAR header (version 1)
    output.addByte(1); // version
    output.addByte(1); // characteristics

    final rootCid = await CID.computeForData(
      await EnhancedCBORHandler.encodeCbor(node),
      format: 'dag-cbor',
    );

    output.addByte(1);
    output.add(rootCid.toBytes());

    await _writeCarBlock(node, output);
    return output.toBytes();
  }

  Future<void> _writeCarBlock(IPLDNode node, BytesBuilder output) async {
    final encoded = await EnhancedCBORHandler.encodeCbor(node);
    final cid = await CID.computeForData(encoded, format: 'dag-cbor');

    final cidBytes = cid.toBytes();
    output.add(_encodeVarint(cidBytes.length));
    output.add(cidBytes);

    output.add(_encodeVarint(encoded.length));
    output.add(encoded);

    if (node.kind == Kind.MAP) {
      for (final entry in node.mapValue.entries) {
        if (entry.value.kind == Kind.LINK) {
          final link = entry.value.linkValue;
          final cidStr = CID
              .v1(
                link.codec,
                multihash_lib.Multihash.decode(
                  Uint8List.fromList(link.multihash),
                ),
              )
              .toString();
          final linkedBlock = await blockStore.getBlock(cidStr);
          final linkedNode = await decoder(
            Uint8List.fromList(linkedBlock.block.data),
            link.codec,
          );
          await _writeCarBlock(linkedNode, output);
        }
      }
    }
  }

  List<int> _encodeVarint(int value) {
    final bytes = <int>[];
    while (value >= 0x80) {
      bytes.add((value & 0x7f) | 0x80);
      value >>= 7;
    }
    bytes.add(value & 0x7f);
    return bytes;
  }

  @override
  Future<IPLDNode> decode(Uint8List data) async {
    throw UnimplementedError('CAR decoding not implemented in this codec');
  }
}
