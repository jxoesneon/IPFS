//
//  Generated code. Do not modify.
//  source: dht_messages.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use dHTMessageDescriptor instead')
const DHTMessage$json = {
  '1': 'DHTMessage',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'type', '3': 2, '4': 1, '5': 14, '6': '.ipfs.dht.DHTMessage.MessageType', '10': 'type'},
    {'1': 'key', '3': 3, '4': 1, '5': 12, '10': 'key'},
    {'1': 'value', '3': 4, '4': 1, '5': 12, '10': 'value'},
    {'1': 'closer_peers', '3': 5, '4': 3, '5': 9, '10': 'closerPeers'},
    {'1': 'timestamp', '3': 6, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'timestamp'},
  ],
  '4': [DHTMessage_MessageType$json],
};

@$core.Deprecated('Use dHTMessageDescriptor instead')
const DHTMessage_MessageType$json = {
  '1': 'MessageType',
  '2': [
    {'1': 'UNKNOWN', '2': 0},
    {'1': 'FIND_NODE', '2': 1},
    {'1': 'FIND_VALUE', '2': 2},
    {'1': 'STORE', '2': 3},
    {'1': 'PING', '2': 4},
  ],
};

/// Descriptor for `DHTMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dHTMessageDescriptor = $convert.base64Decode(
    'CgpESFRNZXNzYWdlEh0KCm1lc3NhZ2VfaWQYASABKAlSCW1lc3NhZ2VJZBI0CgR0eXBlGAIgAS'
    'gOMiAuaXBmcy5kaHQuREhUTWVzc2FnZS5NZXNzYWdlVHlwZVIEdHlwZRIQCgNrZXkYAyABKAxS'
    'A2tleRIUCgV2YWx1ZRgEIAEoDFIFdmFsdWUSIQoMY2xvc2VyX3BlZXJzGAUgAygJUgtjbG9zZX'
    'JQZWVycxI4Cgl0aW1lc3RhbXAYBiABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgl0'
    'aW1lc3RhbXAiTgoLTWVzc2FnZVR5cGUSCwoHVU5LTk9XThAAEg0KCUZJTkRfTk9ERRABEg4KCk'
    'ZJTkRfVkFMVUUQAhIJCgVTVE9SRRADEggKBFBJTkcQBA==');

@$core.Deprecated('Use findNodeRequestDescriptor instead')
const FindNodeRequest$json = {
  '1': 'FindNodeRequest',
  '2': [
    {'1': 'target_id', '3': 1, '4': 1, '5': 12, '10': 'targetId'},
    {'1': 'num_closest_peers', '3': 2, '4': 1, '5': 13, '10': 'numClosestPeers'},
  ],
};

/// Descriptor for `FindNodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findNodeRequestDescriptor = $convert.base64Decode(
    'Cg9GaW5kTm9kZVJlcXVlc3QSGwoJdGFyZ2V0X2lkGAEgASgMUgh0YXJnZXRJZBIqChFudW1fY2'
    'xvc2VzdF9wZWVycxgCIAEoDVIPbnVtQ2xvc2VzdFBlZXJz');

@$core.Deprecated('Use findNodeResponseDescriptor instead')
const FindNodeResponse$json = {
  '1': 'FindNodeResponse',
  '2': [
    {'1': 'closer_peers', '3': 1, '4': 3, '5': 11, '6': '.ipfs.dht.Peer', '10': 'closerPeers'},
  ],
};

/// Descriptor for `FindNodeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findNodeResponseDescriptor = $convert.base64Decode(
    'ChBGaW5kTm9kZVJlc3BvbnNlEjEKDGNsb3Nlcl9wZWVycxgBIAMoCzIOLmlwZnMuZGh0LlBlZX'
    'JSC2Nsb3NlclBlZXJz');

@$core.Deprecated('Use peerDescriptor instead')
const Peer$json = {
  '1': 'Peer',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 12, '10': 'peerId'},
    {'1': 'addresses', '3': 2, '4': 3, '5': 9, '10': 'addresses'},
    {'1': 'metadata', '3': 3, '4': 3, '5': 11, '6': '.ipfs.dht.Peer.MetadataEntry', '10': 'metadata'},
  ],
  '3': [Peer_MetadataEntry$json],
};

@$core.Deprecated('Use peerDescriptor instead')
const Peer_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Peer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerDescriptor = $convert.base64Decode(
    'CgRQZWVyEhcKB3BlZXJfaWQYASABKAxSBnBlZXJJZBIcCglhZGRyZXNzZXMYAiADKAlSCWFkZH'
    'Jlc3NlcxI4CghtZXRhZGF0YRgDIAMoCzIcLmlwZnMuZGh0LlBlZXIuTWV0YWRhdGFFbnRyeVII'
    'bWV0YWRhdGEaOwoNTWV0YWRhdGFFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIA'
    'EoCVIFdmFsdWU6AjgB');

