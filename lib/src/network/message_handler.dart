import '../proto/generated/core/cid.pb.dart' as pb_cid;
import '../core/cid.dart';

class MessageHandler {
  Future<void> handleCIDMessage(pb_cid.IPFSCIDProto protoMessage) async {
    final cid = CID.fromProto(protoMessage);
    // ... handle the CID
  }

  pb_cid.IPFSCIDProto prepareCIDMessage(CID cid) {
    return cid.toProto();
  }
}
