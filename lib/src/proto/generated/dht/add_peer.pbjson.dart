//
//  Generated code. Do not modify.
//  source: dht/add_peer.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use addPeerRequestDescriptor instead')
const AddPeerRequest$json = {
  '1': 'AddPeerRequest',
  '2': [
    {
      '1': 'peer_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.common_kademlia.KademliaId',
      '10': 'peerId'
    },
    {
      '1': 'associated_peer_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.common_kademlia.KademliaId',
      '10': 'associatedPeerId'
    },
  ],
};

/// Descriptor for `AddPeerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addPeerRequestDescriptor = $convert.base64Decode(
    'Cg5BZGRQZWVyUmVxdWVzdBI9CgdwZWVyX2lkGAEgASgLMiQuaXBmcy5kaHQuY29tbW9uX2thZG'
    'VtbGlhLkthZGVtbGlhSWRSBnBlZXJJZBJSChJhc3NvY2lhdGVkX3BlZXJfaWQYAiABKAsyJC5p'
    'cGZzLmRodC5jb21tb25fa2FkZW1saWEuS2FkZW1saWFJZFIQYXNzb2NpYXRlZFBlZXJJZA==');

@$core.Deprecated('Use addPeerResponseDescriptor instead')
const AddPeerResponse$json = {
  '1': 'AddPeerResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `AddPeerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addPeerResponseDescriptor = $convert.base64Decode(
    'Cg9BZGRQZWVyUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2Vzcw==');
