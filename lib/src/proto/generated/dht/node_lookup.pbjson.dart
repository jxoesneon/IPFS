//
//  Generated code. Do not modify.
//  source: node_lookup.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use nodeLookupRequestDescriptor instead')
const NodeLookupRequest$json = {
  '1': 'NodeLookupRequest',
  '2': [
    {'1': 'target', '3': 1, '4': 1, '5': 11, '6': '.ipfs.dht.common_kademlia.KademliaId', '10': 'target'},
  ],
};

/// Descriptor for `NodeLookupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeLookupRequestDescriptor = $convert.base64Decode(
    'ChFOb2RlTG9va3VwUmVxdWVzdBI8CgZ0YXJnZXQYASABKAsyJC5pcGZzLmRodC5jb21tb25fa2'
    'FkZW1saWEuS2FkZW1saWFJZFIGdGFyZ2V0');

@$core.Deprecated('Use nodeLookupResponseDescriptor instead')
const NodeLookupResponse$json = {
  '1': 'NodeLookupResponse',
  '2': [
    {'1': 'closest_nodes', '3': 1, '4': 3, '5': 11, '6': '.ipfs.dht.common_kademlia.KademliaId', '10': 'closestNodes'},
  ],
};

/// Descriptor for `NodeLookupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeLookupResponseDescriptor = $convert.base64Decode(
    'ChJOb2RlTG9va3VwUmVzcG9uc2USSQoNY2xvc2VzdF9ub2RlcxgBIAMoCzIkLmlwZnMuZGh0Lm'
    'NvbW1vbl9rYWRlbWxpYS5LYWRlbWxpYUlkUgxjbG9zZXN0Tm9kZXM=');

