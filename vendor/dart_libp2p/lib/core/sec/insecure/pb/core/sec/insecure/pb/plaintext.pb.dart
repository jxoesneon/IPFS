// This is a generated file - do not edit.
//
// Generated from core/sec/insecure/pb/plaintext.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import '../../../crypto/pb/crypto.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Exchange extends $pb.GeneratedMessage {
  factory Exchange({
    $core.List<$core.int>? id,
    $0.PublicKey? pubkey,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (pubkey != null) result.pubkey = pubkey;
    return result;
  }

  Exchange._();

  factory Exchange.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Exchange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Exchange',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'plaintext.pb'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OY)
    ..aOM<$0.PublicKey>(2, _omitFieldNames ? '' : 'pubkey',
        subBuilder: $0.PublicKey.create);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Exchange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Exchange copyWith(void Function(Exchange) updates) =>
      super.copyWith((message) => updates(message as Exchange)) as Exchange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Exchange create() => Exchange._();
  @$core.override
  Exchange createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Exchange getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Exchange>(create);
  static Exchange? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get id => $_getN(0);
  @$pb.TagNumber(1)
  set id($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.PublicKey get pubkey => $_getN(1);
  @$pb.TagNumber(2)
  set pubkey($0.PublicKey value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearPubkey() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.PublicKey ensurePubkey() => $_ensure(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
