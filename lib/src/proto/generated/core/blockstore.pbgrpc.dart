// This is a generated file - do not edit.
//
// Generated from core/blockstore.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $3;

import 'block.pb.dart' as $0;
import 'blockstore.pb.dart' as $1;
import 'cid.pb.dart' as $2;

export 'blockstore.pb.dart';

/// The BlockStore service definition
@$pb.GrpcServiceName('ipfs.core.data_structures.BlockStoreService')
class BlockStoreServiceClient extends $grpc.Client {

  BlockStoreServiceClient(super.channel, {super.options, super.interceptors});
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  $grpc.ResponseFuture<$1.AddBlockResponse> addBlock(
    $0.BlockProto request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$addBlock, request, options: options);
  }

  $grpc.ResponseFuture<$1.GetBlockResponse> getBlock(
    $2.IPFSCIDProto request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getBlock, request, options: options);
  }

  $grpc.ResponseFuture<$1.RemoveBlockResponse> removeBlock(
    $2.IPFSCIDProto request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$removeBlock, request, options: options);
  }

  $grpc.ResponseStream<$0.BlockProto> getAllBlocks(
    $3.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$getAllBlocks, $async.Stream.fromIterable([request]),
        options: options);
  }

  // method descriptors

  static final _$addBlock =
      $grpc.ClientMethod<$0.BlockProto, $1.AddBlockResponse>(
          '/ipfs.core.data_structures.BlockStoreService/AddBlock',
          ($0.BlockProto value) => value.writeToBuffer(),
          $1.AddBlockResponse.fromBuffer);
  static final _$getBlock =
      $grpc.ClientMethod<$2.IPFSCIDProto, $1.GetBlockResponse>(
          '/ipfs.core.data_structures.BlockStoreService/GetBlock',
          ($2.IPFSCIDProto value) => value.writeToBuffer(),
          $1.GetBlockResponse.fromBuffer);
  static final _$removeBlock =
      $grpc.ClientMethod<$2.IPFSCIDProto, $1.RemoveBlockResponse>(
          '/ipfs.core.data_structures.BlockStoreService/RemoveBlock',
          ($2.IPFSCIDProto value) => value.writeToBuffer(),
          $1.RemoveBlockResponse.fromBuffer);
  static final _$getAllBlocks = $grpc.ClientMethod<$3.Empty, $0.BlockProto>(
      '/ipfs.core.data_structures.BlockStoreService/GetAllBlocks',
      ($3.Empty value) => value.writeToBuffer(),
      $0.BlockProto.fromBuffer);
}

@$pb.GrpcServiceName('ipfs.core.data_structures.BlockStoreService')
abstract class BlockStoreServiceBase extends $grpc.Service {

  BlockStoreServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.BlockProto, $1.AddBlockResponse>(
        'AddBlock',
        addBlock_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.BlockProto.fromBuffer(value),
        ($1.AddBlockResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.IPFSCIDProto, $1.GetBlockResponse>(
        'GetBlock',
        getBlock_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.IPFSCIDProto.fromBuffer(value),
        ($1.GetBlockResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.IPFSCIDProto, $1.RemoveBlockResponse>(
        'RemoveBlock',
        removeBlock_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.IPFSCIDProto.fromBuffer(value),
        ($1.RemoveBlockResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$3.Empty, $0.BlockProto>(
        'GetAllBlocks',
        getAllBlocks_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $3.Empty.fromBuffer(value),
        ($0.BlockProto value) => value.writeToBuffer()));
  }
  $core.String get $name => 'ipfs.core.data_structures.BlockStoreService';

  $async.Future<$1.AddBlockResponse> addBlock_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.BlockProto> $request) async {
    return addBlock($call, await $request);
  }

  $async.Future<$1.AddBlockResponse> addBlock(
      $grpc.ServiceCall call, $0.BlockProto request);

  $async.Future<$1.GetBlockResponse> getBlock_Pre(
      $grpc.ServiceCall $call, $async.Future<$2.IPFSCIDProto> $request) async {
    return getBlock($call, await $request);
  }

  $async.Future<$1.GetBlockResponse> getBlock(
      $grpc.ServiceCall call, $2.IPFSCIDProto request);

  $async.Future<$1.RemoveBlockResponse> removeBlock_Pre(
      $grpc.ServiceCall $call, $async.Future<$2.IPFSCIDProto> $request) async {
    return removeBlock($call, await $request);
  }

  $async.Future<$1.RemoveBlockResponse> removeBlock(
      $grpc.ServiceCall call, $2.IPFSCIDProto request);

  $async.Stream<$0.BlockProto> getAllBlocks_Pre(
      $grpc.ServiceCall $call, $async.Future<$3.Empty> $request) async* {
    yield* getAllBlocks($call, await $request);
  }

  $async.Stream<$0.BlockProto> getAllBlocks(
      $grpc.ServiceCall call, $3.Empty request);
}
