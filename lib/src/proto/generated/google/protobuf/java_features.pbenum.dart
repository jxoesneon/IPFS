// This is a generated file - do not edit.
//
// Generated from google/protobuf/java_features.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// The UTF8 validation strategy to use.  See go/editions-utf8-validation for
/// more information on this feature.
class JavaFeatures_Utf8Validation extends $pb.ProtobufEnum {
  /// Invalid default, which should never be used.
  static const JavaFeatures_Utf8Validation UTF8_VALIDATION_UNKNOWN =
      JavaFeatures_Utf8Validation._(
          0, _omitEnumNames ? '' : 'UTF8_VALIDATION_UNKNOWN');

  /// Respect the UTF8 validation behavior specified by the global
  /// utf8_validation feature.
  static const JavaFeatures_Utf8Validation DEFAULT =
      JavaFeatures_Utf8Validation._(1, _omitEnumNames ? '' : 'DEFAULT');

  /// Verifies UTF8 validity overriding the global utf8_validation
  /// feature. This represents the legacy java_string_check_utf8 option.
  static const JavaFeatures_Utf8Validation VERIFY =
      JavaFeatures_Utf8Validation._(2, _omitEnumNames ? '' : 'VERIFY');

  static const $core.List<JavaFeatures_Utf8Validation> values =
      <JavaFeatures_Utf8Validation>[
    UTF8_VALIDATION_UNKNOWN,
    DEFAULT,
    VERIFY,
  ];

  static final $core.List<JavaFeatures_Utf8Validation?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static JavaFeatures_Utf8Validation? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const JavaFeatures_Utf8Validation._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
