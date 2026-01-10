// This is a generated file - do not edit.
//
// Generated from base_messages.proto.

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

@$core.Deprecated('Use iPFSMessageDescriptor instead')
const IPFSMessage$json = {
  '1': 'IPFSMessage',
  '2': [
    {'1': 'protocol_id', '3': 1, '4': 1, '5': 9, '10': 'protocolId'},
    {'1': 'payload', '3': 2, '4': 1, '5': 12, '10': 'payload'},
    {
      '1': 'timestamp',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'timestamp'
    },
    {'1': 'sender_id', '3': 4, '4': 1, '5': 9, '10': 'senderId'},
    {
      '1': 'type',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.ipfs.base.IPFSMessage.MessageType',
      '10': 'type'
    },
    {'1': 'request_id', '3': 6, '4': 1, '5': 9, '10': 'requestId'},
  ],
  '4': [IPFSMessage_MessageType$json],
};

@$core.Deprecated('Use iPFSMessageDescriptor instead')
const IPFSMessage_MessageType$json = {
  '1': 'MessageType',
  '2': [
    {'1': 'UNKNOWN', '2': 0},
    {'1': 'DHT', '2': 1},
    {'1': 'BITSWAP', '2': 2},
    {'1': 'PUBSUB', '2': 3},
    {'1': 'IDENTIFY', '2': 4},
    {'1': 'PING', '2': 5},
  ],
};

/// Descriptor for `IPFSMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iPFSMessageDescriptor = $convert.base64Decode(
    'CgtJUEZTTWVzc2FnZRIfCgtwcm90b2NvbF9pZBgBIAEoCVIKcHJvdG9jb2xJZBIYCgdwYXlsb2'
    'FkGAIgASgMUgdwYXlsb2FkEjgKCXRpbWVzdGFtcBgDIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5U'
    'aW1lc3RhbXBSCXRpbWVzdGFtcBIbCglzZW5kZXJfaWQYBCABKAlSCHNlbmRlcklkEjYKBHR5cG'
    'UYBSABKA4yIi5pcGZzLmJhc2UuSVBGU01lc3NhZ2UuTWVzc2FnZVR5cGVSBHR5cGUSHQoKcmVx'
    'dWVzdF9pZBgGIAEoCVIJcmVxdWVzdElkIlQKC01lc3NhZ2VUeXBlEgsKB1VOS05PV04QABIHCg'
    'NESFQQARILCgdCSVRTV0FQEAISCgoGUFVCU1VCEAMSDAoISURFTlRJRlkQBBIICgRQSU5HEAU=');

@$core.Deprecated('Use networkEventDescriptor instead')
const NetworkEvent$json = {
  '1': 'NetworkEvent',
  '2': [
    {
      '1': 'timestamp',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'timestamp'
    },
    {'1': 'event_type', '3': 2, '4': 1, '5': 9, '10': 'eventType'},
    {'1': 'peer_id', '3': 3, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'data', '3': 4, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `NetworkEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List networkEventDescriptor = $convert.base64Decode(
    'CgxOZXR3b3JrRXZlbnQSOAoJdGltZXN0YW1wGAEgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbW'
    'VzdGFtcFIJdGltZXN0YW1wEh0KCmV2ZW50X3R5cGUYAiABKAlSCWV2ZW50VHlwZRIXCgdwZWVy'
    'X2lkGAMgASgJUgZwZWVySWQSEgoEZGF0YRgEIAEoDFIEZGF0YQ==');
