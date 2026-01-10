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

import 'dag.pb.dart' as $5;
import 'link.pbenum.dart';

export 'link.pbenum.dart';

/// Extended link with additional metadata (uses standard PBLink)
class LinkMetadata extends $pb.GeneratedMessage {
  factory LinkMetadata({
    $5.PBLink? link,
    $fixnum.Int64? timestamp,
    $core.Map<$core.String, $core.String>? metadata,
    LinkType? type,
    $core.int? bucketIndex,
    $core.int? depth,
  }) {
    final $result = create();
    if (link != null) {
      $result.link = link;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
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
  LinkMetadata._() : super();
  factory LinkMetadata.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory LinkMetadata.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LinkMetadata',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOM<$5.PBLink>(1, _omitFieldNames ? '' : 'link',
        subBuilder: $5.PBLink.create)
    ..aInt64(2, _omitFieldNames ? '' : 'timestamp')
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'metadata',
        entryClassName: 'LinkMetadata.MetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('ipfs.core.data_structures'))
    ..e<LinkType>(4, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE,
        defaultOrMaker: LinkType.LINK_TYPE_UNSPECIFIED,
        valueOf: LinkType.valueOf,
        enumValues: LinkType.values)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'bucketIndex', $pb.PbFieldType.O3)
    ..a<$core.int>(6, _omitFieldNames ? '' : 'depth', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  LinkMetadata clone() => LinkMetadata()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  LinkMetadata copyWith(void Function(LinkMetadata) updates) =>
      super.copyWith((message) => updates(message as LinkMetadata))
          as LinkMetadata;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LinkMetadata create() => LinkMetadata._();
  LinkMetadata createEmptyInstance() => create();
  static $pb.PbList<LinkMetadata> createRepeated() =>
      $pb.PbList<LinkMetadata>();
  @$core.pragma('dart2js:noInline')
  static LinkMetadata getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LinkMetadata>(create);
  static LinkMetadata? _defaultInstance;

  /// Reference to the standard PBLink
  @$pb.TagNumber(1)
  $5.PBLink get link => $_getN(0);
  @$pb.TagNumber(1)
  set link($5.PBLink v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasLink() => $_has(0);
  @$pb.TagNumber(1)
  void clearLink() => clearField(1);
  @$pb.TagNumber(1)
  $5.PBLink ensureLink() => $_ensure(0);

  /// Unix timestamp of when the link was created
  @$pb.TagNumber(2)
  $fixnum.Int64 get timestamp => $_getI64(1);
  @$pb.TagNumber(2)
  set timestamp($fixnum.Int64 v) {
    $_setInt64(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasTimestamp() => $_has(1);
  @$pb.TagNumber(2)
  void clearTimestamp() => clearField(2);

  /// Custom metadata or additional fields
  @$pb.TagNumber(3)
  $core.Map<$core.String, $core.String> get metadata => $_getMap(2);

  /// Link type for different DAG structures
  @$pb.TagNumber(4)
  LinkType get type => $_getN(3);
  @$pb.TagNumber(4)
  set type(LinkType v) {
    setField(4, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => clearField(4);

  /// For HAMT links
  @$pb.TagNumber(5)
  $core.int get bucketIndex => $_getIZ(4);
  @$pb.TagNumber(5)
  set bucketIndex($core.int v) {
    $_setSignedInt32(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasBucketIndex() => $_has(4);
  @$pb.TagNumber(5)
  void clearBucketIndex() => clearField(5);

  /// For trickle-dag links
  @$pb.TagNumber(6)
  $core.int get depth => $_getIZ(5);
  @$pb.TagNumber(6)
  set depth($core.int v) {
    $_setSignedInt32(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasDepth() => $_has(5);
  @$pb.TagNumber(6)
  void clearDepth() => clearField(6);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
