//
//  Generated code. Do not modify.
//  source: blockstore.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use blockStoreProtoDescriptor instead')
const BlockStoreProto$json = {
  '1': 'BlockStoreProto',
  '2': [
    {'1': 'blocks', '3': 1, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.BlockProto', '10': 'blocks'},
  ],
  '3': [BlockStoreProto_AddBlockRequest$json, BlockStoreProto_AddBlockResponse$json, BlockStoreProto_GetBlockRequest$json, BlockStoreProto_GetBlockResponse$json, BlockStoreProto_RemoveBlockRequest$json, BlockStoreProto_RemoveBlockResponse$json],
};

@$core.Deprecated('Use blockStoreProtoDescriptor instead')
const BlockStoreProto_AddBlockRequest$json = {
  '1': 'AddBlockRequest',
  '2': [
    {'1': 'block', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.BlockProto', '10': 'block'},
  ],
};

@$core.Deprecated('Use blockStoreProtoDescriptor instead')
const BlockStoreProto_AddBlockResponse$json = {
  '1': 'AddBlockResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

@$core.Deprecated('Use blockStoreProtoDescriptor instead')
const BlockStoreProto_GetBlockRequest$json = {
  '1': 'GetBlockRequest',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.CID', '10': 'cid'},
  ],
};

@$core.Deprecated('Use blockStoreProtoDescriptor instead')
const BlockStoreProto_GetBlockResponse$json = {
  '1': 'GetBlockResponse',
  '2': [
    {'1': 'block', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.BlockProto', '10': 'block'},
    {'1': 'found', '3': 2, '4': 1, '5': 8, '10': 'found'},
  ],
};

@$core.Deprecated('Use blockStoreProtoDescriptor instead')
const BlockStoreProto_RemoveBlockRequest$json = {
  '1': 'RemoveBlockRequest',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.CID', '10': 'cid'},
  ],
};

@$core.Deprecated('Use blockStoreProtoDescriptor instead')
const BlockStoreProto_RemoveBlockResponse$json = {
  '1': 'RemoveBlockResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `BlockStoreProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockStoreProtoDescriptor = $convert.base64Decode(
    'Cg9CbG9ja1N0b3JlUHJvdG8SPQoGYmxvY2tzGAEgAygLMiUuaXBmcy5jb3JlLmRhdGFfc3RydW'
    'N0dXJlcy5CbG9ja1Byb3RvUgZibG9ja3MaTgoPQWRkQmxvY2tSZXF1ZXN0EjsKBWJsb2NrGAEg'
    'ASgLMiUuaXBmcy5jb3JlLmRhdGFfc3RydWN0dXJlcy5CbG9ja1Byb3RvUgVibG9jaxpGChBBZG'
    'RCbG9ja1Jlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbWVzc2FnZRgCIAEo'
    'CVIHbWVzc2FnZRpDCg9HZXRCbG9ja1JlcXVlc3QSMAoDY2lkGAEgASgLMh4uaXBmcy5jb3JlLm'
    'RhdGFfc3RydWN0dXJlcy5DSURSA2NpZBplChBHZXRCbG9ja1Jlc3BvbnNlEjsKBWJsb2NrGAEg'
    'ASgLMiUuaXBmcy5jb3JlLmRhdGFfc3RydWN0dXJlcy5CbG9ja1Byb3RvUgVibG9jaxIUCgVmb3'
    'VuZBgCIAEoCFIFZm91bmQaRgoSUmVtb3ZlQmxvY2tSZXF1ZXN0EjAKA2NpZBgBIAEoCzIeLmlw'
    'ZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuQ0lEUgNjaWQaSQoTUmVtb3ZlQmxvY2tSZXNwb25zZR'
    'IYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEhgKB21lc3NhZ2UYAiABKAlSB21lc3NhZ2U=');

