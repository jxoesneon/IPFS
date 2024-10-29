//
//  Generated code. Do not modify.
//  source: core/blockstore.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

import '../google/protobuf/empty.pbjson.dart' as $2;
import 'block.pbjson.dart' as $1;
import 'cid.pbjson.dart' as $0;

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
    {'1': 'block', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.BlockProto', '10': 'block'},
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

const $core.Map<$core.String, $core.dynamic> BlockStoreServiceBase$json = {
  '1': 'BlockStoreService',
  '2': [
    {'1': 'AddBlock', '2': '.ipfs.core.data_structures.BlockProto', '3': '.ipfs.core.data_structures.AddBlockResponse'},
    {'1': 'GetBlock', '2': '.ipfs.core.data_structures.CIDProto', '3': '.ipfs.core.data_structures.GetBlockResponse'},
    {'1': 'RemoveBlock', '2': '.ipfs.core.data_structures.CIDProto', '3': '.ipfs.core.data_structures.RemoveBlockResponse'},
    {'1': 'GetAllBlocks', '2': '.google.protobuf.Empty', '3': '.ipfs.core.data_structures.BlockProto', '6': true},
  ],
};

@$core.Deprecated('Use blockStoreServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>> BlockStoreServiceBase$messageJson = {
  '.ipfs.core.data_structures.BlockProto': $1.BlockProto$json,
  '.ipfs.core.data_structures.CIDProto': $0.CIDProto$json,
  '.ipfs.core.data_structures.AddBlockResponse': AddBlockResponse$json,
  '.ipfs.core.data_structures.GetBlockResponse': GetBlockResponse$json,
  '.ipfs.core.data_structures.RemoveBlockResponse': RemoveBlockResponse$json,
  '.google.protobuf.Empty': $2.Empty$json,
};

/// Descriptor for `BlockStoreService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List blockStoreServiceDescriptor = $convert.base64Decode(
    'ChFCbG9ja1N0b3JlU2VydmljZRJeCghBZGRCbG9jaxIlLmlwZnMuY29yZS5kYXRhX3N0cnVjdH'
    'VyZXMuQmxvY2tQcm90bxorLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuQWRkQmxvY2tSZXNw'
    'b25zZRJcCghHZXRCbG9jaxIjLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuQ0lEUHJvdG8aKy'
    '5pcGZzLmNvcmUuZGF0YV9zdHJ1Y3R1cmVzLkdldEJsb2NrUmVzcG9uc2USYgoLUmVtb3ZlQmxv'
    'Y2sSIy5pcGZzLmNvcmUuZGF0YV9zdHJ1Y3R1cmVzLkNJRFByb3RvGi4uaXBmcy5jb3JlLmRhdG'
    'Ffc3RydWN0dXJlcy5SZW1vdmVCbG9ja1Jlc3BvbnNlEk8KDEdldEFsbEJsb2NrcxIWLmdvb2ds'
    'ZS5wcm90b2J1Zi5FbXB0eRolLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuQmxvY2tQcm90bz'
    'AB');

