// This is a generated file - do not edit.
//
// Generated from dht/kademlia_tree.proto.

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

@$core.Deprecated('Use kademliaTreeDescriptor instead')
const KademliaTree$json = {
  '1': 'KademliaTree',
  '2': [
    {
      '1': 'local_node',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.kademlia_node.KademliaNode',
      '10': 'localNode'
    },
    {
      '1': 'buckets',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.ipfs.dht.kademlia_tree.KademliaBucket',
      '10': 'buckets'
    },
  ],
};

/// Descriptor for `KademliaTree`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kademliaTreeDescriptor = $convert.base64Decode(
    'CgxLYWRlbWxpYVRyZWUSQwoKbG9jYWxfbm9kZRgBIAEoCzIkLmlwZnMuZGh0LmthZGVtbGlhX2'
    '5vZGUuS2FkZW1saWFOb2RlUglsb2NhbE5vZGUSQAoHYnVja2V0cxgCIAMoCzImLmlwZnMuZGh0'
    'LmthZGVtbGlhX3RyZWUuS2FkZW1saWFCdWNrZXRSB2J1Y2tldHM=');

@$core.Deprecated('Use kademliaBucketDescriptor instead')
const KademliaBucket$json = {
  '1': 'KademliaBucket',
  '2': [
    {
      '1': 'nodes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.ipfs.dht.kademlia_node.KademliaNode',
      '10': 'nodes'
    },
  ],
};

/// Descriptor for `KademliaBucket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kademliaBucketDescriptor = $convert.base64Decode(
    'Cg5LYWRlbWxpYUJ1Y2tldBI6CgVub2RlcxgBIAMoCzIkLmlwZnMuZGh0LmthZGVtbGlhX25vZG'
    'UuS2FkZW1saWFOb2RlUgVub2Rlcw==');

