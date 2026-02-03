// This is a generated file - do not edit.
//
// Generated from dht/helpers.proto.

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

@$core.Deprecated('Use calculateDistanceRequestDescriptor instead')
const CalculateDistanceRequest$json = {
  '1': 'CalculateDistanceRequest',
  '2': [
    {
      '1': 'id1',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.common_kademlia.KademliaId',
      '10': 'id1'
    },
    {
      '1': 'id2',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.common_kademlia.KademliaId',
      '10': 'id2'
    },
  ],
};

/// Descriptor for `CalculateDistanceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List calculateDistanceRequestDescriptor = $convert.base64Decode(
    'ChhDYWxjdWxhdGVEaXN0YW5jZVJlcXVlc3QSNgoDaWQxGAEgASgLMiQuaXBmcy5kaHQuY29tbW'
    '9uX2thZGVtbGlhLkthZGVtbGlhSWRSA2lkMRI2CgNpZDIYAiABKAsyJC5pcGZzLmRodC5jb21t'
    'b25fa2FkZW1saWEuS2FkZW1saWFJZFIDaWQy');

@$core.Deprecated('Use calculateDistanceResponseDescriptor instead')
const CalculateDistanceResponse$json = {
  '1': 'CalculateDistanceResponse',
  '2': [
    {'1': 'distance', '3': 1, '4': 1, '5': 3, '10': 'distance'},
  ],
};

/// Descriptor for `CalculateDistanceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List calculateDistanceResponseDescriptor =
    $convert.base64Decode(
        'ChlDYWxjdWxhdGVEaXN0YW5jZVJlc3BvbnNlEhoKCGRpc3RhbmNlGAEgASgDUghkaXN0YW5jZQ'
        '==');

