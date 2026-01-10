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

import 'validation.pbenum.dart';

export 'validation.pbenum.dart';

class ValidationResult extends $pb.GeneratedMessage {
  factory ValidationResult({
    $core.bool? isValid,
    $core.String? errorMessage,
    ValidationResult_ValidationCode? code,
  }) {
    final $result = create();
    if (isValid != null) {
      $result.isValid = isValid;
    }
    if (errorMessage != null) {
      $result.errorMessage = errorMessage;
    }
    if (code != null) {
      $result.code = code;
    }
    return $result;
  }
  ValidationResult._() : super();
  factory ValidationResult.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ValidationResult.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ValidationResult',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.validation'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'isValid')
    ..aOS(2, _omitFieldNames ? '' : 'errorMessage')
    ..e<ValidationResult_ValidationCode>(
        3, _omitFieldNames ? '' : 'code', $pb.PbFieldType.OE,
        defaultOrMaker: ValidationResult_ValidationCode.UNKNOWN,
        valueOf: ValidationResult_ValidationCode.valueOf,
        enumValues: ValidationResult_ValidationCode.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ValidationResult clone() => ValidationResult()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ValidationResult copyWith(void Function(ValidationResult) updates) =>
      super.copyWith((message) => updates(message as ValidationResult))
          as ValidationResult;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ValidationResult create() => ValidationResult._();
  ValidationResult createEmptyInstance() => create();
  static $pb.PbList<ValidationResult> createRepeated() =>
      $pb.PbList<ValidationResult>();
  @$core.pragma('dart2js:noInline')
  static ValidationResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ValidationResult>(create);
  static ValidationResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isValid => $_getBF(0);
  @$pb.TagNumber(1)
  set isValid($core.bool v) {
    $_setBool(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasIsValid() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsValid() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get errorMessage => $_getSZ(1);
  @$pb.TagNumber(2)
  set errorMessage($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasErrorMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrorMessage() => clearField(2);

  @$pb.TagNumber(3)
  ValidationResult_ValidationCode get code => $_getN(2);
  @$pb.TagNumber(3)
  set code(ValidationResult_ValidationCode v) {
    setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearCode() => clearField(3);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
