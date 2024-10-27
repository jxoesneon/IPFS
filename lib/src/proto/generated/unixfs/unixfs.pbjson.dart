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
    {'1': 'Type', '3': 1, '4': 2, '5': 14, '6': '.Data.DataType', '10': 'Type'},
    {'1': 'Data', '3': 2, '4': 1, '5': 12, '10': 'Data'},
    {'1': 'filesize', '3': 3, '4': 1, '5': 4, '10': 'filesize'},
    {'1': 'blocksizes', '3': 4, '4': 3, '5': 4, '10': 'blocksizes'},
    {'1': 'hashType', '3': 5, '4': 1, '5': 4, '10': 'hashType'},
    {'1': 'fanout', '3': 6, '4': 1, '5': 4, '10': 'fanout'},
    {'1': 'mode', '3': 7, '4': 1, '5': 13, '10': 'mode'},
    {'1': 'mtime', '3': 8, '4': 1, '5': 11, '6': '.UnixTime', '10': 'mtime'},
  ],
  '4': [Data_DataType$json],
};

@$core.Deprecated('Use dataDescriptor instead')
const Data_DataType$json = {
  '1': 'DataType',
  '2': [
    {'1': 'Raw', '2': 0},
    {'1': 'Directory', '2': 1},
    {'1': 'File', '2': 2},
    {'1': 'Metadata', '2': 3},
    {'1': 'Symlink', '2': 4},
    {'1': 'HAMTShard', '2': 5},
  ],
};

/// Descriptor for `Data`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dataDescriptor = $convert.base64Decode(
    'CgREYXRhEiIKBFR5cGUYASACKA4yDi5EYXRhLkRhdGFUeXBlUgRUeXBlEhIKBERhdGEYAiABKA'
    'xSBERhdGESGgoIZmlsZXNpemUYAyABKARSCGZpbGVzaXplEh4KCmJsb2Nrc2l6ZXMYBCADKARS'
    'CmJsb2Nrc2l6ZXMSGgoIaGFzaFR5cGUYBSABKARSCGhhc2hUeXBlEhYKBmZhbm91dBgGIAEoBF'
    'IGZmFub3V0EhIKBG1vZGUYByABKA1SBG1vZGUSHwoFbXRpbWUYCCABKAsyCS5Vbml4VGltZVIF'
    'bXRpbWUiVgoIRGF0YVR5cGUSBwoDUmF3EAASDQoJRGlyZWN0b3J5EAESCAoERmlsZRACEgwKCE'
    '1ldGFkYXRhEAMSCwoHU3ltbGluaxAEEg0KCUhBTVRTaGFyZBAF');

@$core.Deprecated('Use metadataDescriptor instead')
const Metadata$json = {
  '1': 'Metadata',
  '2': [
    {'1': 'MimeType', '3': 1, '4': 1, '5': 9, '10': 'MimeType'},
  ],
};

/// Descriptor for `Metadata`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List metadataDescriptor = $convert.base64Decode(
    'CghNZXRhZGF0YRIaCghNaW1lVHlwZRgBIAEoCVIITWltZVR5cGU=');

@$core.Deprecated('Use unixTimeDescriptor instead')
const UnixTime$json = {
  '1': 'UnixTime',
  '2': [
    {'1': 'Seconds', '3': 1, '4': 2, '5': 3, '10': 'Seconds'},
    {'1': 'FractionalNanoseconds', '3': 2, '4': 1, '5': 7, '10': 'FractionalNanoseconds'},
  ],
};

/// Descriptor for `UnixTime`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unixTimeDescriptor = $convert.base64Decode(
    'CghVbml4VGltZRIYCgdTZWNvbmRzGAEgAigDUgdTZWNvbmRzEjQKFUZyYWN0aW9uYWxOYW5vc2'
    'Vjb25kcxgCIAEoB1IVRnJhY3Rpb25hbE5hbm9zZWNvbmRz');

