//
//  Generated code. Do not modify.
//  source: core/link.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

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

@$core.Deprecated('Use pBLinkDescriptor instead')
const PBLink$json = {
  '1': 'PBLink',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'cid', '3': 2, '4': 1, '5': 12, '10': 'cid'},
    {'1': 'hash', '3': 3, '4': 1, '5': 12, '10': 'hash'},
    {'1': 'size', '3': 4, '4': 1, '5': 4, '10': 'size'},
    {'1': 'timestamp', '3': 5, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'is_directory', '3': 6, '4': 1, '5': 8, '10': 'isDirectory'},
    {'1': 'metadata', '3': 7, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.PBLink.MetadataEntry', '10': 'metadata'},
    {'1': 'type', '3': 8, '4': 1, '5': 14, '6': '.ipfs.core.data_structures.LinkType', '10': 'type'},
    {'1': 'bucket_index', '3': 9, '4': 1, '5': 5, '10': 'bucketIndex'},
    {'1': 'depth', '3': 10, '4': 1, '5': 5, '10': 'depth'},
  ],
  '3': [PBLink_MetadataEntry$json],
};

@$core.Deprecated('Use pBLinkDescriptor instead')
const PBLink_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `PBLink`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pBLinkDescriptor = $convert.base64Decode(
    'CgZQQkxpbmsSEgoEbmFtZRgBIAEoCVIEbmFtZRIQCgNjaWQYAiABKAxSA2NpZBISCgRoYXNoGA'
    'MgASgMUgRoYXNoEhIKBHNpemUYBCABKARSBHNpemUSHAoJdGltZXN0YW1wGAUgASgDUgl0aW1l'
    'c3RhbXASIQoMaXNfZGlyZWN0b3J5GAYgASgIUgtpc0RpcmVjdG9yeRJLCghtZXRhZGF0YRgHIA'
    'MoCzIvLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuUEJMaW5rLk1ldGFkYXRhRW50cnlSCG1l'
    'dGFkYXRhEjcKBHR5cGUYCCABKA4yIy5pcGZzLmNvcmUuZGF0YV9zdHJ1Y3R1cmVzLkxpbmtUeX'
    'BlUgR0eXBlEiEKDGJ1Y2tldF9pbmRleBgJIAEoBVILYnVja2V0SW5kZXgSFAoFZGVwdGgYCiAB'
    'KAVSBWRlcHRoGjsKDU1ldGFkYXRhRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAi'
    'ABKAlSBXZhbHVlOgI4AQ==');

