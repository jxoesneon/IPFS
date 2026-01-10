//
//  Generated code. Do not modify.
//  source: dht/dht.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use dHTPeerDescriptor instead')
const DHTPeer$json = {
  '1': 'DHTPeer',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 12, '10': 'id'},
    {'1': 'addrs', '3': 2, '4': 3, '5': 9, '10': 'addrs'},
  ],
};

/// Descriptor for `DHTPeer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dHTPeerDescriptor = $convert.base64Decode(
    'CgdESFRQZWVyEg4KAmlkGAEgASgMUgJpZBIUCgVhZGRycxgCIAMoCVIFYWRkcnM=');

@$core.Deprecated('Use recordDescriptor instead')
const Record$json = {
  '1': 'Record',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 12, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
    {
      '1': 'publisher',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.DHTPeer',
      '10': 'publisher'
    },
    {'1': 'sequence', '3': 4, '4': 1, '5': 4, '10': 'sequence'},
  ],
};

/// Descriptor for `Record`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordDescriptor = $convert.base64Decode(
    'CgZSZWNvcmQSEAoDa2V5GAEgASgMUgNrZXkSFAoFdmFsdWUYAiABKAxSBXZhbHVlEi8KCXB1Ym'
    'xpc2hlchgDIAEoCzIRLmlwZnMuZGh0LkRIVFBlZXJSCXB1Ymxpc2hlchIaCghzZXF1ZW5jZRgE'
    'IAEoBFIIc2VxdWVuY2U=');

@$core.Deprecated('Use findProvidersRequestDescriptor instead')
const FindProvidersRequest$json = {
  '1': 'FindProvidersRequest',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 12, '10': 'key'},
    {'1': 'count', '3': 2, '4': 1, '5': 5, '10': 'count'},
  ],
};

/// Descriptor for `FindProvidersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findProvidersRequestDescriptor = $convert.base64Decode(
    'ChRGaW5kUHJvdmlkZXJzUmVxdWVzdBIQCgNrZXkYASABKAxSA2tleRIUCgVjb3VudBgCIAEoBV'
    'IFY291bnQ=');

@$core.Deprecated('Use findProvidersResponseDescriptor instead')
const FindProvidersResponse$json = {
  '1': 'FindProvidersResponse',
  '2': [
    {
      '1': 'providers',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.ipfs.dht.DHTPeer',
      '10': 'providers'
    },
    {'1': 'closerPeers', '3': 2, '4': 1, '5': 8, '10': 'closerPeers'},
  ],
};

/// Descriptor for `FindProvidersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findProvidersResponseDescriptor = $convert.base64Decode(
    'ChVGaW5kUHJvdmlkZXJzUmVzcG9uc2USLwoJcHJvdmlkZXJzGAEgAygLMhEuaXBmcy5kaHQuRE'
    'hUUGVlclIJcHJvdmlkZXJzEiAKC2Nsb3NlclBlZXJzGAIgASgIUgtjbG9zZXJQZWVycw==');

@$core.Deprecated('Use provideRequestDescriptor instead')
const ProvideRequest$json = {
  '1': 'ProvideRequest',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 12, '10': 'key'},
    {
      '1': 'provider',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.ipfs.dht.DHTPeer',
      '10': 'provider'
    },
  ],
};

/// Descriptor for `ProvideRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List provideRequestDescriptor = $convert.base64Decode(
    'Cg5Qcm92aWRlUmVxdWVzdBIQCgNrZXkYASABKAxSA2tleRItCghwcm92aWRlchgCIAEoCzIRLm'
    'lwZnMuZGh0LkRIVFBlZXJSCHByb3ZpZGVy');

@$core.Deprecated('Use provideResponseDescriptor instead')
const ProvideResponse$json = {
  '1': 'ProvideResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `ProvideResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List provideResponseDescriptor = $convert.base64Decode(
    'Cg9Qcm92aWRlUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2Vzcw==');

@$core.Deprecated('Use findValueRequestDescriptor instead')
const FindValueRequest$json = {
  '1': 'FindValueRequest',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 12, '10': 'key'},
  ],
};

/// Descriptor for `FindValueRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findValueRequestDescriptor =
    $convert.base64Decode('ChBGaW5kVmFsdWVSZXF1ZXN0EhAKA2tleRgBIAEoDFIDa2V5');

@$core.Deprecated('Use findValueResponseDescriptor instead')
const FindValueResponse$json = {
  '1': 'FindValueResponse',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 12, '10': 'value'},
    {
      '1': 'closerPeers',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.ipfs.dht.DHTPeer',
      '10': 'closerPeers'
    },
  ],
};

/// Descriptor for `FindValueResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findValueResponseDescriptor = $convert.base64Decode(
    'ChFGaW5kVmFsdWVSZXNwb25zZRIUCgV2YWx1ZRgBIAEoDFIFdmFsdWUSMwoLY2xvc2VyUGVlcn'
    'MYAiADKAsyES5pcGZzLmRodC5ESFRQZWVyUgtjbG9zZXJQZWVycw==');

@$core.Deprecated('Use putValueRequestDescriptor instead')
const PutValueRequest$json = {
  '1': 'PutValueRequest',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 12, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
  ],
};

/// Descriptor for `PutValueRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List putValueRequestDescriptor = $convert.base64Decode(
    'Cg9QdXRWYWx1ZVJlcXVlc3QSEAoDa2V5GAEgASgMUgNrZXkSFAoFdmFsdWUYAiABKAxSBXZhbH'
    'Vl');

@$core.Deprecated('Use putValueResponseDescriptor instead')
const PutValueResponse$json = {
  '1': 'PutValueResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `PutValueResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List putValueResponseDescriptor = $convert.base64Decode(
    'ChBQdXRWYWx1ZVJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3M=');

@$core.Deprecated('Use findNodeRequestDescriptor instead')
const FindNodeRequest$json = {
  '1': 'FindNodeRequest',
  '2': [
    {'1': 'peerId', '3': 1, '4': 1, '5': 12, '10': 'peerId'},
  ],
};

/// Descriptor for `FindNodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findNodeRequestDescriptor = $convert
    .base64Decode('Cg9GaW5kTm9kZVJlcXVlc3QSFgoGcGVlcklkGAEgASgMUgZwZWVySWQ=');

@$core.Deprecated('Use findNodeResponseDescriptor instead')
const FindNodeResponse$json = {
  '1': 'FindNodeResponse',
  '2': [
    {
      '1': 'closerPeers',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.ipfs.dht.DHTPeer',
      '10': 'closerPeers'
    },
  ],
};

/// Descriptor for `FindNodeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findNodeResponseDescriptor = $convert.base64Decode(
    'ChBGaW5kTm9kZVJlc3BvbnNlEjMKC2Nsb3NlclBlZXJzGAEgAygLMhEuaXBmcy5kaHQuREhUUG'
    'VlclILY2xvc2VyUGVlcnM=');
