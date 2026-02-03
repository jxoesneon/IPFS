// This is a generated file - do not edit.
//
// Generated from core/cid.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'cid.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'cid.pbenum.dart';

class IPFSCIDProto extends $pb.GeneratedMessage {
  factory IPFSCIDProto({
    IPFSCIDVersion? version,
    $core.List<$core.int>? multihash,
    $core.String? codec,
    $core.String? multibasePrefix,
    $core.int? codecType,
  }) {
    final result = create();
    if (version != null) result.version = version;
    if (multihash != null) result.multihash = multihash;
    if (codec != null) result.codec = codec;
    if (multibasePrefix != null) result.multibasePrefix = multibasePrefix;
    if (codecType != null) result.codecType = codecType;
    return result;
  }

  IPFSCIDProto._();

  factory IPFSCIDProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IPFSCIDProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IPFSCIDProto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core'),
      createEmptyInstance: create)
    ..aE<IPFSCIDVersion>(1, _omitFieldNames ? '' : 'version',
        enumValues: IPFSCIDVersion.values)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'multihash', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'codec')
    ..aOS(4, _omitFieldNames ? '' : 'multibasePrefix')
    ..aI(5, _omitFieldNames ? '' : 'codecType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IPFSCIDProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IPFSCIDProto copyWith(void Function(IPFSCIDProto) updates) =>
      super.copyWith((message) => updates(message as IPFSCIDProto))
          as IPFSCIDProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IPFSCIDProto create() => IPFSCIDProto._();
  @$core.override
  IPFSCIDProto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IPFSCIDProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IPFSCIDProto>(create);
  static IPFSCIDProto? _defaultInstance;

  @$pb.TagNumber(1)
  IPFSCIDVersion get version => $_getN(0);
  @$pb.TagNumber(1)
  set version(IPFSCIDVersion value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get multihash => $_getN(1);
  @$pb.TagNumber(2)
  set multihash($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMultihash() => $_has(1);
  @$pb.TagNumber(2)
  void clearMultihash() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get codec => $_getSZ(2);
  @$pb.TagNumber(3)
  set codec($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCodec() => $_has(2);
  @$pb.TagNumber(3)
  void clearCodec() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get multibasePrefix => $_getSZ(3);
  @$pb.TagNumber(4)
  set multibasePrefix($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMultibasePrefix() => $_has(3);
  @$pb.TagNumber(4)
  void clearMultibasePrefix() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get codecType => $_getIZ(4);
  @$pb.TagNumber(5)
  set codecType($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCodecType() => $_has(4);
  @$pb.TagNumber(5)
  void clearCodecType() => $_clearField(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

