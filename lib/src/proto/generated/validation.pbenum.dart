// This is a generated file - do not edit.
//
// Generated from validation.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ValidationResult_ValidationCode extends $pb.ProtobufEnum {
  static const ValidationResult_ValidationCode UNKNOWN =
      ValidationResult_ValidationCode._(0, _omitEnumNames ? '' : 'UNKNOWN');
  static const ValidationResult_ValidationCode SUCCESS =
      ValidationResult_ValidationCode._(1, _omitEnumNames ? '' : 'SUCCESS');
  static const ValidationResult_ValidationCode INVALID_SIZE =
      ValidationResult_ValidationCode._(
          2, _omitEnumNames ? '' : 'INVALID_SIZE');
  static const ValidationResult_ValidationCode INVALID_PROTOCOL =
      ValidationResult_ValidationCode._(
          3, _omitEnumNames ? '' : 'INVALID_PROTOCOL');
  static const ValidationResult_ValidationCode INVALID_FORMAT =
      ValidationResult_ValidationCode._(
          4, _omitEnumNames ? '' : 'INVALID_FORMAT');
  static const ValidationResult_ValidationCode RATE_LIMITED =
      ValidationResult_ValidationCode._(
          5, _omitEnumNames ? '' : 'RATE_LIMITED');

  static const $core.List<ValidationResult_ValidationCode> values =
      <ValidationResult_ValidationCode>[
    UNKNOWN,
    SUCCESS,
    INVALID_SIZE,
    INVALID_PROTOCOL,
    INVALID_FORMAT,
    RATE_LIMITED,
  ];

  static final $core.List<ValidationResult_ValidationCode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ValidationResult_ValidationCode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ValidationResult_ValidationCode._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');

