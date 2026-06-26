// src/core/ipld/codecs/advanced_codecs.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/ipld/codecs/ipld_codec.dart';
import 'package:dart_ipfs/src/core/ipld/jose_cose_handler.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';

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
  String get identifier => name;

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
