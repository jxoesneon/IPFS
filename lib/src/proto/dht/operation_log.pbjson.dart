//
//  Generated code. Do not modify.
//  source: operation_log.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use operationLogEntryDescriptor instead')
const OperationLogEntry$json = {
  '1': 'OperationLogEntry',
  '2': [
    {'1': 'timestamp', '3': 1, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'operation', '3': 2, '4': 1, '5': 9, '10': 'operation'},
    {'1': 'details', '3': 3, '4': 1, '5': 9, '10': 'details'},
    {'1': 'cid', '3': 4, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.CIDProto', '10': 'cid'},
    {'1': 'node_type', '3': 5, '4': 1, '5': 14, '6': '.ipfs.core.data_structures.NodeTypeProto', '10': 'nodeType'},
  ],
};

/// Descriptor for `OperationLogEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationLogEntryDescriptor = $convert.base64Decode(
    'ChFPcGVyYXRpb25Mb2dFbnRyeRIcCgl0aW1lc3RhbXAYASABKANSCXRpbWVzdGFtcBIcCglvcG'
    'VyYXRpb24YAiABKAlSCW9wZXJhdGlvbhIYCgdkZXRhaWxzGAMgASgJUgdkZXRhaWxzEjUKA2Np'
    'ZBgEIAEoCzIjLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuQ0lEUHJvdG9SA2NpZBJFCglub2'
    'RlX3R5cGUYBSABKA4yKC5pcGZzLmNvcmUuZGF0YV9zdHJ1Y3R1cmVzLk5vZGVUeXBlUHJvdG9S'
    'CG5vZGVUeXBl');

@$core.Deprecated('Use operationLogDescriptor instead')
const OperationLog$json = {
  '1': 'OperationLog',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.OperationLogEntry', '10': 'entries'},
  ],
};

/// Descriptor for `OperationLog`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationLogDescriptor = $convert.base64Decode(
    'CgxPcGVyYXRpb25Mb2cSRgoHZW50cmllcxgBIAMoCzIsLmlwZnMuY29yZS5kYXRhX3N0cnVjdH'
    'VyZXMuT3BlcmF0aW9uTG9nRW50cnlSB2VudHJpZXM=');

