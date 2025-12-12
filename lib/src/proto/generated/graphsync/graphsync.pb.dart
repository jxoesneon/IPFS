// This is a generated file - do not edit.
//
// Generated from graphsync/graphsync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'graphsync.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'graphsync.pbenum.dart';

/// Main Graphsync Message
class GraphsyncMessage extends $pb.GeneratedMessage {
  factory GraphsyncMessage({
    $core.Iterable<GraphsyncRequest>? requests,
    $core.Iterable<GraphsyncResponse>? responses,
    $core.Iterable<Block>? blocks,
    $core.Iterable<$core.MapEntry<$core.String, $core.List<$core.int>>>?
        extensions,
  }) {
    final result = create();
    if (requests != null) result.requests.addAll(requests);
    if (responses != null) result.responses.addAll(responses);
    if (blocks != null) result.blocks.addAll(blocks);
    if (extensions != null) result.extensions.addEntries(extensions);
    return result;
  }

  GraphsyncMessage._();

  factory GraphsyncMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GraphsyncMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GraphsyncMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.graphsync'),
      createEmptyInstance: create)
    ..pPM<GraphsyncRequest>(1, _omitFieldNames ? '' : 'requests',
        subBuilder: GraphsyncRequest.create)
    ..pPM<GraphsyncResponse>(2, _omitFieldNames ? '' : 'responses',
        subBuilder: GraphsyncResponse.create)
    ..pPM<Block>(3, _omitFieldNames ? '' : 'blocks', subBuilder: Block.create)
    ..m<$core.String, $core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'extensions',
        entryClassName: 'GraphsyncMessage.ExtensionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OY,
        packageName: const $pb.PackageName('ipfs.graphsync'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GraphsyncMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GraphsyncMessage copyWith(void Function(GraphsyncMessage) updates) =>
      super.copyWith((message) => updates(message as GraphsyncMessage))
          as GraphsyncMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GraphsyncMessage create() => GraphsyncMessage._();
  @$core.override
  GraphsyncMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GraphsyncMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GraphsyncMessage>(create);
  static GraphsyncMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<GraphsyncRequest> get requests => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<GraphsyncResponse> get responses => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<Block> get blocks => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.List<$core.int>> get extensions => $_getMap(3);
}

/// Request for graph traversal
class GraphsyncRequest extends $pb.GeneratedMessage {
  factory GraphsyncRequest({
    $core.int? id,
    $core.List<$core.int>? root,
    $core.List<$core.int>? selector,
    $core.int? priority,
    $core.Iterable<$core.MapEntry<$core.String, $core.List<$core.int>>>?
        extensions,
    $core.bool? cancel,
    $core.bool? pause,
    $core.bool? unpause,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (root != null) result.root = root;
    if (selector != null) result.selector = selector;
    if (priority != null) result.priority = priority;
    if (extensions != null) result.extensions.addEntries(extensions);
    if (cancel != null) result.cancel = cancel;
    if (pause != null) result.pause = pause;
    if (unpause != null) result.unpause = unpause;
    return result;
  }

  GraphsyncRequest._();

  factory GraphsyncRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GraphsyncRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GraphsyncRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.graphsync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'root', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'selector', $pb.PbFieldType.OY)
    ..aI(4, _omitFieldNames ? '' : 'priority')
    ..m<$core.String, $core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'extensions',
        entryClassName: 'GraphsyncRequest.ExtensionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OY,
        packageName: const $pb.PackageName('ipfs.graphsync'))
    ..aOB(6, _omitFieldNames ? '' : 'cancel')
    ..aOB(7, _omitFieldNames ? '' : 'pause')
    ..aOB(8, _omitFieldNames ? '' : 'unpause')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GraphsyncRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GraphsyncRequest copyWith(void Function(GraphsyncRequest) updates) =>
      super.copyWith((message) => updates(message as GraphsyncRequest))
          as GraphsyncRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GraphsyncRequest create() => GraphsyncRequest._();
  @$core.override
  GraphsyncRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GraphsyncRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GraphsyncRequest>(create);
  static GraphsyncRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get root => $_getN(1);
  @$pb.TagNumber(2)
  set root($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRoot() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoot() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get selector => $_getN(2);
  @$pb.TagNumber(3)
  set selector($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSelector() => $_has(2);
  @$pb.TagNumber(3)
  void clearSelector() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get priority => $_getIZ(3);
  @$pb.TagNumber(4)
  set priority($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPriority() => $_has(3);
  @$pb.TagNumber(4)
  void clearPriority() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbMap<$core.String, $core.List<$core.int>> get extensions => $_getMap(4);

  @$pb.TagNumber(6)
  $core.bool get cancel => $_getBF(5);
  @$pb.TagNumber(6)
  set cancel($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCancel() => $_has(5);
  @$pb.TagNumber(6)
  void clearCancel() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get pause => $_getBF(6);
  @$pb.TagNumber(7)
  set pause($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPause() => $_has(6);
  @$pb.TagNumber(7)
  void clearPause() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get unpause => $_getBF(7);
  @$pb.TagNumber(8)
  set unpause($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUnpause() => $_has(7);
  @$pb.TagNumber(8)
  void clearUnpause() => $_clearField(8);
}

/// Response to graph request
class GraphsyncResponse extends $pb.GeneratedMessage {
  factory GraphsyncResponse({
    $core.int? id,
    ResponseStatus? status,
    $core.Iterable<$core.MapEntry<$core.String, $core.List<$core.int>>>?
        extensions,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? metadata,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (status != null) result.status = status;
    if (extensions != null) result.extensions.addEntries(extensions);
    if (metadata != null) result.metadata.addEntries(metadata);
    return result;
  }

  GraphsyncResponse._();

  factory GraphsyncResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GraphsyncResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GraphsyncResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.graphsync'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id')
    ..aE<ResponseStatus>(2, _omitFieldNames ? '' : 'status',
        enumValues: ResponseStatus.values)
    ..m<$core.String, $core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'extensions',
        entryClassName: 'GraphsyncResponse.ExtensionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OY,
        packageName: const $pb.PackageName('ipfs.graphsync'))
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'metadata',
        entryClassName: 'GraphsyncResponse.MetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('ipfs.graphsync'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GraphsyncResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GraphsyncResponse copyWith(void Function(GraphsyncResponse) updates) =>
      super.copyWith((message) => updates(message as GraphsyncResponse))
          as GraphsyncResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GraphsyncResponse create() => GraphsyncResponse._();
  @$core.override
  GraphsyncResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GraphsyncResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GraphsyncResponse>(create);
  static GraphsyncResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  ResponseStatus get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(ResponseStatus value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.List<$core.int>> get extensions => $_getMap(2);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get metadata => $_getMap(3);
}

/// Block data with prefix
class Block extends $pb.GeneratedMessage {
  factory Block({
    $core.List<$core.int>? prefix,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (prefix != null) result.prefix = prefix;
    if (data != null) result.data = data;
    return result;
  }

  Block._();

  factory Block.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Block.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Block',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.graphsync'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'prefix', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Block clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Block copyWith(void Function(Block) updates) =>
      super.copyWith((message) => updates(message as Block)) as Block;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Block create() => Block._();
  @$core.override
  Block createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Block getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Block>(create);
  static Block? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get prefix => $_getN(0);
  @$pb.TagNumber(1)
  set prefix($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPrefix() => $_has(0);
  @$pb.TagNumber(1)
  void clearPrefix() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
