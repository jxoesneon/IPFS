//
//  Generated code. Do not modify.
//  source: core/node.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use nodeProtoDescriptor instead')
const NodeProto$json = {
  '1': 'NodeProto',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.IPFSCIDProto', '10': 'cid'},
    {'1': 'links', '3': 2, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.PBLink', '10': 'links'},
    {'1': 'data', '3': 3, '4': 1, '5': 12, '10': 'data'},
    {'1': 'type', '3': 4, '4': 1, '5': 14, '6': '.ipfs.core.data_structures.NodeTypeProto', '10': 'type'},
    {'1': 'size', '3': 5, '4': 1, '5': 4, '10': 'size'},
    {'1': 'timestamp', '3': 6, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'metadata', '3': 7, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.NodeProto.MetadataEntry', '10': 'metadata'},
  ],
  '3': [NodeProto_MetadataEntry$json],
};

@$core.Deprecated('Use nodeProtoDescriptor instead')
const NodeProto_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `NodeProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeProtoDescriptor = $convert.base64Decode(
    'CglOb2RlUHJvdG8SKQoDY2lkGAEgASgLMhcuaXBmcy5jb3JlLklQRlNDSURQcm90b1IDY2lkEj'
    'cKBWxpbmtzGAIgAygLMiEuaXBmcy5jb3JlLmRhdGFfc3RydWN0dXJlcy5QQkxpbmtSBWxpbmtz'
    'EhIKBGRhdGEYAyABKAxSBGRhdGESPAoEdHlwZRgEIAEoDjIoLmlwZnMuY29yZS5kYXRhX3N0cn'
    'VjdHVyZXMuTm9kZVR5cGVQcm90b1IEdHlwZRISCgRzaXplGAUgASgEUgRzaXplEhwKCXRpbWVz'
    'dGFtcBgGIAEoA1IJdGltZXN0YW1wEk4KCG1ldGFkYXRhGAcgAygLMjIuaXBmcy5jb3JlLmRhdG'
    'Ffc3RydWN0dXJlcy5Ob2RlUHJvdG8uTWV0YWRhdGFFbnRyeVIIbWV0YWRhdGEaOwoNTWV0YWRh'
    'dGFFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

