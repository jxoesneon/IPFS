import '../proto/generated/core/cid.pb.dart' as pb_cid;
import '../core/cid.dart';

class ContentService {
  Future<CID> storageContent(List<int> content) async {
    final proto = pb_cid.IPFSCIDProto()
      ..version = pb_cid.IPFSCIDVersion.IPFS_CID_VERSION_1
      ..multihash = await computeHash(content)
      ..codec = 'raw'
      // ... other fields

    return CID.fromProto(proto);
  }
  
  // ... rest of implementation
} 