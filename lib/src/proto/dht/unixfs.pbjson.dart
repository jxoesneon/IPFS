//
//  Generated code. Do not modify.
//  source: unixfs.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use dataDescriptor instead')
const Data$json = {
  '1': 'Data',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 14, '6': '.ipfs.unixfs.Data.DataType', '10': 'type'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
    {'1': 'filesize', '3': 3, '4': 1, '5': 4, '10': 'filesize'},
    {'1': 'blocksizes', '3': 4, '4': 3, '5': 4, '10': 'blocksizes'},
    {'1': 'hash_type', '3': 5, '4': 1, '5': 4, '10': 'hashType'},
    {'1': 'fanout', '3': 6, '4': 1, '5': 4, '10': 'fanout'},
    {'1': 'mode', '3': 7, '4': 1, '5': 13, '10': 'mode'},
    {'1': 'mtime', '3': 8, '4': 1, '5': 11, '6': '.ipfs.unixfs.UnixTime', '10': 'mtime'},
  ],
  '4': [Data_DataType$json],
};

@$core.Deprecated('Use dataDescriptor instead')
const Data_DataType$json = {
  '1': 'DataType',
  '2': [
    {'1': 'RAW', '2': 0},
    {'1': 'DIRECTORY', '2': 1},
    {'1': 'FILE', '2': 2},
    {'1': 'METADATA', '2': 3},
    {'1': 'SYMLINK', '2': 4},
    {'1': 'HAMT_SHARD', '2': 5},
  ],
};

/// Descriptor for `Data`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dataDescriptor = $convert.base64Decode(
    'CgREYXRhEi4KBHR5cGUYASABKA4yGi5pcGZzLnVuaXhmcy5EYXRhLkRhdGFUeXBlUgR0eXBlEh'
    'IKBGRhdGEYAiABKAxSBGRhdGESGgoIZmlsZXNpemUYAyABKARSCGZpbGVzaXplEh4KCmJsb2Nr'
    'c2l6ZXMYBCADKARSCmJsb2Nrc2l6ZXMSGwoJaGFzaF90eXBlGAUgASgEUghoYXNoVHlwZRIWCg'
    'ZmYW5vdXQYBiABKARSBmZhbm91dBISCgRtb2RlGAcgASgNUgRtb2RlEisKBW10aW1lGAggASgL'
    'MhUuaXBmcy51bml4ZnMuVW5peFRpbWVSBW10aW1lIlcKCERhdGFUeXBlEgcKA1JBVxAAEg0KCU'
    'RJUkVDVE9SWRABEggKBEZJTEUQAhIMCghNRVRBREFUQRADEgsKB1NZTUxJTksQBBIOCgpIQU1U'
    'X1NIQVJEEAU=');

@$core.Deprecated('Use metadataDescriptor instead')
const Metadata$json = {
  '1': 'Metadata',
  '2': [
    {'1': 'mime_type', '3': 1, '4': 1, '5': 9, '10': 'mimeType'},
  ],
};

/// Descriptor for `Metadata`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List metadataDescriptor = $convert.base64Decode(
    'CghNZXRhZGF0YRIbCgltaW1lX3R5cGUYASABKAlSCG1pbWVUeXBl');

@$core.Deprecated('Use unixTimeDescriptor instead')
const UnixTime$json = {
  '1': 'UnixTime',
  '2': [
    {'1': 'seconds', '3': 1, '4': 1, '5': 3, '10': 'seconds'},
    {'1': 'fractional_nanoseconds', '3': 2, '4': 1, '5': 7, '10': 'fractionalNanoseconds'},
  ],
};

/// Descriptor for `UnixTime`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unixTimeDescriptor = $convert.base64Decode(
    'CghVbml4VGltZRIYCgdzZWNvbmRzGAEgASgDUgdzZWNvbmRzEjUKFmZyYWN0aW9uYWxfbmFub3'
    'NlY29uZHMYAiABKAdSFWZyYWN0aW9uYWxOYW5vc2Vjb25kcw==');

