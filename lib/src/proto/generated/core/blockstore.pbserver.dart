//
//  Generated code. Do not modify.
//  source: core/blockstore.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import '../google/protobuf/empty.pb.dart' as $2;
import 'block.pb.dart' as $1;
import 'blockstore.pb.dart' as $3;
import 'blockstore.pbjson.dart';
import 'cid.pb.dart' as $0;

export 'blockstore.pb.dart';

abstract class BlockStoreServiceBase extends $pb.GeneratedService {
  $async.Future<$3.AddBlockResponse> addBlock($pb.ServerContext ctx, $1.BlockProto request);
  $async.Future<$3.GetBlockResponse> getBlock($pb.ServerContext ctx, $0.CIDProto request);
  $async.Future<$3.RemoveBlockResponse> removeBlock($pb.ServerContext ctx, $0.CIDProto request);
  $async.Future<$1.BlockProto> getAllBlocks($pb.ServerContext ctx, $2.Empty request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'AddBlock': return $1.BlockProto();
      case 'GetBlock': return $0.CIDProto();
      case 'RemoveBlock': return $0.CIDProto();
      case 'GetAllBlocks': return $2.Empty();
      default: throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx, $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'AddBlock': return this.addBlock(ctx, request as $1.BlockProto);
      case 'GetBlock': return this.getBlock(ctx, request as $0.CIDProto);
      case 'RemoveBlock': return this.removeBlock(ctx, request as $0.CIDProto);
      case 'GetAllBlocks': return this.getAllBlocks(ctx, request as $2.Empty);
      default: throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => BlockStoreServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>> get $messageJson => BlockStoreServiceBase$messageJson;
}

