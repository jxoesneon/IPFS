// This is a generated file - do not edit.
//
// Generated from google/protobuf/any.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/src/protobuf/mixins/well_known.dart' as $mixin;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Any extends $pb.GeneratedMessage with $mixin.AnyMixin {
  factory Any({
    $core.String? typeUrl,
    $core.List<$core.int>? value,
  }) {
    final result = create();
    if (typeUrl != null) result.typeUrl = typeUrl;
    if (value != null) result.value = value;
    return result;
  }

  Any._();

  factory Any.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Any.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Any',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.protobuf'),
      createEmptyInstance: create,
      wellKnownType: $mixin.WellKnownType.any)
    ..aOS(1, _omitFieldNames ? '' : 'typeUrl')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Any clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Any copyWith(void Function(Any) updates) =>
      super.copyWith((message) => updates(message as Any)) as Any;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Any create() => Any._();
  @$core.override
  Any createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Any getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Any>(create);
  static Any? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get typeUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set typeUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTypeUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearTypeUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);

  static Any pack($pb.GeneratedMessage message,
      {$core.String typeUrlPrefix = 'type.googleapis.com'}) {
    final result = create();
    $mixin.AnyMixin.packIntoAny(result, message, typeUrlPrefix: typeUrlPrefix);
    return result;
  }
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
