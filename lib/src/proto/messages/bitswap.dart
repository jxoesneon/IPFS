import 'dart:typed_data';

import 'package:dart_ipfs/src/proto/base_message.dart';
import 'package:protobuf/protobuf.dart';

/// Bitswap protocol message for block exchange.
class BitswapMessage extends BaseProtoMessage {
  /// Creates an empty Bitswap message.
  BitswapMessage() : super();

  /// Creates a Bitswap message from bytes.
  factory BitswapMessage.fromBytes(Uint8List bytes) {
    return BaseProtoMessage.fromBytes(bytes, () => BitswapMessage());
  }

  @override
  BitswapMessage createEmptyInstance() => BitswapMessage();

  static final BuilderInfo _info = BuilderInfo(
    'BitswapMessage',
    package: const PackageName('ipfs.bitswap'),
    createEmptyInstance: () => BitswapMessage(),
  );

  @override
  BuilderInfo get info_ => _info;
}

