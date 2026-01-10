// This is a generated file - do not edit.
//
// Generated from dht/bucket_management.proto.

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

@$core.Deprecated('Use splitBucketRequestDescriptor instead')
const SplitBucketRequest$json = {
  '1': 'SplitBucketRequest',
  '2': [
    {'1': 'bucket_index', '3': 1, '4': 1, '5': 5, '10': 'bucketIndex'},
  ],
};

/// Descriptor for `SplitBucketRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List splitBucketRequestDescriptor = $convert
    .base64Decode('ChJTcGxpdEJ1Y2tldFJlcXVlc3QSIQoMYnVja2V0X2luZGV4GAEgASgFUgtidWNrZXRJbmRleA'
        '==');

@$core.Deprecated('Use splitBucketResponseDescriptor instead')
const SplitBucketResponse$json = {
  '1': 'SplitBucketResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `SplitBucketResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List splitBucketResponseDescriptor =
    $convert.base64Decode('ChNTcGxpdEJ1Y2tldFJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3M=');

@$core.Deprecated('Use mergeBucketsRequestDescriptor instead')
const MergeBucketsRequest$json = {
  '1': 'MergeBucketsRequest',
  '2': [
    {'1': 'bucket_index_1', '3': 1, '4': 1, '5': 5, '10': 'bucketIndex1'},
    {'1': 'bucket_index_2', '3': 2, '4': 1, '5': 5, '10': 'bucketIndex2'},
  ],
};

/// Descriptor for `MergeBucketsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mergeBucketsRequestDescriptor = $convert
    .base64Decode('ChNNZXJnZUJ1Y2tldHNSZXF1ZXN0EiQKDmJ1Y2tldF9pbmRleF8xGAEgASgFUgxidWNrZXRJbm'
        'RleDESJAoOYnVja2V0X2luZGV4XzIYAiABKAVSDGJ1Y2tldEluZGV4Mg==');

@$core.Deprecated('Use mergeBucketsResponseDescriptor instead')
const MergeBucketsResponse$json = {
  '1': 'MergeBucketsResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `MergeBucketsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mergeBucketsResponseDescriptor =
    $convert.base64Decode('ChRNZXJnZUJ1Y2tldHNSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNz');
