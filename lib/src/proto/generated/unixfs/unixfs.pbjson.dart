// This is a generated file - do not edit.
//
// Generated from unixfs/unixfs.proto.

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

@$core.Deprecated('Use dataDescriptor instead')
const Data$json = {
  '1': 'Data',
  '2': [
    {'1': 'Type', '3': 1, '4': 1, '5': 14, '6': '.ipfs.unixfs.pb.Data.DataType', '10': 'Type'},
    {'1': 'Data', '3': 2, '4': 1, '5': 12, '10': 'Data'},
    {'1': 'filesize', '3': 3, '4': 1, '5': 4, '10': 'filesize'},
    {'1': 'blocksizes', '3': 4, '4': 3, '5': 4, '10': 'blocksizes'},
    {'1': 'hashType', '3': 5, '4': 1, '5': 4, '9': 0, '10': 'hashType', '17': true},
    {'1': 'fanout', '3': 6, '4': 1, '5': 4, '9': 1, '10': 'fanout', '17': true},
    {'1': 'mode', '3': 7, '4': 1, '5': 13, '9': 2, '10': 'mode', '17': true},
    {'1': 'mtime', '3': 8, '4': 1, '5': 3, '9': 3, '10': 'mtime', '17': true},
    {'1': 'mtime_nsecs', '3': 9, '4': 1, '5': 13, '9': 4, '10': 'mtimeNsecs', '17': true},
  ],
  '4': [Data_DataType$json],
  '8': [
    {'1': '_hashType'},
    {'1': '_fanout'},
    {'1': '_mode'},
    {'1': '_mtime'},
    {'1': '_mtime_nsecs'},
  ],
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
final $typed_data.Uint8List dataDescriptor = $convert
    .base64Decode('CgREYXRhEjEKBFR5cGUYASABKA4yHS5pcGZzLnVuaXhmcy5wYi5EYXRhLkRhdGFUeXBlUgRUeX'
        'BlEhIKBERhdGEYAiABKAxSBERhdGESGgoIZmlsZXNpemUYAyABKARSCGZpbGVzaXplEh4KCmJs'
        'b2Nrc2l6ZXMYBCADKARSCmJsb2Nrc2l6ZXMSHwoIaGFzaFR5cGUYBSABKARIAFIIaGFzaFR5cG'
        'WIAQESGwoGZmFub3V0GAYgASgESAFSBmZhbm91dIgBARIXCgRtb2RlGAcgASgNSAJSBG1vZGWI'
        'AQESGQoFbXRpbWUYCCABKANIA1IFbXRpbWWIAQESJAoLbXRpbWVfbnNlY3MYCSABKA1IBFIKbX'
        'RpbWVOc2Vjc4gBASJWCghEYXRhVHlwZRIHCgNSYXcQABINCglEaXJlY3RvcnkQARIICgRGaWxl'
        'EAISDAoITWV0YWRhdGEQAxILCgdTeW1saW5rEAQSDQoJSEFNVFNoYXJkEAVCCwoJX2hhc2hUeX'
        'BlQgkKB19mYW5vdXRCBwoFX21vZGVCCAoGX210aW1lQg4KDF9tdGltZV9uc2Vjcw==');

@$core.Deprecated('Use metadataDescriptor instead')
const Metadata$json = {
  '1': 'Metadata',
  '2': [
    {'1': 'MimeType', '3': 1, '4': 1, '5': 9, '10': 'MimeType'},
    {'1': 'Size', '3': 2, '4': 1, '5': 4, '10': 'Size'},
    {
      '1': 'properties',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.ipfs.unixfs.pb.Metadata.PropertiesEntry',
      '10': 'properties'
    },
  ],
  '3': [Metadata_PropertiesEntry$json],
};

@$core.Deprecated('Use metadataDescriptor instead')
const Metadata_PropertiesEntry$json = {
  '1': 'PropertiesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Metadata`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List metadataDescriptor = $convert
    .base64Decode('CghNZXRhZGF0YRIaCghNaW1lVHlwZRgBIAEoCVIITWltZVR5cGUSEgoEU2l6ZRgCIAEoBFIEU2'
        'l6ZRJICgpwcm9wZXJ0aWVzGAMgAygLMiguaXBmcy51bml4ZnMucGIuTWV0YWRhdGEuUHJvcGVy'
        'dGllc0VudHJ5Ugpwcm9wZXJ0aWVzGj0KD1Byb3BlcnRpZXNFbnRyeRIQCgNrZXkYASABKAlSA2'
        'tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');
