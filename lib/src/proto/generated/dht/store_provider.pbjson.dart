//
//  Generated code. Do not modify.
//  source: dht/store_provider.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use storeProviderRequestDescriptor instead')
const StoreProviderRequest$json = {
  '1': 'StoreProviderRequest',
  '2': [
    {
      '1': 'key',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.common_red_black_tree.K_PeerId',
      '10': 'key'
    },
    {
      '1': 'provider_info',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.common_red_black_tree.V_PeerInfo',
      '10': 'providerInfo'
    },
    {'1': 'ttl', '3': 3, '4': 1, '5': 3, '10': 'ttl'},
  ],
};

/// Descriptor for `StoreProviderRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List storeProviderRequestDescriptor = $convert.base64Decode(
    'ChRTdG9yZVByb3ZpZGVyUmVxdWVzdBI6CgNrZXkYASABKAsyKC5pcGZzLmRodC5jb21tb25fcm'
    'VkX2JsYWNrX3RyZWUuS19QZWVySWRSA2tleRJPCg1wcm92aWRlcl9pbmZvGAIgASgLMiouaXBm'
    'cy5kaHQuY29tbW9uX3JlZF9ibGFja190cmVlLlZfUGVlckluZm9SDHByb3ZpZGVySW5mbxIQCg'
    'N0dGwYAyABKANSA3R0bA==');

@$core.Deprecated('Use storeProviderResponseDescriptor instead')
const StoreProviderResponse$json = {
  '1': 'StoreProviderResponse',
  '2': [
    {
      '1': 'status',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.ipfs.dht.store_provider.StoreProviderResponse.Status',
      '10': 'status'
    },
    {'1': 'error_message', '3': 2, '4': 1, '5': 9, '10': 'errorMessage'},
    {
      '1': 'replication_count',
      '3': 3,
      '4': 1,
      '5': 5,
      '10': 'replicationCount'
    },
  ],
  '4': [StoreProviderResponse_Status$json],
};

@$core.Deprecated('Use storeProviderResponseDescriptor instead')
const StoreProviderResponse_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'SUCCESS', '2': 0},
    {'1': 'ERROR', '2': 1},
    {'1': 'CAPACITY_EXCEEDED', '2': 2},
  ],
};

/// Descriptor for `StoreProviderResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List storeProviderResponseDescriptor = $convert.base64Decode(
    'ChVTdG9yZVByb3ZpZGVyUmVzcG9uc2USTQoGc3RhdHVzGAEgASgOMjUuaXBmcy5kaHQuc3Rvcm'
    'VfcHJvdmlkZXIuU3RvcmVQcm92aWRlclJlc3BvbnNlLlN0YXR1c1IGc3RhdHVzEiMKDWVycm9y'
    'X21lc3NhZ2UYAiABKAlSDGVycm9yTWVzc2FnZRIrChFyZXBsaWNhdGlvbl9jb3VudBgDIAEoBV'
    'IQcmVwbGljYXRpb25Db3VudCI3CgZTdGF0dXMSCwoHU1VDQ0VTUxAAEgkKBUVSUk9SEAESFQoR'
    'Q0FQQUNJVFlfRVhDRUVERUQQAg==');

@$core.Deprecated('Use getProvidersRequestDescriptor instead')
const GetProvidersRequest$json = {
  '1': 'GetProvidersRequest',
  '2': [
    {
      '1': 'key',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.common_red_black_tree.K_PeerId',
      '10': 'key'
    },
    {'1': 'max_providers', '3': 2, '4': 1, '5': 5, '10': 'maxProviders'},
  ],
};

/// Descriptor for `GetProvidersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProvidersRequestDescriptor = $convert.base64Decode(
    'ChNHZXRQcm92aWRlcnNSZXF1ZXN0EjoKA2tleRgBIAEoCzIoLmlwZnMuZGh0LmNvbW1vbl9yZW'
    'RfYmxhY2tfdHJlZS5LX1BlZXJJZFIDa2V5EiMKDW1heF9wcm92aWRlcnMYAiABKAVSDG1heFBy'
    'b3ZpZGVycw==');

@$core.Deprecated('Use getProvidersResponseDescriptor instead')
const GetProvidersResponse$json = {
  '1': 'GetProvidersResponse',
  '2': [
    {
      '1': 'providers',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.ipfs.dht.common_red_black_tree.V_PeerInfo',
      '10': 'providers'
    },
    {
      '1': 'closest_peers',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.ipfs.dht.common_red_black_tree.V_PeerInfo',
      '10': 'closestPeers'
    },
  ],
};

/// Descriptor for `GetProvidersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProvidersResponseDescriptor = $convert.base64Decode(
    'ChRHZXRQcm92aWRlcnNSZXNwb25zZRJICglwcm92aWRlcnMYASADKAsyKi5pcGZzLmRodC5jb2'
    '1tb25fcmVkX2JsYWNrX3RyZWUuVl9QZWVySW5mb1IJcHJvdmlkZXJzEk8KDWNsb3Nlc3RfcGVl'
    'cnMYAiADKAsyKi5pcGZzLmRodC5jb21tb25fcmVkX2JsYWNrX3RyZWUuVl9QZWVySW5mb1IMY2'
    'xvc2VzdFBlZXJz');
