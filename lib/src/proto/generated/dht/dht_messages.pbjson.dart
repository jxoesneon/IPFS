// This is a generated file - do not edit.
//
// Generated from dht/dht_messages.proto.

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

@$core.Deprecated('Use pingRequestDescriptor instead')
const PingRequest$json = {
  '1': 'PingRequest',
  '2': [
    {
      '1': 'peer_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.common_kademlia.KademliaId',
      '10': 'peerId'
    },
  ],
};

/// Descriptor for `PingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingRequestDescriptor = $convert.base64Decode(
    'CgtQaW5nUmVxdWVzdBI9CgdwZWVyX2lkGAEgASgLMiQuaXBmcy5kaHQuY29tbW9uX2thZGVtbG'
    'lhLkthZGVtbGlhSWRSBnBlZXJJZA==');

@$core.Deprecated('Use pingResponseDescriptor instead')
const PingResponse$json = {
  '1': 'PingResponse',
  '2': [
    {
      '1': 'peer_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.common_kademlia.KademliaId',
      '10': 'peerId'
    },
    {'1': 'success', '3': 2, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `PingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingResponseDescriptor = $convert.base64Decode(
    'CgxQaW5nUmVzcG9uc2USPQoHcGVlcl9pZBgBIAEoCzIkLmlwZnMuZGh0LmNvbW1vbl9rYWRlbW'
    'xpYS5LYWRlbWxpYUlkUgZwZWVySWQSGAoHc3VjY2VzcxgCIAEoCFIHc3VjY2Vzcw==');
