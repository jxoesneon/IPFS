// This is a generated file - do not edit.
//
// Generated from core/link.proto.

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

@$core.Deprecated('Use linkTypeDescriptor instead')
const LinkType$json = {
  '1': 'LinkType',
  '2': [
    {'1': 'LINK_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'LINK_TYPE_DIRECT', '2': 1},
    {'1': 'LINK_TYPE_HAMT', '2': 2},
    {'1': 'LINK_TYPE_TRICKLE', '2': 3},
  ],
};

/// Descriptor for `LinkType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List linkTypeDescriptor = $convert.base64Decode(
    'CghMaW5rVHlwZRIZChVMSU5LX1RZUEVfVU5TUEVDSUZJRUQQABIUChBMSU5LX1RZUEVfRElSRU'
    'NUEAESEgoOTElOS19UWVBFX0hBTVQQAhIVChFMSU5LX1RZUEVfVFJJQ0tMRRAD');

@$core.Deprecated('Use linkMetadataDescriptor instead')
const LinkMetadata$json = {
  '1': 'LinkMetadata',
  '2': [
    {
      '1': 'link',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.data_structures.PBLink',
      '10': 'link'
    },
    {'1': 'timestamp', '3': 2, '4': 1, '5': 3, '10': 'timestamp'},
    {
      '1': 'metadata',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.ipfs.core.data_structures.LinkMetadata.MetadataEntry',
      '10': 'metadata'
    },
    {
      '1': 'type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.ipfs.core.data_structures.LinkType',
      '10': 'type'
    },
    {'1': 'bucket_index', '3': 5, '4': 1, '5': 5, '10': 'bucketIndex'},
    {'1': 'depth', '3': 6, '4': 1, '5': 5, '10': 'depth'},
  ],
  '3': [LinkMetadata_MetadataEntry$json],
};

@$core.Deprecated('Use linkMetadataDescriptor instead')
const LinkMetadata_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `LinkMetadata`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List linkMetadataDescriptor = $convert.base64Decode(
    'CgxMaW5rTWV0YWRhdGESNQoEbGluaxgBIAEoCzIhLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZX'
    'MuUEJMaW5rUgRsaW5rEhwKCXRpbWVzdGFtcBgCIAEoA1IJdGltZXN0YW1wElEKCG1ldGFkYXRh'
    'GAMgAygLMjUuaXBmcy5jb3JlLmRhdGFfc3RydWN0dXJlcy5MaW5rTWV0YWRhdGEuTWV0YWRhdG'
    'FFbnRyeVIIbWV0YWRhdGESNwoEdHlwZRgEIAEoDjIjLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVy'
    'ZXMuTGlua1R5cGVSBHR5cGUSIQoMYnVja2V0X2luZGV4GAUgASgFUgtidWNrZXRJbmRleBIUCg'
    'VkZXB0aBgGIAEoBVIFZGVwdGgaOwoNTWV0YWRhdGFFbnRyeRIQCgNrZXkYASABKAlSA2tleRIU'
    'CgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');
