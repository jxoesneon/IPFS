//
//  Generated code. Do not modify.
//  source: core/pin.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'cid.pb.dart' as $2;
import 'pin.pbenum.dart';

export 'pin.pbenum.dart';

class PinProto extends $pb.GeneratedMessage {
  factory PinProto({
    $2.IPFSCIDProto? cid,
    PinTypeProto? type,
    $fixnum.Int64? timestamp,
  }) {
    final $result = create();
    if (cid != null) {
      $result.cid = cid;
    }
    if (type != null) {
      $result.type = type;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    return $result;
  }
  PinProto._() : super();
  factory PinProto.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory PinProto.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PinProto',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOM<$2.IPFSCIDProto>(1, _omitFieldNames ? '' : 'cid',
        subBuilder: $2.IPFSCIDProto.create)
    ..e<PinTypeProto>(2, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE,
        defaultOrMaker: PinTypeProto.PIN_TYPE_UNSPECIFIED,
        valueOf: PinTypeProto.valueOf,
        enumValues: PinTypeProto.values)
    ..aInt64(3, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  PinProto clone() => PinProto()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  PinProto copyWith(void Function(PinProto) updates) =>
      super.copyWith((message) => updates(message as PinProto)) as PinProto;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PinProto create() => PinProto._();
  PinProto createEmptyInstance() => create();
  static $pb.PbList<PinProto> createRepeated() => $pb.PbList<PinProto>();
  @$core.pragma('dart2js:noInline')
  static PinProto getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PinProto>(create);
  static PinProto? _defaultInstance;

  @$pb.TagNumber(1)
  $2.IPFSCIDProto get cid => $_getN(0);
  @$pb.TagNumber(1)
  set cid($2.IPFSCIDProto v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);
  @$pb.TagNumber(1)
  $2.IPFSCIDProto ensureCid() => $_ensure(0);

  @$pb.TagNumber(2)
  PinTypeProto get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(PinTypeProto v) {
    setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestamp => $_getI64(2);
  @$pb.TagNumber(3)
  set timestamp($fixnum.Int64 v) {
    $_setInt64(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasTimestamp() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestamp() => clearField(3);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
