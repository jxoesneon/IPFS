//
//  Generated code. Do not modify.
//  source: core/link.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'link.pbenum.dart';

export 'link.pbenum.dart';

/// A message representing a link between nodes or objects in IPFS.
class PBLink extends $pb.GeneratedMessage {
  factory PBLink({
    $core.String? name,
    $core.List<$core.int>? cid,
    $core.List<$core.int>? hash,
    $fixnum.Int64? size,
    $fixnum.Int64? timestamp,
    $core.bool? isDirectory,
    $core.Map<$core.String, $core.String>? metadata,
    LinkType? type,
    $core.int? bucketIndex,
    $core.int? depth,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (cid != null) {
      $result.cid = cid;
    }
    if (hash != null) {
      $result.hash = hash;
    }
    if (size != null) {
      $result.size = size;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    if (isDirectory != null) {
      $result.isDirectory = isDirectory;
    }
    if (metadata != null) {
      $result.metadata.addAll(metadata);
    }
    if (type != null) {
      $result.type = type;
    }
    if (bucketIndex != null) {
      $result.bucketIndex = bucketIndex;
    }
    if (depth != null) {
      $result.depth = depth;
    }
    return $result;
  }
  PBLink._() : super();
  factory PBLink.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PBLink.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PBLink', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'cid', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'hash', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(5, _omitFieldNames ? '' : 'timestamp')
    ..aOB(6, _omitFieldNames ? '' : 'isDirectory')
    ..m<$core.String, $core.String>(7, _omitFieldNames ? '' : 'metadata', entryClassName: 'PBLink.MetadataEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('ipfs.core.data_structures'))
    ..e<LinkType>(8, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: LinkType.LINK_TYPE_UNSPECIFIED, valueOf: LinkType.valueOf, enumValues: LinkType.values)
    ..a<$core.int>(9, _omitFieldNames ? '' : 'bucketIndex', $pb.PbFieldType.O3)
    ..a<$core.int>(10, _omitFieldNames ? '' : 'depth', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PBLink clone() => PBLink()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PBLink copyWith(void Function(PBLink) updates) => super.copyWith((message) => updates(message as PBLink)) as PBLink;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PBLink create() => PBLink._();
  PBLink createEmptyInstance() => create();
  static $pb.PbList<PBLink> createRepeated() => $pb.PbList<PBLink>();
  @$core.pragma('dart2js:noInline')
  static PBLink getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PBLink>(create);
  static PBLink? _defaultInstance;

  /// The name of the link (optional, could be a human-readable identifier).
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  /// The CID (Content Identifier) that the link points to.
  @$pb.TagNumber(2)
  $core.List<$core.int> get cid => $_getN(1);
  @$pb.TagNumber(2)
  set cid($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCid() => $_has(1);
  @$pb.TagNumber(2)
  void clearCid() => clearField(2);

  /// The hash of the linked object or node.
  @$pb.TagNumber(3)
  $core.List<$core.int> get hash => $_getN(2);
  @$pb.TagNumber(3)
  set hash($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasHash() => $_has(2);
  @$pb.TagNumber(3)
  void clearHash() => clearField(3);

  /// The size of the linked object or node (in bytes).
  @$pb.TagNumber(4)
  $fixnum.Int64 get size => $_getI64(3);
  @$pb.TagNumber(4)
  set size($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearSize() => clearField(4);

  /// Unix timestamp of when the link was created.
  @$pb.TagNumber(5)
  $fixnum.Int64 get timestamp => $_getI64(4);
  @$pb.TagNumber(5)
  set timestamp($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasTimestamp() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimestamp() => clearField(5);

  /// A flag indicating whether the linked object is a directory.
  @$pb.TagNumber(6)
  $core.bool get isDirectory => $_getBF(5);
  @$pb.TagNumber(6)
  set isDirectory($core.bool v) { $_setBool(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasIsDirectory() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsDirectory() => clearField(6);

  /// Custom metadata or additional fields for the link.
  @$pb.TagNumber(7)
  $core.Map<$core.String, $core.String> get metadata => $_getMap(6);

  /// Link type for different DAG structures
  @$pb.TagNumber(8)
  LinkType get type => $_getN(7);
  @$pb.TagNumber(8)
  set type(LinkType v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasType() => $_has(7);
  @$pb.TagNumber(8)
  void clearType() => clearField(8);

  /// For HAMT links
  @$pb.TagNumber(9)
  $core.int get bucketIndex => $_getIZ(8);
  @$pb.TagNumber(9)
  set bucketIndex($core.int v) { $_setSignedInt32(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasBucketIndex() => $_has(8);
  @$pb.TagNumber(9)
  void clearBucketIndex() => clearField(9);

  /// For trickle-dag links
  @$pb.TagNumber(10)
  $core.int get depth => $_getIZ(9);
  @$pb.TagNumber(10)
  set depth($core.int v) { $_setSignedInt32(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasDepth() => $_has(9);
  @$pb.TagNumber(10)
  void clearDepth() => clearField(10);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
