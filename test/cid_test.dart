import 'package:test/test.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart' as pb_cid;
import 'package:dart_ipfs/src/core/cid.dart';

void main() {
  test('CID creation from proto', () {
    final proto = pb_cid.IPFSCIDProto()
      ..version = pb_cid.IPFSCIDVersion.IPFS_CID_VERSION_1;

    final cid = CID.fromProto(proto);
    expect(cid.version, equals(pb_cid.IPFSCIDVersion.IPFS_CID_VERSION_1));
  });
}
