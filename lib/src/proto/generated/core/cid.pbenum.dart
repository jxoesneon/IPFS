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

/// Enum for CID versions
class CIDVersion extends $pb.ProtobufEnum {
  static const CIDVersion CID_VERSION_UNSPECIFIED = CIDVersion._(0, _omitEnumNames ? '' : 'CID_VERSION_UNSPECIFIED');
  static const CIDVersion CID_VERSION_0 = CIDVersion._(1, _omitEnumNames ? '' : 'CID_VERSION_0');
  static const CIDVersion CID_VERSION_1 = CIDVersion._(2, _omitEnumNames ? '' : 'CID_VERSION_1');

  static const $core.List<CIDVersion> values = <CIDVersion> [
    CID_VERSION_UNSPECIFIED,
    CID_VERSION_0,
    CID_VERSION_1,
  ];

  static final $core.Map<$core.int, CIDVersion> _byValue = $pb.ProtobufEnum.initByValue(values);
  static CIDVersion? valueOf($core.int value) => _byValue[value];

  const CIDVersion._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
