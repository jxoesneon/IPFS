//
//  Generated code. Do not modify.
//  source: graphsync/graphsync.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'graphsync.pbenum.dart';

export 'graphsync.pbenum.dart';

/// Main Graphsync Message
class GraphsyncMessage extends $pb.GeneratedMessage {
  factory GraphsyncMessage({
    $core.Iterable<GraphsyncRequest>? requests,
    $core.Iterable<GraphsyncResponse>? responses,
    $core.Iterable<Block>? blocks,
    $core.Map<$core.String, $core.List<$core.int>>? extensions,
  }) {
    final $result = create();
    if (requests != null) {
      $result.requests.addAll(requests);
    }
    if (responses != null) {
      $result.responses.addAll(responses);
    }
    if (blocks != null) {
      $result.blocks.addAll(blocks);
    }
    if (extensions != null) {
      $result.extensions.addAll(extensions);
    }
    return $result;
  }
  GraphsyncMessage._() : super();
  factory GraphsyncMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory GraphsyncMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GraphsyncMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.graphsync'),
      createEmptyInstance: create)
    ..pc<GraphsyncRequest>(
        1, _omitFieldNames ? '' : 'requests', $pb.PbFieldType.PM,
        subBuilder: GraphsyncRequest.create)
    ..pc<GraphsyncResponse>(
        2, _omitFieldNames ? '' : 'responses', $pb.PbFieldType.PM,
        subBuilder: GraphsyncResponse.create)
    ..pc<Block>(3, _omitFieldNames ? '' : 'blocks', $pb.PbFieldType.PM,
        subBuilder: Block.create)
    ..m<$core.String, $core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'extensions',
        entryClassName: 'GraphsyncMessage.ExtensionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OY,
        packageName: const $pb.PackageName('ipfs.graphsync'))
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  GraphsyncMessage clone() => GraphsyncMessage()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  GraphsyncMessage copyWith(void Function(GraphsyncMessage) updates) =>
      super.copyWith((message) => updates(message as GraphsyncMessage))
          as GraphsyncMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GraphsyncMessage create() => GraphsyncMessage._();
  GraphsyncMessage createEmptyInstance() => create();
  static $pb.PbList<GraphsyncMessage> createRepeated() =>
      $pb.PbList<GraphsyncMessage>();
  @$core.pragma('dart2js:noInline')
  static GraphsyncMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GraphsyncMessage>(create);
  static GraphsyncMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<GraphsyncRequest> get requests => $_getList(0);

  @$pb.TagNumber(2)
  $core.List<GraphsyncResponse> get responses => $_getList(1);

  @$pb.TagNumber(3)
  $core.List<Block> get blocks => $_getList(2);

  @$pb.TagNumber(4)
  $core.Map<$core.String, $core.List<$core.int>> get extensions => $_getMap(3);
}

/// Request for graph traversal
class GraphsyncRequest extends $pb.GeneratedMessage {
  factory GraphsyncRequest({
    $core.int? id,
    $core.List<$core.int>? root,
    $core.List<$core.int>? selector,
    $core.int? priority,
    $core.Map<$core.String, $core.List<$core.int>>? extensions,
    $core.bool? cancel,
    $core.bool? pause,
    $core.bool? unpause,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (root != null) {
      $result.root = root;
    }
    if (selector != null) {
      $result.selector = selector;
    }
    if (priority != null) {
      $result.priority = priority;
    }
    if (extensions != null) {
      $result.extensions.addAll(extensions);
    }
    if (cancel != null) {
      $result.cancel = cancel;
    }
    if (pause != null) {
      $result.pause = pause;
    }
    if (unpause != null) {
      $result.unpause = unpause;
    }
    return $result;
  }
  GraphsyncRequest._() : super();
  factory GraphsyncRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory GraphsyncRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GraphsyncRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.graphsync'),
      createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.O3)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'root', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'selector', $pb.PbFieldType.OY)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'priority', $pb.PbFieldType.O3)
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

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  GraphsyncRequest clone() => GraphsyncRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  GraphsyncRequest copyWith(void Function(GraphsyncRequest) updates) =>
      super.copyWith((message) => updates(message as GraphsyncRequest))
          as GraphsyncRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GraphsyncRequest create() => GraphsyncRequest._();
  GraphsyncRequest createEmptyInstance() => create();
  static $pb.PbList<GraphsyncRequest> createRepeated() =>
      $pb.PbList<GraphsyncRequest>();
  @$core.pragma('dart2js:noInline')
  static GraphsyncRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GraphsyncRequest>(create);
  static GraphsyncRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int v) {
    $_setSignedInt32(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get root => $_getN(1);
  @$pb.TagNumber(2)
  set root($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasRoot() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoot() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get selector => $_getN(2);
  @$pb.TagNumber(3)
  set selector($core.List<$core.int> v) {
    $_setBytes(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasSelector() => $_has(2);
  @$pb.TagNumber(3)
  void clearSelector() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get priority => $_getIZ(3);
  @$pb.TagNumber(4)
  set priority($core.int v) {
    $_setSignedInt32(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasPriority() => $_has(3);
  @$pb.TagNumber(4)
  void clearPriority() => clearField(4);

  @$pb.TagNumber(5)
  $core.Map<$core.String, $core.List<$core.int>> get extensions => $_getMap(4);

  @$pb.TagNumber(6)
  $core.bool get cancel => $_getBF(5);
  @$pb.TagNumber(6)
  set cancel($core.bool v) {
    $_setBool(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasCancel() => $_has(5);
  @$pb.TagNumber(6)
  void clearCancel() => clearField(6);

  @$pb.TagNumber(7)
  $core.bool get pause => $_getBF(6);
  @$pb.TagNumber(7)
  set pause($core.bool v) {
    $_setBool(6, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasPause() => $_has(6);
  @$pb.TagNumber(7)
  void clearPause() => clearField(7);

  @$pb.TagNumber(8)
  $core.bool get unpause => $_getBF(7);
  @$pb.TagNumber(8)
  set unpause($core.bool v) {
    $_setBool(7, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasUnpause() => $_has(7);
  @$pb.TagNumber(8)
  void clearUnpause() => clearField(8);
}

/// Response to graph request
class GraphsyncResponse extends $pb.GeneratedMessage {
  factory GraphsyncResponse({
    $core.int? id,
    ResponseStatus? status,
    $core.Map<$core.String, $core.List<$core.int>>? extensions,
    $core.Map<$core.String, $core.String>? metadata,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (status != null) {
      $result.status = status;
    }
    if (extensions != null) {
      $result.extensions.addAll(extensions);
    }
    if (metadata != null) {
      $result.metadata.addAll(metadata);
    }
    return $result;
  }
  GraphsyncResponse._() : super();
  factory GraphsyncResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory GraphsyncResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GraphsyncResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.graphsync'),
      createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.O3)
    ..e<ResponseStatus>(2, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OE,
        defaultOrMaker: ResponseStatus.RS_IN_PROGRESS,
        valueOf: ResponseStatus.valueOf,
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

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  GraphsyncResponse clone() => GraphsyncResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  GraphsyncResponse copyWith(void Function(GraphsyncResponse) updates) =>
      super.copyWith((message) => updates(message as GraphsyncResponse))
          as GraphsyncResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GraphsyncResponse create() => GraphsyncResponse._();
  GraphsyncResponse createEmptyInstance() => create();
  static $pb.PbList<GraphsyncResponse> createRepeated() =>
      $pb.PbList<GraphsyncResponse>();
  @$core.pragma('dart2js:noInline')
  static GraphsyncResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GraphsyncResponse>(create);
  static GraphsyncResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int v) {
    $_setSignedInt32(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  ResponseStatus get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(ResponseStatus v) {
    setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => clearField(2);

  @$pb.TagNumber(3)
  $core.Map<$core.String, $core.List<$core.int>> get extensions => $_getMap(2);

  @$pb.TagNumber(4)
  $core.Map<$core.String, $core.String> get metadata => $_getMap(3);
}

/// Block data with prefix
class Block extends $pb.GeneratedMessage {
  factory Block({
    $core.List<$core.int>? prefix,
    $core.List<$core.int>? data,
  }) {
    final $result = create();
    if (prefix != null) {
      $result.prefix = prefix;
    }
    if (data != null) {
      $result.data = data;
    }
    return $result;
  }
  Block._() : super();
  factory Block.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Block.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Block',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.graphsync'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'prefix', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Block clone() => Block()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Block copyWith(void Function(Block) updates) =>
      super.copyWith((message) => updates(message as Block)) as Block;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Block create() => Block._();
  Block createEmptyInstance() => create();
  static $pb.PbList<Block> createRepeated() => $pb.PbList<Block>();
  @$core.pragma('dart2js:noInline')
  static Block getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Block>(create);
  static Block? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get prefix => $_getN(0);
  @$pb.TagNumber(1)
  set prefix($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPrefix() => $_has(0);
  @$pb.TagNumber(1)
  void clearPrefix() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => clearField(2);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
