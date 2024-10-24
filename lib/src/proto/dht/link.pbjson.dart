//
//  Generated code. Do not modify.
//  source: link.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use linkDescriptor instead')
const Link$json = {
  '1': 'Link',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'cid', '3': 2, '4': 1, '5': 12, '10': 'cid'},
    {'1': 'size', '3': 3, '4': 1, '5': 4, '10': 'size'},
    {'1': 'hash', '3': 4, '4': 1, '5': 12, '10': 'hash'},
    {'1': 'timestamp', '3': 5, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'is_directory', '3': 6, '4': 1, '5': 8, '10': 'isDirectory'},
    {'1': 'metadata', '3': 7, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.Link.MetadataEntry', '10': 'metadata'},
  ],
  '3': [Link_MetadataEntry$json],
};

@$core.Deprecated('Use linkDescriptor instead')
const Link_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Link`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List linkDescriptor = $convert.base64Decode(
    'CgRMaW5rEhIKBG5hbWUYASABKAlSBG5hbWUSEAoDY2lkGAIgASgMUgNjaWQSEgoEc2l6ZRgDIA'
    'EoBFIEc2l6ZRISCgRoYXNoGAQgASgMUgRoYXNoEhwKCXRpbWVzdGFtcBgFIAEoA1IJdGltZXN0'
    'YW1wEiEKDGlzX2RpcmVjdG9yeRgGIAEoCFILaXNEaXJlY3RvcnkSSQoIbWV0YWRhdGEYByADKA'
    'syLS5pcGZzLmNvcmUuZGF0YV9zdHJ1Y3R1cmVzLkxpbmsuTWV0YWRhdGFFbnRyeVIIbWV0YWRh'
    'dGEaOwoNTWV0YWRhdGFFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdm'
    'FsdWU6AjgB');

