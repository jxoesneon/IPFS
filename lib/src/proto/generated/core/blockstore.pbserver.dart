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

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $2;

import 'block.pb.dart' as $0;
import 'blockstore.pb.dart' as $3;
import 'blockstore.pbjson.dart';
import 'cid.pb.dart' as $1;

export 'blockstore.pb.dart';

abstract class BlockStoreServiceBase extends $pb.GeneratedService {
  $async.Future<$3.AddBlockResponse> addBlock(
      $pb.ServerContext ctx, $0.BlockProto request);
  $async.Future<$3.GetBlockResponse> getBlock(
      $pb.ServerContext ctx, $1.IPFSCIDProto request);
  $async.Future<$3.RemoveBlockResponse> removeBlock(
      $pb.ServerContext ctx, $1.IPFSCIDProto request);
  $async.Future<$0.BlockProto> getAllBlocks(
      $pb.ServerContext ctx, $2.Empty request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'AddBlock':
        return $0.BlockProto();
      case 'GetBlock':
        return $1.IPFSCIDProto();
      case 'RemoveBlock':
        return $1.IPFSCIDProto();
      case 'GetAllBlocks':
        return $2.Empty();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'AddBlock':
        return addBlock(ctx, request as $0.BlockProto);
      case 'GetBlock':
        return getBlock(ctx, request as $1.IPFSCIDProto);
      case 'RemoveBlock':
        return removeBlock(ctx, request as $1.IPFSCIDProto);
      case 'GetAllBlocks':
        return getAllBlocks(ctx, request as $2.Empty);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json =>
      BlockStoreServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => BlockStoreServiceBase$messageJson;
}

