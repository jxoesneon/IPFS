//
//  Generated code. Do not modify.
//  source: dht/helpers.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

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
