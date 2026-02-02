//
//  Generated code. Do not modify.
//  source: dht/find_closest_peers.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use findClosestPeersRequestDescriptor instead')
const FindClosestPeersRequest$json = {
  '1': 'FindClosestPeersRequest',
  '2': [
    {'1': 'target', '3': 1, '4': 1, '5': 11, '6': '.ipfs.dht.common_kademlia.KademliaId', '10': 'target'},
    {'1': 'count', '3': 2, '4': 1, '5': 5, '10': 'count'},
  ],
};

/// Descriptor for `FindClosestPeersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findClosestPeersRequestDescriptor = $convert.base64Decode(
    'ChdGaW5kQ2xvc2VzdFBlZXJzUmVxdWVzdBI8CgZ0YXJnZXQYASABKAsyJC5pcGZzLmRodC5jb2'
    '1tb25fa2FkZW1saWEuS2FkZW1saWFJZFIGdGFyZ2V0EhQKBWNvdW50GAIgASgFUgVjb3VudA==');

@$core.Deprecated('Use findClosestPeersResponseDescriptor instead')
const FindClosestPeersResponse$json = {
  '1': 'FindClosestPeersResponse',
  '2': [
    {'1': 'peer_ids', '3': 1, '4': 3, '5': 11, '6': '.ipfs.dht.common_kademlia.KademliaId', '10': 'peerIds'},
  ],
};

/// Descriptor for `FindClosestPeersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findClosestPeersResponseDescriptor = $convert.base64Decode(
    'ChhGaW5kQ2xvc2VzdFBlZXJzUmVzcG9uc2USPwoIcGVlcl9pZHMYASADKAsyJC5pcGZzLmRodC'
    '5jb21tb25fa2FkZW1saWEuS2FkZW1saWFJZFIHcGVlcklkcw==');

