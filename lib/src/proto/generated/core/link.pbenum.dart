// This is a generated file - do not edit.
//
// Generated from core/link.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Link types for different DAG structures
class LinkType extends $pb.ProtobufEnum {
  static const LinkType LINK_TYPE_UNSPECIFIED =
      LinkType._(0, _omitEnumNames ? '' : 'LINK_TYPE_UNSPECIFIED');
  static const LinkType LINK_TYPE_DIRECT = LinkType._(1, _omitEnumNames ? '' : 'LINK_TYPE_DIRECT');
  static const LinkType LINK_TYPE_HAMT = LinkType._(2, _omitEnumNames ? '' : 'LINK_TYPE_HAMT');
  static const LinkType LINK_TYPE_TRICKLE =
      LinkType._(3, _omitEnumNames ? '' : 'LINK_TYPE_TRICKLE');

  static const $core.List<LinkType> values = <LinkType>[
    LINK_TYPE_UNSPECIFIED,
    LINK_TYPE_DIRECT,
    LINK_TYPE_HAMT,
    LINK_TYPE_TRICKLE,
  ];

  static final $core.List<LinkType?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 3);
  static LinkType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const LinkType._(super.value, super.name);
}

const $core.bool _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
