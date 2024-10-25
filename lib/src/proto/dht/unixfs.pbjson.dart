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

@$core.Deprecated('Use unixFSTypeProtoDescriptor instead')
const UnixFSTypeProto$json = {
  '1': 'UnixFSTypeProto',
  '2': [
    {'1': 'FILE', '2': 0},
    {'1': 'DIRECTORY', '2': 1},
  ],
};

/// Descriptor for `UnixFSTypeProto`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List unixFSTypeProtoDescriptor = $convert.base64Decode(
    'Cg9Vbml4RlNUeXBlUHJvdG8SCAoERklMRRAAEg0KCURJUkVDVE9SWRAB');

@$core.Deprecated('Use unixFSDescriptor instead')
const UnixFS$json = {
  '1': 'UnixFS',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 14, '6': '.ipfs.core.data_structures.UnixFSTypeProto', '10': 'type'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
    {'1': 'block_size', '3': 3, '4': 1, '5': 3, '10': 'blockSize'},
    {'1': 'file_size', '3': 4, '4': 1, '5': 3, '10': 'fileSize'},
    {'1': 'blocksizes', '3': 5, '4': 3, '5': 5, '10': 'blocksizes'},
  ],
};

/// Descriptor for `UnixFS`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unixFSDescriptor = $convert.base64Decode(
    'CgZVbml4RlMSPgoEdHlwZRgBIAEoDjIqLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuVW5peE'
    'ZTVHlwZVByb3RvUgR0eXBlEhIKBGRhdGEYAiABKAxSBGRhdGESHQoKYmxvY2tfc2l6ZRgDIAEo'
    'A1IJYmxvY2tTaXplEhsKCWZpbGVfc2l6ZRgEIAEoA1IIZmlsZVNpemUSHgoKYmxvY2tzaXplcx'
    'gFIAMoBVIKYmxvY2tzaXplcw==');

