//
//  Generated code. Do not modify.
//  source: core/link.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Link types for different DAG structures
class LinkType extends $pb.ProtobufEnum {
  static const LinkType LINK_TYPE_UNSPECIFIED = LinkType._(0, _omitEnumNames ? '' : 'LINK_TYPE_UNSPECIFIED');
  static const LinkType LINK_TYPE_DIRECT = LinkType._(1, _omitEnumNames ? '' : 'LINK_TYPE_DIRECT');
  static const LinkType LINK_TYPE_HAMT = LinkType._(2, _omitEnumNames ? '' : 'LINK_TYPE_HAMT');
  static const LinkType LINK_TYPE_TRICKLE = LinkType._(3, _omitEnumNames ? '' : 'LINK_TYPE_TRICKLE');

  static const $core.List<LinkType> values = <LinkType> [
    LINK_TYPE_UNSPECIFIED,
    LINK_TYPE_DIRECT,
    LINK_TYPE_HAMT,
    LINK_TYPE_TRICKLE,
  ];

  static final $core.Map<$core.int, LinkType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static LinkType? valueOf($core.int value) => _byValue[value];

  const LinkType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
