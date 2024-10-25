//
//  Generated code. Do not modify.
//  source: merkle_dag_node.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use merkleDAGNodeDescriptor instead')
const MerkleDAGNode$json = {
  '1': 'MerkleDAGNode',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.CID', '10': 'cid'},
    {'1': 'links', '3': 2, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.PBLink', '10': 'links'},
    {'1': 'data', '3': 3, '4': 1, '5': 12, '10': 'data'},
    {'1': 'size', '3': 4, '4': 1, '5': 4, '10': 'size'},
    {'1': 'timestamp', '3': 5, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'metadata', '3': 6, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.MerkleDAGNode.MetadataEntry', '10': 'metadata'},
    {'1': 'is_directory', '3': 7, '4': 1, '5': 8, '10': 'isDirectory'},
    {'1': 'parent_cid', '3': 8, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.CID', '10': 'parentCid'},
  ],
  '3': [MerkleDAGNode_MetadataEntry$json],
};

@$core.Deprecated('Use merkleDAGNodeDescriptor instead')
const MerkleDAGNode_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `MerkleDAGNode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List merkleDAGNodeDescriptor = $convert.base64Decode(
    'Cg1NZXJrbGVEQUdOb2RlEjAKA2NpZBgBIAEoCzIeLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZX'
    'MuQ0lEUgNjaWQSNwoFbGlua3MYAiADKAsyIS5pcGZzLmNvcmUuZGF0YV9zdHJ1Y3R1cmVzLlBC'
    'TGlua1IFbGlua3MSEgoEZGF0YRgDIAEoDFIEZGF0YRISCgRzaXplGAQgASgEUgRzaXplEhwKCX'
    'RpbWVzdGFtcBgFIAEoA1IJdGltZXN0YW1wElIKCG1ldGFkYXRhGAYgAygLMjYuaXBmcy5jb3Jl'
    'LmRhdGFfc3RydWN0dXJlcy5NZXJrbGVEQUdOb2RlLk1ldGFkYXRhRW50cnlSCG1ldGFkYXRhEi'
    'EKDGlzX2RpcmVjdG9yeRgHIAEoCFILaXNEaXJlY3RvcnkSPQoKcGFyZW50X2NpZBgIIAEoCzIe'
    'LmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuQ0lEUglwYXJlbnRDaWQaOwoNTWV0YWRhdGFFbn'
    'RyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

