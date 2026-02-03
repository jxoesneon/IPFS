// This is a generated file - do not edit.
//
// Generated from connection.proto.

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

@$core.Deprecated('Use connectionStateDescriptor instead')
const ConnectionState$json = {
  '1': 'ConnectionState',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.ipfs.connection.ConnectionState.Status',
      '10': 'status'
    },
    {
      '1': 'connected_at',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'connectedAt'
    },
    {
      '1': 'metadata',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.ipfs.connection.ConnectionState.MetadataEntry',
      '10': 'metadata'
    },
  ],
  '3': [ConnectionState_MetadataEntry$json],
  '4': [ConnectionState_Status$json],
};

@$core.Deprecated('Use connectionStateDescriptor instead')
const ConnectionState_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use connectionStateDescriptor instead')
const ConnectionState_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'UNKNOWN', '2': 0},
    {'1': 'CONNECTING', '2': 1},
    {'1': 'CONNECTED', '2': 2},
    {'1': 'DISCONNECTING', '2': 3},
    {'1': 'DISCONNECTED', '2': 4},
    {'1': 'ERROR', '2': 5},
  ],
};

/// Descriptor for `ConnectionState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectionStateDescriptor = $convert.base64Decode(
    'Cg9Db25uZWN0aW9uU3RhdGUSFwoHcGVlcl9pZBgBIAEoCVIGcGVlcklkEj8KBnN0YXR1cxgCIA'
    'EoDjInLmlwZnMuY29ubmVjdGlvbi5Db25uZWN0aW9uU3RhdGUuU3RhdHVzUgZzdGF0dXMSPQoM'
    'Y29ubmVjdGVkX2F0GAMgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFILY29ubmVjdG'
    'VkQXQSSgoIbWV0YWRhdGEYBCADKAsyLi5pcGZzLmNvbm5lY3Rpb24uQ29ubmVjdGlvblN0YXRl'
    'Lk1ldGFkYXRhRW50cnlSCG1ldGFkYXRhGjsKDU1ldGFkYXRhRW50cnkSEAoDa2V5GAEgASgJUg'
    'NrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4ASJkCgZTdGF0dXMSCwoHVU5LTk9XThAAEg4K'
    'CkNPTk5FQ1RJTkcQARINCglDT05ORUNURUQQAhIRCg1ESVNDT05ORUNUSU5HEAMSEAoMRElTQ0'
    '9OTkVDVEVEEAQSCQoFRVJST1IQBQ==');

@$core.Deprecated('Use connectionMetricsDescriptor instead')
const ConnectionMetrics$json = {
  '1': 'ConnectionMetrics',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'messages_sent', '3': 2, '4': 1, '5': 4, '10': 'messagesSent'},
    {
      '1': 'messages_received',
      '3': 3,
      '4': 1,
      '5': 4,
      '10': 'messagesReceived'
    },
    {'1': 'bytes_sent', '3': 4, '4': 1, '5': 4, '10': 'bytesSent'},
    {'1': 'bytes_received', '3': 5, '4': 1, '5': 4, '10': 'bytesReceived'},
    {
      '1': 'average_latency_ms',
      '3': 6,
      '4': 1,
      '5': 13,
      '10': 'averageLatencyMs'
    },
  ],
};

/// Descriptor for `ConnectionMetrics`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectionMetricsDescriptor = $convert.base64Decode(
    'ChFDb25uZWN0aW9uTWV0cmljcxIXCgdwZWVyX2lkGAEgASgJUgZwZWVySWQSIwoNbWVzc2FnZX'
    'Nfc2VudBgCIAEoBFIMbWVzc2FnZXNTZW50EisKEW1lc3NhZ2VzX3JlY2VpdmVkGAMgASgEUhBt'
    'ZXNzYWdlc1JlY2VpdmVkEh0KCmJ5dGVzX3NlbnQYBCABKARSCWJ5dGVzU2VudBIlCg5ieXRlc1'
    '9yZWNlaXZlZBgFIAEoBFINYnl0ZXNSZWNlaXZlZBIsChJhdmVyYWdlX2xhdGVuY3lfbXMYBiAB'
    'KA1SEGF2ZXJhZ2VMYXRlbmN5TXM=');

