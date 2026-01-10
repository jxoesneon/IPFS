//
//  Generated code. Do not modify.
//  source: validation.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

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

  static final $core.Map<$core.int, ValidationResult_ValidationCode> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static ValidationResult_ValidationCode? valueOf($core.int value) =>
      _byValue[value];

  const ValidationResult_ValidationCode._($core.int v, $core.String n)
      : super(v, n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
