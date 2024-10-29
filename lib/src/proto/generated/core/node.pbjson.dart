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

@$core.Deprecated('Use nodeDescriptor instead')
const Node$json = {
  '1': 'Node',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.CIDProto', '10': 'cid'},
    {'1': 'links', '3': 2, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.PBLink', '10': 'links'},
    {'1': 'data', '3': 3, '4': 1, '5': 12, '10': 'data'},
    {'1': 'type', '3': 4, '4': 1, '5': 14, '6': '.ipfs.core.data_structures.NodeTypeProto', '10': 'type'},
    {'1': 'size', '3': 5, '4': 1, '5': 4, '10': 'size'},
    {'1': 'timestamp', '3': 6, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'metadata', '3': 7, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.Node.MetadataEntry', '10': 'metadata'},
  ],
  '3': [Node_MetadataEntry$json],
};

@$core.Deprecated('Use nodeDescriptor instead')
const Node_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Node`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeDescriptor = $convert.base64Decode(
    'CgROb2RlEjUKA2NpZBgBIAEoCzIjLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuQ0lEUHJvdG'
    '9SA2NpZBI3CgVsaW5rcxgCIAMoCzIhLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuUEJMaW5r'
    'UgVsaW5rcxISCgRkYXRhGAMgASgMUgRkYXRhEjwKBHR5cGUYBCABKA4yKC5pcGZzLmNvcmUuZG'
    'F0YV9zdHJ1Y3R1cmVzLk5vZGVUeXBlUHJvdG9SBHR5cGUSEgoEc2l6ZRgFIAEoBFIEc2l6ZRIc'
    'Cgl0aW1lc3RhbXAYBiABKANSCXRpbWVzdGFtcBJJCghtZXRhZGF0YRgHIAMoCzItLmlwZnMuY2'
    '9yZS5kYXRhX3N0cnVjdHVyZXMuTm9kZS5NZXRhZGF0YUVudHJ5UghtZXRhZGF0YRo7Cg1NZXRh'
    'ZGF0YUVudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZToCOAE=');

