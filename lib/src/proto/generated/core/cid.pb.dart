//
//  Generated code. Do not modify.
//  source: core/cid.proto
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

class IPFSCIDProto extends $pb.GeneratedMessage {
  factory IPFSCIDProto({
    IPFSCIDVersion? version,
    $core.List<$core.int>? multihash,
    $core.String? codec,
    $core.String? multibasePrefix,
    $core.int? codecType,
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
    if (multibasePrefix != null) {
      $result.multibasePrefix = multibasePrefix;
    }
    if (codecType != null) {
      $result.codecType = codecType;
    }
    return $result;
  }
  IPFSCIDProto._() : super();
  factory IPFSCIDProto.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory IPFSCIDProto.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IPFSCIDProto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core'),
      createEmptyInstance: create)
    ..e<IPFSCIDVersion>(1, _omitFieldNames ? '' : 'version', $pb.PbFieldType.OE,
        defaultOrMaker: IPFSCIDVersion.IPFS_CID_VERSION_UNSPECIFIED,
        valueOf: IPFSCIDVersion.valueOf,
        enumValues: IPFSCIDVersion.values)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'multihash', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'codec')
    ..aOS(4, _omitFieldNames ? '' : 'multibasePrefix')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'codecType', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  IPFSCIDProto clone() => IPFSCIDProto()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  IPFSCIDProto copyWith(void Function(IPFSCIDProto) updates) =>
      super.copyWith((message) => updates(message as IPFSCIDProto))
          as IPFSCIDProto;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IPFSCIDProto create() => IPFSCIDProto._();
  IPFSCIDProto createEmptyInstance() => create();
  static $pb.PbList<IPFSCIDProto> createRepeated() =>
      $pb.PbList<IPFSCIDProto>();
  @$core.pragma('dart2js:noInline')
  static IPFSCIDProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IPFSCIDProto>(create);
  static IPFSCIDProto? _defaultInstance;

  @$pb.TagNumber(1)
  IPFSCIDVersion get version => $_getN(0);
  @$pb.TagNumber(1)
  set version(IPFSCIDVersion v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get multihash => $_getN(1);
  @$pb.TagNumber(2)
  set multihash($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasMultihash() => $_has(1);
  @$pb.TagNumber(2)
  void clearMultihash() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get codec => $_getSZ(2);
  @$pb.TagNumber(3)
  set codec($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasCodec() => $_has(2);
  @$pb.TagNumber(3)
  void clearCodec() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get multibasePrefix => $_getSZ(3);
  @$pb.TagNumber(4)
  set multibasePrefix($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasMultibasePrefix() => $_has(3);
  @$pb.TagNumber(4)
  void clearMultibasePrefix() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get codecType => $_getIZ(4);
  @$pb.TagNumber(5)
  set codecType($core.int v) {
    $_setSignedInt32(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasCodecType() => $_has(4);
  @$pb.TagNumber(5)
  void clearCodecType() => clearField(5);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
