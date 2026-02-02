//
//  Generated code. Do not modify.
//  source: core/cid.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class IPFSCIDVersion extends $pb.ProtobufEnum {
  static const IPFSCIDVersion IPFS_CID_VERSION_UNSPECIFIED = IPFSCIDVersion._(0, _omitEnumNames ? '' : 'IPFS_CID_VERSION_UNSPECIFIED');
  static const IPFSCIDVersion IPFS_CID_VERSION_0 = IPFSCIDVersion._(1, _omitEnumNames ? '' : 'IPFS_CID_VERSION_0');
  static const IPFSCIDVersion IPFS_CID_VERSION_1 = IPFSCIDVersion._(2, _omitEnumNames ? '' : 'IPFS_CID_VERSION_1');

  static const $core.List<IPFSCIDVersion> values = <IPFSCIDVersion> [
    IPFS_CID_VERSION_UNSPECIFIED,
    IPFS_CID_VERSION_0,
    IPFS_CID_VERSION_1,
  ];

  static final $core.Map<$core.int, IPFSCIDVersion> _byValue = $pb.ProtobufEnum.initByValue(values);
  static IPFSCIDVersion? valueOf($core.int value) => _byValue[value];

  const IPFSCIDVersion._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
