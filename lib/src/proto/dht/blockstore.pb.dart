//
//  Generated code. Do not modify.
//  source: blockstore.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'block.pb.dart' as $0;
import 'cid.pb.dart' as $1;
import 'google/protobuf/empty.pb.dart' as $2;

/// Response message for adding a block
class AddBlockResponse extends $pb.GeneratedMessage {
  factory AddBlockResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final result = create();
    if (success != null) {
      result.success = success;
    }
    if (message != null) {
      result.message = message;
    }
    return result;
  }
  AddBlockResponse._() : super();
  factory AddBlockResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AddBlockResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AddBlockResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AddBlockResponse clone() => AddBlockResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AddBlockResponse copyWith(void Function(AddBlockResponse) updates) => super.copyWith((message) => updates(message as AddBlockResponse)) as AddBlockResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddBlockResponse create() => AddBlockResponse._();
  AddBlockResponse createEmptyInstance() => create();
  static $pb.PbList<AddBlockResponse> createRepeated() => $pb.PbList<AddBlockResponse>();
  @$core.pragma('dart2js:noInline')
  static AddBlockResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AddBlockResponse>(create);
  static AddBlockResponse? _defaultInstance;

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

/// Response message for retrieving a block
class GetBlockResponse extends $pb.GeneratedMessage {
  factory GetBlockResponse({
    $0.BlockProto? block,
    $core.bool? found,
  }) {
    final result = create();
    if (block != null) {
      result.block = block;
    }
    if (found != null) {
      result.found = found;
    }
    return result;
  }
  GetBlockResponse._() : super();
  factory GetBlockResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetBlockResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetBlockResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOM<$0.BlockProto>(1, _omitFieldNames ? '' : 'block', subBuilder: $0.BlockProto.create)
    ..aOB(2, _omitFieldNames ? '' : 'found')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetBlockResponse clone() => GetBlockResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetBlockResponse copyWith(void Function(GetBlockResponse) updates) => super.copyWith((message) => updates(message as GetBlockResponse)) as GetBlockResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetBlockResponse create() => GetBlockResponse._();
  GetBlockResponse createEmptyInstance() => create();
  static $pb.PbList<GetBlockResponse> createRepeated() => $pb.PbList<GetBlockResponse>();
  @$core.pragma('dart2js:noInline')
  static GetBlockResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetBlockResponse>(create);
  static GetBlockResponse? _defaultInstance;

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

/// Response message for removing a block
class RemoveBlockResponse extends $pb.GeneratedMessage {
  factory RemoveBlockResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final result = create();
    if (success != null) {
      result.success = success;
    }
    if (message != null) {
      result.message = message;
    }
    return result;
  }
  RemoveBlockResponse._() : super();
  factory RemoveBlockResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RemoveBlockResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RemoveBlockResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RemoveBlockResponse clone() => RemoveBlockResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RemoveBlockResponse copyWith(void Function(RemoveBlockResponse) updates) => super.copyWith((message) => updates(message as RemoveBlockResponse)) as RemoveBlockResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveBlockResponse create() => RemoveBlockResponse._();
  RemoveBlockResponse createEmptyInstance() => create();
  static $pb.PbList<RemoveBlockResponse> createRepeated() => $pb.PbList<RemoveBlockResponse>();
  @$core.pragma('dart2js:noInline')
  static RemoveBlockResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RemoveBlockResponse>(create);
  static RemoveBlockResponse? _defaultInstance;

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

class BlockStoreServiceApi {
  $pb.RpcClient _client;
  BlockStoreServiceApi(this._client);

  $async.Future<AddBlockResponse> addBlock($pb.ClientContext? ctx, $0.BlockProto request) =>
    _client.invoke<AddBlockResponse>(ctx, 'BlockStoreService', 'AddBlock', request, AddBlockResponse())
  ;
  $async.Future<GetBlockResponse> getBlock($pb.ClientContext? ctx, $1.CIDProto request) =>
    _client.invoke<GetBlockResponse>(ctx, 'BlockStoreService', 'GetBlock', request, GetBlockResponse())
  ;
  $async.Future<RemoveBlockResponse> removeBlock($pb.ClientContext? ctx, $1.CIDProto request) =>
    _client.invoke<RemoveBlockResponse>(ctx, 'BlockStoreService', 'RemoveBlock', request, RemoveBlockResponse())
  ;
  $async.Future<$0.BlockProto> getAllBlocks($pb.ClientContext? ctx, $2.Empty request) =>
    _client.invoke<$0.BlockProto>(ctx, 'BlockStoreService', 'GetAllBlocks', request, $0.BlockProto())
  ;
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
