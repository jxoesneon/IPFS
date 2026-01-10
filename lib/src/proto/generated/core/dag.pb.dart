//
//  Generated code. Do not modify.
//  source: core/dag.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

/// PBLink represents a link between two DAG nodes
class PBLink extends $pb.GeneratedMessage {
  factory PBLink({
    $core.List<$core.int>? hash,
    $core.String? name,
    $fixnum.Int64? size,
  }) {
    final $result = create();
    if (hash != null) {
      $result.hash = hash;
    }
    if (name != null) {
      $result.name = name;
    }
    if (size != null) {
      $result.size = size;
    }
    return $result;
  }
  PBLink._() : super();
  factory PBLink.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PBLink.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PBLink', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'hash', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
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

  /// multihash of the target object
  @$pb.TagNumber(1)
  $core.List<$core.int> get hash => $_getN(0);
  @$pb.TagNumber(1)
  set hash($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasHash() => $_has(0);
  @$pb.TagNumber(1)
  void clearHash() => clearField(1);

  /// utf string name. should be unique per object
  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => clearField(2);

  /// cumulative size of target object
  @$pb.TagNumber(3)
  $fixnum.Int64 get size => $_getI64(2);
  @$pb.TagNumber(3)
  set size($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearSize() => clearField(3);
}

/// PBNode represents a DAG node
class PBNode extends $pb.GeneratedMessage {
  factory PBNode({
    $core.List<$core.int>? data,
    $core.Iterable<PBLink>? links,
  }) {
    final $result = create();
    if (data != null) {
      $result.data = data;
    }
    if (links != null) {
      $result.links.addAll(links);
    }
    return $result;
  }
  PBNode._() : super();
  factory PBNode.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PBNode.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PBNode', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..pc<PBLink>(2, _omitFieldNames ? '' : 'links', $pb.PbFieldType.PM, subBuilder: PBLink.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PBNode clone() => PBNode()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PBNode copyWith(void Function(PBNode) updates) => super.copyWith((message) => updates(message as PBNode)) as PBNode;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PBNode create() => PBNode._();
  PBNode createEmptyInstance() => create();
  static $pb.PbList<PBNode> createRepeated() => $pb.PbList<PBNode>();
  @$core.pragma('dart2js:noInline')
  static PBNode getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PBNode>(create);
  static PBNode? _defaultInstance;

  /// opaque user data content
  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => clearField(1);

  /// refs to other objects
  @$pb.TagNumber(2)
  $core.List<PBLink> get links => $_getList(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
