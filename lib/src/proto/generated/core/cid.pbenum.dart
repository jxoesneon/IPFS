// This is a generated file - do not edit.
//
// Generated from core/cid.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class IPFSCIDVersion extends $pb.ProtobufEnum {
  static const IPFSCIDVersion IPFS_CID_VERSION_UNSPECIFIED =
      IPFSCIDVersion._(0, _omitEnumNames ? '' : 'IPFS_CID_VERSION_UNSPECIFIED');
  static const IPFSCIDVersion IPFS_CID_VERSION_0 =
      IPFSCIDVersion._(1, _omitEnumNames ? '' : 'IPFS_CID_VERSION_0');
  static const IPFSCIDVersion IPFS_CID_VERSION_1 =
      IPFSCIDVersion._(2, _omitEnumNames ? '' : 'IPFS_CID_VERSION_1');

  static const $core.List<IPFSCIDVersion> values = <IPFSCIDVersion>[
    IPFS_CID_VERSION_UNSPECIFIED,
    IPFS_CID_VERSION_0,
    IPFS_CID_VERSION_1,
  ];

  static final $core.List<IPFSCIDVersion?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static IPFSCIDVersion? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const IPFSCIDVersion._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');

