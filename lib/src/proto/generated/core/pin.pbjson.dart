//
//  Generated code. Do not modify.
//  source: core/pin.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use pinTypeProtoDescriptor instead')
const PinTypeProto$json = {
  '1': 'PinTypeProto',
  '2': [
    {'1': 'DIRECT', '2': 0},
    {'1': 'RECURSIVE', '2': 1},
  ],
};

/// Descriptor for `PinTypeProto`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List pinTypeProtoDescriptor = $convert.base64Decode(
    'CgxQaW5UeXBlUHJvdG8SCgoGRElSRUNUEAASDQoJUkVDVVJTSVZFEAE=');

@$core.Deprecated('Use pinDescriptor instead')
const Pin$json = {
  '1': 'Pin',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.CIDProto', '10': 'cid'},
    {'1': 'type', '3': 2, '4': 1, '5': 14, '6': '.ipfs.core.data_structures.PinTypeProto', '10': 'type'},
    {'1': 'timestamp', '3': 3, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `Pin`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pinDescriptor = $convert.base64Decode(
    'CgNQaW4SNQoDY2lkGAEgASgLMiMuaXBmcy5jb3JlLmRhdGFfc3RydWN0dXJlcy5DSURQcm90b1'
    'IDY2lkEjsKBHR5cGUYAiABKA4yJy5pcGZzLmNvcmUuZGF0YV9zdHJ1Y3R1cmVzLlBpblR5cGVQ'
    'cm90b1IEdHlwZRIcCgl0aW1lc3RhbXAYAyABKANSCXRpbWVzdGFtcA==');

