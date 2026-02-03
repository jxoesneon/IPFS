// This is a generated file - do not edit.
//
// Generated from dht/kademlia_node.proto.

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

@$core.Deprecated('Use kademliaNodeDescriptor instead')
const KademliaNode$json = {
  '1': 'KademliaNode',
  '2': [
    {
      '1': 'peer_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.common_kademlia.KademliaId',
      '10': 'peerId'
    },
    {'1': 'distance', '3': 2, '4': 1, '5': 5, '10': 'distance'},
    {
      '1': 'associated_peer_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.common_kademlia.KademliaId',
      '10': 'associatedPeerId'
    },
    {
      '1': 'children',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.ipfs.dht.kademlia_node.KademliaNode',
      '10': 'children'
    },
    {'1': 'last_seen', '3': 5, '4': 1, '5': 3, '10': 'lastSeen'},
  ],
};

/// Descriptor for `KademliaNode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kademliaNodeDescriptor = $convert.base64Decode(
    'CgxLYWRlbWxpYU5vZGUSPQoHcGVlcl9pZBgBIAEoCzIkLmlwZnMuZGh0LmNvbW1vbl9rYWRlbW'
    'xpYS5LYWRlbWxpYUlkUgZwZWVySWQSGgoIZGlzdGFuY2UYAiABKAVSCGRpc3RhbmNlElIKEmFz'
    'c29jaWF0ZWRfcGVlcl9pZBgDIAEoCzIkLmlwZnMuZGh0LmNvbW1vbl9rYWRlbWxpYS5LYWRlbW'
    'xpYUlkUhBhc3NvY2lhdGVkUGVlcklkEkAKCGNoaWxkcmVuGAQgAygLMiQuaXBmcy5kaHQua2Fk'
    'ZW1saWFfbm9kZS5LYWRlbWxpYU5vZGVSCGNoaWxkcmVuEhsKCWxhc3Rfc2VlbhgFIAEoA1IIbG'
    'FzdFNlZW4=');

