import 'package:protobuf/protobuf.dart';
import 'proto/cid.pb.dart'; // Import the generated CIDProto

/// Represents a Content Identifier (CID) in IPFS.
class CID {
  final CIDProto _cidProto;

  CID(this._cidProto);

  /// Creates a CID from the given multihash and codec.
  factory CID.fromBytes(List<int> multihash, String codec, {CIDVersion version = CIDVersion.CID_VERSION_0}) {
    final cidProto = CIDProto()
      ..version = version
      ..multihash = Uint8List.fromList(multihash)
      ..codec = codec;
    
    return CID(cidProto);
  }

  /// Gets the version of the CID.
  CIDVersion get version => _cidProto.version;

  /// Gets the multihash of the CID.
  List<int> get multihash => _cidProto.multihash.toList();

  /// Gets the codec used for the CID.
  String get codec => _cidProto.codec;

  /// Converts the CID to a string representation.
  @override
  String toString() {
    return 'CID(version: $version, multihash: ${multihash.toString()}, codec: $codec)';
  }
}
extension CIDToProto on CID {
    CID toProto() {
        final cidProto = CID();
        CID.version = version;
        CID.multihash = multihash;
        CID.codec = codec;
        return CID;
    }
}


