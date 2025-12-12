// This is a generated file - do not edit.
//
// Generated from core/pin.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'cid.pb.dart' as $0;
import 'pin.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'pin.pbenum.dart';

class PinProto extends $pb.GeneratedMessage {
  factory PinProto({
    $0.IPFSCIDProto? cid,
    PinTypeProto? type,
    $fixnum.Int64? timestamp,
  }) {
    final result = create();
    if (cid != null) result.cid = cid;
    if (type != null) result.type = type;
    if (timestamp != null) result.timestamp = timestamp;
    return result;
  }

  PinProto._();

  factory PinProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PinProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PinProto',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOM<$0.IPFSCIDProto>(1, _omitFieldNames ? '' : 'cid',
        subBuilder: $0.IPFSCIDProto.create)
    ..aE<PinTypeProto>(2, _omitFieldNames ? '' : 'type',
        enumValues: PinTypeProto.values)
    ..aInt64(3, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PinProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PinProto copyWith(void Function(PinProto) updates) =>
      super.copyWith((message) => updates(message as PinProto)) as PinProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PinProto create() => PinProto._();
  @$core.override
  PinProto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PinProto getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PinProto>(create);
  static PinProto? _defaultInstance;

  @$pb.TagNumber(1)
  $0.IPFSCIDProto get cid => $_getN(0);
  @$pb.TagNumber(1)
  set cid($0.IPFSCIDProto value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.IPFSCIDProto ensureCid() => $_ensure(0);

  @$pb.TagNumber(2)
  PinTypeProto get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(PinTypeProto value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestamp => $_getI64(2);
  @$pb.TagNumber(3)
  set timestamp($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestamp() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestamp() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
