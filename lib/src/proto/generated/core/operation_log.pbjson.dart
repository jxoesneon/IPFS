// This is a generated file - do not edit.
//
// Generated from core/operation_log.proto.

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

@$core.Deprecated('Use operationLogEntryProtoDescriptor instead')
const OperationLogEntryProto$json = {
  '1': 'OperationLogEntryProto',
  '2': [
    {'1': 'timestamp', '3': 1, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'operation', '3': 2, '4': 1, '5': 9, '10': 'operation'},
    {'1': 'details', '3': 3, '4': 1, '5': 9, '10': 'details'},
    {
      '1': 'cid',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.IPFSCIDProto',
      '10': 'cid'
    },
    {
      '1': 'node_type',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.ipfs.core.data_structures.NodeTypeProto',
      '10': 'nodeType'
    },
  ],
};

/// Descriptor for `OperationLogEntryProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationLogEntryProtoDescriptor = $convert.base64Decode(
    'ChZPcGVyYXRpb25Mb2dFbnRyeVByb3RvEhwKCXRpbWVzdGFtcBgBIAEoA1IJdGltZXN0YW1wEh'
    'wKCW9wZXJhdGlvbhgCIAEoCVIJb3BlcmF0aW9uEhgKB2RldGFpbHMYAyABKAlSB2RldGFpbHMS'
    'KQoDY2lkGAQgASgLMhcuaXBmcy5jb3JlLklQRlNDSURQcm90b1IDY2lkEkUKCW5vZGVfdHlwZR'
    'gFIAEoDjIoLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuTm9kZVR5cGVQcm90b1IIbm9kZVR5'
    'cGU=');

@$core.Deprecated('Use operationLogProtoDescriptor instead')
const OperationLogProto$json = {
  '1': 'OperationLogProto',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.ipfs.core.data_structures.OperationLogEntryProto',
      '10': 'entries'
    },
  ],
};

/// Descriptor for `OperationLogProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationLogProtoDescriptor = $convert.base64Decode(
    'ChFPcGVyYXRpb25Mb2dQcm90bxJLCgdlbnRyaWVzGAEgAygLMjEuaXBmcy5jb3JlLmRhdGFfc3'
    'RydWN0dXJlcy5PcGVyYXRpb25Mb2dFbnRyeVByb3RvUgdlbnRyaWVz');
