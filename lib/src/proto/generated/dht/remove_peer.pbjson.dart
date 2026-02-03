// This is a generated file - do not edit.
//
// Generated from dht/remove_peer.proto.

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

@$core.Deprecated('Use removePeerRequestDescriptor instead')
const RemovePeerRequest$json = {
  '1': 'RemovePeerRequest',
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

/// Descriptor for `RemovePeerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removePeerRequestDescriptor = $convert.base64Decode(
    'ChFSZW1vdmVQZWVyUmVxdWVzdBI9CgdwZWVyX2lkGAEgASgLMiQuaXBmcy5kaHQuY29tbW9uX2'
    'thZGVtbGlhLkthZGVtbGlhSWRSBnBlZXJJZA==');

@$core.Deprecated('Use removePeerResponseDescriptor instead')
const RemovePeerResponse$json = {
  '1': 'RemovePeerResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `RemovePeerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removePeerResponseDescriptor =
    $convert.base64Decode(
        'ChJSZW1vdmVQZWVyUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2Vzcw==');

