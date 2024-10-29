//
//  Generated code. Do not modify.
//  source: dht/kademlia_node.proto
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
    {'1': 'peer_id', '3': 1, '4': 1, '5': 11, '6': '.ipfs.dht.common_kademlia.KademliaId', '10': 'peerId'},
    {'1': 'distance', '3': 2, '4': 1, '5': 5, '10': 'distance'},
    {'1': 'associated_peer_id', '3': 3, '4': 1, '5': 11, '6': '.ipfs.dht.common_kademlia.KademliaId', '10': 'associatedPeerId'},
  ],
};

/// Descriptor for `KademliaNode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kademliaNodeDescriptor = $convert.base64Decode(
    'CgxLYWRlbWxpYU5vZGUSPQoHcGVlcl9pZBgBIAEoCzIkLmlwZnMuZGh0LmNvbW1vbl9rYWRlbW'
    'xpYS5LYWRlbWxpYUlkUgZwZWVySWQSGgoIZGlzdGFuY2UYAiABKAVSCGRpc3RhbmNlElIKEmFz'
    'c29jaWF0ZWRfcGVlcl9pZBgDIAEoCzIkLmlwZnMuZGh0LmNvbW1vbl9rYWRlbWxpYS5LYWRlbW'
    'xpYUlkUhBhc3NvY2lhdGVkUGVlcklk');

