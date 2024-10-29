//
//  Generated code. Do not modify.
//  source: dht/merkle_dag_node.proto
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
    {'1': 'cid', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.CIDProto', '10': 'cid'},
    {'1': 'links', '3': 2, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.PBLink', '10': 'links'},
    {'1': 'data', '3': 3, '4': 1, '5': 12, '10': 'data'},
    {'1': 'size', '3': 4, '4': 1, '5': 4, '10': 'size'},
    {'1': 'timestamp', '3': 5, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'metadata', '3': 6, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.MerkleDAGNode.MetadataEntry', '10': 'metadata'},
    {'1': 'is_directory', '3': 7, '4': 1, '5': 8, '10': 'isDirectory'},
    {'1': 'parent_cid', '3': 8, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.CIDProto', '10': 'parentCid'},
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
    'Cg1NZXJrbGVEQUdOb2RlEjUKA2NpZBgBIAEoCzIjLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZX'
    'MuQ0lEUHJvdG9SA2NpZBI3CgVsaW5rcxgCIAMoCzIhLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVy'
    'ZXMuUEJMaW5rUgVsaW5rcxISCgRkYXRhGAMgASgMUgRkYXRhEhIKBHNpemUYBCABKARSBHNpem'
    'USHAoJdGltZXN0YW1wGAUgASgDUgl0aW1lc3RhbXASUgoIbWV0YWRhdGEYBiADKAsyNi5pcGZz'
    'LmNvcmUuZGF0YV9zdHJ1Y3R1cmVzLk1lcmtsZURBR05vZGUuTWV0YWRhdGFFbnRyeVIIbWV0YW'
    'RhdGESIQoMaXNfZGlyZWN0b3J5GAcgASgIUgtpc0RpcmVjdG9yeRJCCgpwYXJlbnRfY2lkGAgg'
    'ASgLMiMuaXBmcy5jb3JlLmRhdGFfc3RydWN0dXJlcy5DSURQcm90b1IJcGFyZW50Q2lkGjsKDU'
    '1ldGFkYXRhRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4'
    'AQ==');

