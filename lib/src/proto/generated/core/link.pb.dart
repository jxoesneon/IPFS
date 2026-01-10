// This is a generated file - do not edit.
//
// Generated from core/link.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'dag.pb.dart' as $0;
import 'link.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'link.pbenum.dart';

/// Extended link with additional metadata (uses standard PBLink)
class LinkMetadata extends $pb.GeneratedMessage {
  factory LinkMetadata({
    $0.PBLink? link,
    $fixnum.Int64? timestamp,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? metadata,
    LinkType? type,
    $core.int? bucketIndex,
    $core.int? depth,
  }) {
    final result = create();
    if (link != null) result.link = link;
    if (timestamp != null) result.timestamp = timestamp;
    if (metadata != null) result.metadata.addEntries(metadata);
    if (type != null) result.type = type;
    if (bucketIndex != null) result.bucketIndex = bucketIndex;
    if (depth != null) result.depth = depth;
    return result;
  }

  LinkMetadata._();

  factory LinkMetadata.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LinkMetadata.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LinkMetadata',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOM<$0.PBLink>(1, _omitFieldNames ? '' : 'link', subBuilder: $0.PBLink.create)
    ..aInt64(2, _omitFieldNames ? '' : 'timestamp')
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'metadata',
        entryClassName: 'LinkMetadata.MetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('ipfs.core.data_structures'))
    ..aE<LinkType>(4, _omitFieldNames ? '' : 'type', enumValues: LinkType.values)
    ..aI(5, _omitFieldNames ? '' : 'bucketIndex')
    ..aI(6, _omitFieldNames ? '' : 'depth')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkMetadata clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkMetadata copyWith(void Function(LinkMetadata) updates) =>
      super.copyWith((message) => updates(message as LinkMetadata)) as LinkMetadata;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LinkMetadata create() => LinkMetadata._();
  @$core.override
  LinkMetadata createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LinkMetadata getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LinkMetadata>(create);
  static LinkMetadata? _defaultInstance;

  /// Reference to the standard PBLink
  @$pb.TagNumber(1)
  $0.PBLink get link => $_getN(0);
  @$pb.TagNumber(1)
  set link($0.PBLink value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasLink() => $_has(0);
  @$pb.TagNumber(1)
  void clearLink() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.PBLink ensureLink() => $_ensure(0);

  /// Unix timestamp of when the link was created
  @$pb.TagNumber(2)
  $fixnum.Int64 get timestamp => $_getI64(1);
  @$pb.TagNumber(2)
  set timestamp($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTimestamp() => $_has(1);
  @$pb.TagNumber(2)
  void clearTimestamp() => $_clearField(2);

  /// Custom metadata or additional fields
  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.String> get metadata => $_getMap(2);

  /// Link type for different DAG structures
  @$pb.TagNumber(4)
  LinkType get type => $_getN(3);
  @$pb.TagNumber(4)
  set type(LinkType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);

  /// For HAMT links
  @$pb.TagNumber(5)
  $core.int get bucketIndex => $_getIZ(4);
  @$pb.TagNumber(5)
  set bucketIndex($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBucketIndex() => $_has(4);
  @$pb.TagNumber(5)
  void clearBucketIndex() => $_clearField(5);

  /// For trickle-dag links
  @$pb.TagNumber(6)
  $core.int get depth => $_getIZ(5);
  @$pb.TagNumber(6)
  set depth($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDepth() => $_has(5);
  @$pb.TagNumber(6)
  void clearDepth() => $_clearField(6);
}

const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
