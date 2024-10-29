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

@$core.Deprecated('Use pBLinkDescriptor instead')
const PBLink$json = {
  '1': 'PBLink',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'cid', '3': 2, '4': 1, '5': 12, '10': 'cid'},
    {'1': 'size', '3': 3, '4': 1, '5': 4, '10': 'size'},
    {'1': 'hash', '3': 4, '4': 1, '5': 12, '10': 'hash'},
    {'1': 'timestamp', '3': 5, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'is_directory', '3': 6, '4': 1, '5': 8, '10': 'isDirectory'},
    {'1': 'metadata', '3': 7, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.PBLink.MetadataEntry', '10': 'metadata'},
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
    'CgZQQkxpbmsSEgoEbmFtZRgBIAEoCVIEbmFtZRIQCgNjaWQYAiABKAxSA2NpZBISCgRzaXplGA'
    'MgASgEUgRzaXplEhIKBGhhc2gYBCABKAxSBGhhc2gSHAoJdGltZXN0YW1wGAUgASgDUgl0aW1l'
    'c3RhbXASIQoMaXNfZGlyZWN0b3J5GAYgASgIUgtpc0RpcmVjdG9yeRJLCghtZXRhZGF0YRgHIA'
    'MoCzIvLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuUEJMaW5rLk1ldGFkYXRhRW50cnlSCG1l'
    'dGFkYXRhGjsKDU1ldGFkYXRhRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKA'
    'lSBXZhbHVlOgI4AQ==');

