//
//  Generated code. Do not modify.
//  source: cid.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'cid.pbenum.dart';

export 'cid.pbenum.dart';

/// CID message structure
class CID extends $pb.GeneratedMessage {
  factory CID({
    CIDVersion? version,
    $core.List<$core.int>? multihash,
    $core.String? codec,
  }) {
    final $result = create();
    if (version != null) {
      $result.version = version;
    }
    if (multihash != null) {
      $result.multihash = multihash;
    }
    if (codec != null) {
      $result.codec = codec;
    }
    return $result;
  }
  CID._() : super();
  factory CID.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CID.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CID', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..e<CIDVersion>(1, _omitFieldNames ? '' : 'version', $pb.PbFieldType.OE, defaultOrMaker: CIDVersion.CID_VERSION_UNSPECIFIED, valueOf: CIDVersion.valueOf, enumValues: CIDVersion.values)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'multihash', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'codec')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CID clone() => CID()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CID copyWith(void Function(CID) updates) => super.copyWith((message) => updates(message as CID)) as CID;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CID create() => CID._();
  CID createEmptyInstance() => create();
  static $pb.PbList<CID> createRepeated() => $pb.PbList<CID>();
  @$core.pragma('dart2js:noInline')
  static CID getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CID>(create);
  static CID? _defaultInstance;

  @$pb.TagNumber(1)
  CIDVersion get version => $_getN(0);
  @$pb.TagNumber(1)
  set version(CIDVersion v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get multihash => $_getN(1);
  @$pb.TagNumber(2)
  set multihash($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMultihash() => $_has(1);
  @$pb.TagNumber(2)
  void clearMultihash() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get codec => $_getSZ(2);
  @$pb.TagNumber(3)
  set codec($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasCodec() => $_has(2);
  @$pb.TagNumber(3)
  void clearCodec() => clearField(3);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
