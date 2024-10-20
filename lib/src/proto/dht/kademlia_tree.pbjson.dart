//
//  Generated code. Do not modify.
//  source: kademlia_tree.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use kademliaNodeDescriptor instead')
const KademliaNode$json = {
  '1': 'KademliaNode',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 11, '6': '.ipfs.dht.common.PeerId', '10': 'peerId'},
    {'1': 'distance', '3': 2, '4': 1, '5': 5, '10': 'distance'},
    {'1': 'children', '3': 3, '4': 1, '5': 11, '6': '.ipfs.dht.red_black_tree.RedBlackTreeNode', '10': 'children'},
  ],
};

/// Descriptor for `KademliaNode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kademliaNodeDescriptor = $convert.base64Decode(
    'CgxLYWRlbWxpYU5vZGUSMAoHcGVlcl9pZBgBIAEoCzIXLmlwZnMuZGh0LmNvbW1vbi5QZWVySW'
    'RSBnBlZXJJZBIaCghkaXN0YW5jZRgCIAEoBVIIZGlzdGFuY2USRQoIY2hpbGRyZW4YAyABKAsy'
    'KS5pcGZzLmRodC5yZWRfYmxhY2tfdHJlZS5SZWRCbGFja1RyZWVOb2RlUghjaGlsZHJlbg==');

@$core.Deprecated('Use kademliaBucketDescriptor instead')
const KademliaBucket$json = {
  '1': 'KademliaBucket',
  '2': [
    {'1': 'tree', '3': 1, '4': 1, '5': 11, '6': '.ipfs.dht.red_black_tree.RedBlackTreeNode', '10': 'tree'},
  ],
};

/// Descriptor for `KademliaBucket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kademliaBucketDescriptor = $convert.base64Decode(
    'Cg5LYWRlbWxpYUJ1Y2tldBI9CgR0cmVlGAEgASgLMikuaXBmcy5kaHQucmVkX2JsYWNrX3RyZW'
    'UuUmVkQmxhY2tUcmVlTm9kZVIEdHJlZQ==');

@$core.Deprecated('Use kademliaTreeDescriptor instead')
const KademliaTree$json = {
  '1': 'KademliaTree',
  '2': [
    {'1': 'local_node', '3': 1, '4': 1, '5': 11, '6': '.ipfs.dht.kademlia_tree.KademliaNode', '10': 'localNode'},
    {'1': 'buckets', '3': 2, '4': 3, '5': 11, '6': '.ipfs.dht.kademlia_tree.KademliaBucket', '10': 'buckets'},
  ],
};

/// Descriptor for `KademliaTree`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kademliaTreeDescriptor = $convert.base64Decode(
    'CgxLYWRlbWxpYVRyZWUSQwoKbG9jYWxfbm9kZRgBIAEoCzIkLmlwZnMuZGh0LmthZGVtbGlhX3'
    'RyZWUuS2FkZW1saWFOb2RlUglsb2NhbE5vZGUSQAoHYnVja2V0cxgCIAMoCzImLmlwZnMuZGh0'
    'LmthZGVtbGlhX3RyZWUuS2FkZW1saWFCdWNrZXRSB2J1Y2tldHM=');

