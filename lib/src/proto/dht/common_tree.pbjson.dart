//
//  Generated code. Do not modify.
//  source: common_tree.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use nodeColorDescriptor instead')
const NodeColor$json = {
  '1': 'NodeColor',
  '2': [
    {'1': 'RED', '2': 0},
    {'1': 'BLACK', '2': 1},
  ],
};

/// Descriptor for `NodeColor`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List nodeColorDescriptor = $convert.base64Decode(
    'CglOb2RlQ29sb3ISBwoDUkVEEAASCQoFQkxBQ0sQAQ==');

@$core.Deprecated('Use peerIdDescriptor instead')
const PeerId$json = {
  '1': 'PeerId',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `PeerId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerIdDescriptor = $convert.base64Decode(
    'CgZQZWVySWQSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use nodeDescriptor instead')
const Node$json = {
  '1': 'Node',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 11, '6': '.ipfs.dht.common.PeerId', '10': 'peerId'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `Node`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeDescriptor = $convert.base64Decode(
    'CgROb2RlEjAKB3BlZXJfaWQYASABKAsyFy5pcGZzLmRodC5jb21tb24uUGVlcklkUgZwZWVySW'
    'QSEgoEZGF0YRgCIAEoDFIEZGF0YQ==');

