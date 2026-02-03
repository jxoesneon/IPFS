// This is a generated file - do not edit.
//
// Generated from metrics.proto.

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

@$core.Deprecated('Use networkMetricsDescriptor instead')
const NetworkMetrics$json = {
  '1': 'NetworkMetrics',
  '2': [
    {
      '1': 'timestamp',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'timestamp'
    },
    {
      '1': 'peer_metrics',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.ipfs.metrics.NetworkMetrics.PeerMetricsEntry',
      '10': 'peerMetrics'
    },
    {
      '1': 'protocol_metrics',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.ipfs.metrics.NetworkMetrics.ProtocolMetricsEntry',
      '10': 'protocolMetrics'
    },
  ],
  '3': [
    NetworkMetrics_PeerMetricsEntry$json,
    NetworkMetrics_ProtocolMetricsEntry$json
  ],
};

@$core.Deprecated('Use networkMetricsDescriptor instead')
const NetworkMetrics_PeerMetricsEntry$json = {
  '1': 'PeerMetricsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.ipfs.metrics.PeerMetrics',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use networkMetricsDescriptor instead')
const NetworkMetrics_ProtocolMetricsEntry$json = {
  '1': 'ProtocolMetricsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.ipfs.metrics.ProtocolMetrics',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `NetworkMetrics`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List networkMetricsDescriptor = $convert.base64Decode(
    'Cg5OZXR3b3JrTWV0cmljcxI4Cgl0aW1lc3RhbXAYASABKAsyGi5nb29nbGUucHJvdG9idWYuVG'
    'ltZXN0YW1wUgl0aW1lc3RhbXASUAoMcGVlcl9tZXRyaWNzGAIgAygLMi0uaXBmcy5tZXRyaWNz'
    'Lk5ldHdvcmtNZXRyaWNzLlBlZXJNZXRyaWNzRW50cnlSC3BlZXJNZXRyaWNzElwKEHByb3RvY2'
    '9sX21ldHJpY3MYAyADKAsyMS5pcGZzLm1ldHJpY3MuTmV0d29ya01ldHJpY3MuUHJvdG9jb2xN'
    'ZXRyaWNzRW50cnlSD3Byb3RvY29sTWV0cmljcxpZChBQZWVyTWV0cmljc0VudHJ5EhAKA2tleR'
    'gBIAEoCVIDa2V5Ei8KBXZhbHVlGAIgASgLMhkuaXBmcy5tZXRyaWNzLlBlZXJNZXRyaWNzUgV2'
    'YWx1ZToCOAEaYQoUUHJvdG9jb2xNZXRyaWNzRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSMwoFdm'
    'FsdWUYAiABKAsyHS5pcGZzLm1ldHJpY3MuUHJvdG9jb2xNZXRyaWNzUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use peerMetricsDescriptor instead')
const PeerMetrics$json = {
  '1': 'PeerMetrics',
  '2': [
    {'1': 'messages_sent', '3': 1, '4': 1, '5': 4, '10': 'messagesSent'},
    {
      '1': 'messages_received',
      '3': 2,
      '4': 1,
      '5': 4,
      '10': 'messagesReceived'
    },
    {'1': 'bytes_sent', '3': 3, '4': 1, '5': 4, '10': 'bytesSent'},
    {'1': 'bytes_received', '3': 4, '4': 1, '5': 4, '10': 'bytesReceived'},
    {
      '1': 'average_latency_ms',
      '3': 5,
      '4': 1,
      '5': 13,
      '10': 'averageLatencyMs'
    },
    {'1': 'error_count', '3': 6, '4': 1, '5': 13, '10': 'errorCount'},
  ],
};

/// Descriptor for `PeerMetrics`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerMetricsDescriptor = $convert.base64Decode(
    'CgtQZWVyTWV0cmljcxIjCg1tZXNzYWdlc19zZW50GAEgASgEUgxtZXNzYWdlc1NlbnQSKwoRbW'
    'Vzc2FnZXNfcmVjZWl2ZWQYAiABKARSEG1lc3NhZ2VzUmVjZWl2ZWQSHQoKYnl0ZXNfc2VudBgD'
    'IAEoBFIJYnl0ZXNTZW50EiUKDmJ5dGVzX3JlY2VpdmVkGAQgASgEUg1ieXRlc1JlY2VpdmVkEi'
    'wKEmF2ZXJhZ2VfbGF0ZW5jeV9tcxgFIAEoDVIQYXZlcmFnZUxhdGVuY3lNcxIfCgtlcnJvcl9j'
    'b3VudBgGIAEoDVIKZXJyb3JDb3VudA==');

@$core.Deprecated('Use protocolMetricsDescriptor instead')
const ProtocolMetrics$json = {
  '1': 'ProtocolMetrics',
  '2': [
    {'1': 'messages_sent', '3': 1, '4': 1, '5': 4, '10': 'messagesSent'},
    {
      '1': 'messages_received',
      '3': 2,
      '4': 1,
      '5': 4,
      '10': 'messagesReceived'
    },
    {
      '1': 'active_connections',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'activeConnections'
    },
    {
      '1': 'error_counts',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.ipfs.metrics.ProtocolMetrics.ErrorCountsEntry',
      '10': 'errorCounts'
    },
  ],
  '3': [ProtocolMetrics_ErrorCountsEntry$json],
};

@$core.Deprecated('Use protocolMetricsDescriptor instead')
const ProtocolMetrics_ErrorCountsEntry$json = {
  '1': 'ErrorCountsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 4, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `ProtocolMetrics`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protocolMetricsDescriptor = $convert.base64Decode(
    'Cg9Qcm90b2NvbE1ldHJpY3MSIwoNbWVzc2FnZXNfc2VudBgBIAEoBFIMbWVzc2FnZXNTZW50Ei'
    'sKEW1lc3NhZ2VzX3JlY2VpdmVkGAIgASgEUhBtZXNzYWdlc1JlY2VpdmVkEi0KEmFjdGl2ZV9j'
    'b25uZWN0aW9ucxgDIAEoDVIRYWN0aXZlQ29ubmVjdGlvbnMSUQoMZXJyb3JfY291bnRzGAQgAy'
    'gLMi4uaXBmcy5tZXRyaWNzLlByb3RvY29sTWV0cmljcy5FcnJvckNvdW50c0VudHJ5UgtlcnJv'
    'ckNvdW50cxo+ChBFcnJvckNvdW50c0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGA'
    'IgASgEUgV2YWx1ZToCOAE=');

