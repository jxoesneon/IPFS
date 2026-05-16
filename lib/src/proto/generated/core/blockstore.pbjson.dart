// This is a generated file - do not edit.
//
// Generated from core/blockstore.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

import 'block.pbjson.dart' as $0;
import 'cid.pbjson.dart' as $1;
import 'package:protobuf/well_known_types/google/protobuf/empty.pbjson.dart'
    as $2;

@$core.Deprecated('Use addBlockResponseDescriptor instead')
const AddBlockResponse$json = {
  '1': 'AddBlockResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `AddBlockResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addBlockResponseDescriptor = $convert.base64Decode(
    'ChBBZGRCbG9ja1Jlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbWVzc2FnZR'
    'gCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use getBlockResponseDescriptor instead')
const GetBlockResponse$json = {
  '1': 'GetBlockResponse',
  '2': [
    {
      '1': 'block',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.data_structures.BlockProto',
      '10': 'block'
    },
    {'1': 'found', '3': 2, '4': 1, '5': 8, '10': 'found'},
  ],
};

/// Descriptor for `GetBlockResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getBlockResponseDescriptor = $convert.base64Decode(
    'ChBHZXRCbG9ja1Jlc3BvbnNlEjsKBWJsb2NrGAEgASgLMiUuaXBmcy5jb3JlLmRhdGFfc3RydW'
    'N0dXJlcy5CbG9ja1Byb3RvUgVibG9jaxIUCgVmb3VuZBgCIAEoCFIFZm91bmQ=');

@$core.Deprecated('Use removeBlockResponseDescriptor instead')
const RemoveBlockResponse$json = {
  '1': 'RemoveBlockResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `RemoveBlockResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeBlockResponseDescriptor = $convert.base64Decode(
    'ChNSZW1vdmVCbG9ja1Jlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbWVzc2'
    'FnZRgCIAEoCVIHbWVzc2FnZQ==');

const BlockStoreServiceBase$json = {
  '1': 'BlockStoreService',
  '2': [
    {
      '1': 'AddBlock',
      '2': '.ipfs.core.data_structures.BlockProto',
      '3': '.ipfs.core.data_structures.AddBlockResponse'
    },
    {
      '1': 'GetBlock',
      '2': '.ipfs.core.data_structures.IPFSCIDProto',
      '3': '.ipfs.core.data_structures.GetBlockResponse'
    },
    {
      '1': 'RemoveBlock',
      '2': '.ipfs.core.data_structures.IPFSCIDProto',
      '3': '.ipfs.core.data_structures.RemoveBlockResponse'
    },
    {
      '1': 'GetAllBlocks',
      '2': '.google.protobuf.Empty',
      '3': '.ipfs.core.data_structures.BlockProto'
    },
  ],
};

const BlockStoreServiceBase$messageJson = {
  '.ipfs.core.data_structures.BlockProto': $0.BlockProto$json,
  '.ipfs.core.data_structures.AddBlockResponse': AddBlockResponse$json,
  '.ipfs.core.data_structures.IPFSCIDProto': $1.IPFSCIDProto$json,
  '.ipfs.core.data_structures.GetBlockResponse': GetBlockResponse$json,
  '.ipfs.core.data_structures.RemoveBlockResponse': RemoveBlockResponse$json,
  '.google.protobuf.Empty': $2.Empty$json, // ignore: deprecated_member_use
};
