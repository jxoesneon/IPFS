//
//  Generated code. Do not modify.
//  source: blockstore.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'block.pb.dart' as $0;
import 'cid.pb.dart' as $1;

/// Functionality for adding a block to the store
class BlockStoreProto_AddBlockRequest extends $pb.GeneratedMessage {
  factory BlockStoreProto_AddBlockRequest({
    $0.BlockProto? block,
  }) {
    final $result = create();
    if (block != null) {
      $result.block = block;
    }
    return $result;
  }
  BlockStoreProto_AddBlockRequest._() : super();
  factory BlockStoreProto_AddBlockRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockStoreProto_AddBlockRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockStoreProto.AddBlockRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOM<$0.BlockProto>(1, _omitFieldNames ? '' : 'block', subBuilder: $0.BlockProto.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockStoreProto_AddBlockRequest clone() => BlockStoreProto_AddBlockRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockStoreProto_AddBlockRequest copyWith(void Function(BlockStoreProto_AddBlockRequest) updates) => super.copyWith((message) => updates(message as BlockStoreProto_AddBlockRequest)) as BlockStoreProto_AddBlockRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockStoreProto_AddBlockRequest create() => BlockStoreProto_AddBlockRequest._();
  BlockStoreProto_AddBlockRequest createEmptyInstance() => create();
  static $pb.PbList<BlockStoreProto_AddBlockRequest> createRepeated() => $pb.PbList<BlockStoreProto_AddBlockRequest>();
  @$core.pragma('dart2js:noInline')
  static BlockStoreProto_AddBlockRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockStoreProto_AddBlockRequest>(create);
  static BlockStoreProto_AddBlockRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $0.BlockProto get block => $_getN(0);
  @$pb.TagNumber(1)
  set block($0.BlockProto v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasBlock() => $_has(0);
  @$pb.TagNumber(1)
  void clearBlock() => clearField(1);
  @$pb.TagNumber(1)
  $0.BlockProto ensureBlock() => $_ensure(0);
}

/// Response for adding a block
class BlockStoreProto_AddBlockResponse extends $pb.GeneratedMessage {
  factory BlockStoreProto_AddBlockResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  BlockStoreProto_AddBlockResponse._() : super();
  factory BlockStoreProto_AddBlockResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockStoreProto_AddBlockResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockStoreProto.AddBlockResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockStoreProto_AddBlockResponse clone() => BlockStoreProto_AddBlockResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockStoreProto_AddBlockResponse copyWith(void Function(BlockStoreProto_AddBlockResponse) updates) => super.copyWith((message) => updates(message as BlockStoreProto_AddBlockResponse)) as BlockStoreProto_AddBlockResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockStoreProto_AddBlockResponse create() => BlockStoreProto_AddBlockResponse._();
  BlockStoreProto_AddBlockResponse createEmptyInstance() => create();
  static $pb.PbList<BlockStoreProto_AddBlockResponse> createRepeated() => $pb.PbList<BlockStoreProto_AddBlockResponse>();
  @$core.pragma('dart2js:noInline')
  static BlockStoreProto_AddBlockResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockStoreProto_AddBlockResponse>(create);
  static BlockStoreProto_AddBlockResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

/// Functionality for retrieving a block by its CID
class BlockStoreProto_GetBlockRequest extends $pb.GeneratedMessage {
  factory BlockStoreProto_GetBlockRequest({
    $1.CID? cid,
  }) {
    final $result = create();
    if (cid != null) {
      $result.cid = cid;
    }
    return $result;
  }
  BlockStoreProto_GetBlockRequest._() : super();
  factory BlockStoreProto_GetBlockRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockStoreProto_GetBlockRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockStoreProto.GetBlockRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOM<$1.CID>(1, _omitFieldNames ? '' : 'cid', subBuilder: $1.CID.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockStoreProto_GetBlockRequest clone() => BlockStoreProto_GetBlockRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockStoreProto_GetBlockRequest copyWith(void Function(BlockStoreProto_GetBlockRequest) updates) => super.copyWith((message) => updates(message as BlockStoreProto_GetBlockRequest)) as BlockStoreProto_GetBlockRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockStoreProto_GetBlockRequest create() => BlockStoreProto_GetBlockRequest._();
  BlockStoreProto_GetBlockRequest createEmptyInstance() => create();
  static $pb.PbList<BlockStoreProto_GetBlockRequest> createRepeated() => $pb.PbList<BlockStoreProto_GetBlockRequest>();
  @$core.pragma('dart2js:noInline')
  static BlockStoreProto_GetBlockRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockStoreProto_GetBlockRequest>(create);
  static BlockStoreProto_GetBlockRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $1.CID get cid => $_getN(0);
  @$pb.TagNumber(1)
  set cid($1.CID v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);
  @$pb.TagNumber(1)
  $1.CID ensureCid() => $_ensure(0);
}

/// Response for retrieving a block
class BlockStoreProto_GetBlockResponse extends $pb.GeneratedMessage {
  factory BlockStoreProto_GetBlockResponse({
    $0.BlockProto? block,
    $core.bool? found,
  }) {
    final $result = create();
    if (block != null) {
      $result.block = block;
    }
    if (found != null) {
      $result.found = found;
    }
    return $result;
  }
  BlockStoreProto_GetBlockResponse._() : super();
  factory BlockStoreProto_GetBlockResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockStoreProto_GetBlockResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockStoreProto.GetBlockResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOM<$0.BlockProto>(1, _omitFieldNames ? '' : 'block', subBuilder: $0.BlockProto.create)
    ..aOB(2, _omitFieldNames ? '' : 'found')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockStoreProto_GetBlockResponse clone() => BlockStoreProto_GetBlockResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockStoreProto_GetBlockResponse copyWith(void Function(BlockStoreProto_GetBlockResponse) updates) => super.copyWith((message) => updates(message as BlockStoreProto_GetBlockResponse)) as BlockStoreProto_GetBlockResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockStoreProto_GetBlockResponse create() => BlockStoreProto_GetBlockResponse._();
  BlockStoreProto_GetBlockResponse createEmptyInstance() => create();
  static $pb.PbList<BlockStoreProto_GetBlockResponse> createRepeated() => $pb.PbList<BlockStoreProto_GetBlockResponse>();
  @$core.pragma('dart2js:noInline')
  static BlockStoreProto_GetBlockResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockStoreProto_GetBlockResponse>(create);
  static BlockStoreProto_GetBlockResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $0.BlockProto get block => $_getN(0);
  @$pb.TagNumber(1)
  set block($0.BlockProto v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasBlock() => $_has(0);
  @$pb.TagNumber(1)
  void clearBlock() => clearField(1);
  @$pb.TagNumber(1)
  $0.BlockProto ensureBlock() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get found => $_getBF(1);
  @$pb.TagNumber(2)
  set found($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasFound() => $_has(1);
  @$pb.TagNumber(2)
  void clearFound() => clearField(2);
}

/// Functionality for removing a block from the store
class BlockStoreProto_RemoveBlockRequest extends $pb.GeneratedMessage {
  factory BlockStoreProto_RemoveBlockRequest({
    $1.CID? cid,
  }) {
    final $result = create();
    if (cid != null) {
      $result.cid = cid;
    }
    return $result;
  }
  BlockStoreProto_RemoveBlockRequest._() : super();
  factory BlockStoreProto_RemoveBlockRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockStoreProto_RemoveBlockRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockStoreProto.RemoveBlockRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOM<$1.CID>(1, _omitFieldNames ? '' : 'cid', subBuilder: $1.CID.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockStoreProto_RemoveBlockRequest clone() => BlockStoreProto_RemoveBlockRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockStoreProto_RemoveBlockRequest copyWith(void Function(BlockStoreProto_RemoveBlockRequest) updates) => super.copyWith((message) => updates(message as BlockStoreProto_RemoveBlockRequest)) as BlockStoreProto_RemoveBlockRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockStoreProto_RemoveBlockRequest create() => BlockStoreProto_RemoveBlockRequest._();
  BlockStoreProto_RemoveBlockRequest createEmptyInstance() => create();
  static $pb.PbList<BlockStoreProto_RemoveBlockRequest> createRepeated() => $pb.PbList<BlockStoreProto_RemoveBlockRequest>();
  @$core.pragma('dart2js:noInline')
  static BlockStoreProto_RemoveBlockRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockStoreProto_RemoveBlockRequest>(create);
  static BlockStoreProto_RemoveBlockRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $1.CID get cid => $_getN(0);
  @$pb.TagNumber(1)
  set cid($1.CID v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);
  @$pb.TagNumber(1)
  $1.CID ensureCid() => $_ensure(0);
}

/// Response for removing a block
class BlockStoreProto_RemoveBlockResponse extends $pb.GeneratedMessage {
  factory BlockStoreProto_RemoveBlockResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  BlockStoreProto_RemoveBlockResponse._() : super();
  factory BlockStoreProto_RemoveBlockResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockStoreProto_RemoveBlockResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockStoreProto.RemoveBlockResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockStoreProto_RemoveBlockResponse clone() => BlockStoreProto_RemoveBlockResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockStoreProto_RemoveBlockResponse copyWith(void Function(BlockStoreProto_RemoveBlockResponse) updates) => super.copyWith((message) => updates(message as BlockStoreProto_RemoveBlockResponse)) as BlockStoreProto_RemoveBlockResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockStoreProto_RemoveBlockResponse create() => BlockStoreProto_RemoveBlockResponse._();
  BlockStoreProto_RemoveBlockResponse createEmptyInstance() => create();
  static $pb.PbList<BlockStoreProto_RemoveBlockResponse> createRepeated() => $pb.PbList<BlockStoreProto_RemoveBlockResponse>();
  @$core.pragma('dart2js:noInline')
  static BlockStoreProto_RemoveBlockResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockStoreProto_RemoveBlockResponse>(create);
  static BlockStoreProto_RemoveBlockResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

/// Represents a BlockStore that contains multiple blocks.
class BlockStoreProto extends $pb.GeneratedMessage {
  factory BlockStoreProto({
    $core.Iterable<$0.BlockProto>? blocks,
  }) {
    final $result = create();
    if (blocks != null) {
      $result.blocks.addAll(blocks);
    }
    return $result;
  }
  BlockStoreProto._() : super();
  factory BlockStoreProto.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockStoreProto.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockStoreProto', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..pc<$0.BlockProto>(1, _omitFieldNames ? '' : 'blocks', $pb.PbFieldType.PM, subBuilder: $0.BlockProto.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockStoreProto clone() => BlockStoreProto()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockStoreProto copyWith(void Function(BlockStoreProto) updates) => super.copyWith((message) => updates(message as BlockStoreProto)) as BlockStoreProto;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockStoreProto create() => BlockStoreProto._();
  BlockStoreProto createEmptyInstance() => create();
  static $pb.PbList<BlockStoreProto> createRepeated() => $pb.PbList<BlockStoreProto>();
  @$core.pragma('dart2js:noInline')
  static BlockStoreProto getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockStoreProto>(create);
  static BlockStoreProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$0.BlockProto> get blocks => $_getList(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
