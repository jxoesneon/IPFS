// This is a generated file - do not edit.
//
// Generated from google/protobuf/cpp_features.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class CppFeatures_StringType extends $pb.ProtobufEnum {
  static const CppFeatures_StringType STRING_TYPE_UNKNOWN =
      CppFeatures_StringType._(0, _omitEnumNames ? '' : 'STRING_TYPE_UNKNOWN');
  static const CppFeatures_StringType VIEW =
      CppFeatures_StringType._(1, _omitEnumNames ? '' : 'VIEW');
  static const CppFeatures_StringType CORD =
      CppFeatures_StringType._(2, _omitEnumNames ? '' : 'CORD');
  static const CppFeatures_StringType STRING =
      CppFeatures_StringType._(3, _omitEnumNames ? '' : 'STRING');

  static const $core.List<CppFeatures_StringType> values =
      <CppFeatures_StringType>[
    STRING_TYPE_UNKNOWN,
    VIEW,
    CORD,
    STRING,
  ];

  static final $core.List<CppFeatures_StringType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static CppFeatures_StringType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CppFeatures_StringType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
