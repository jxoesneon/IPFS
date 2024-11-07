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
    {'1': 'record', '3': 4, '4': 1, '5': 12, '10': 'record'},
    {'1': 'closer_peers', '3': 5, '4': 3, '5': 11, '6': '.ipfs.dht.Peer', '10': 'closerPeers'},
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
    {'1': 'PUT_VALUE', '2': 3},
    {'1': 'GET_VALUE', '2': 4},
    {'1': 'ADD_PROVIDER', '2': 5},
    {'1': 'GET_PROVIDERS', '2': 6},
    {'1': 'PING', '2': 7},
  ],
};

/// Descriptor for `DHTMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dHTMessageDescriptor = $convert.base64Decode(
    'CgpESFRNZXNzYWdlEh0KCm1lc3NhZ2VfaWQYASABKAlSCW1lc3NhZ2VJZBI0CgR0eXBlGAIgAS'
    'gOMiAuaXBmcy5kaHQuREhUTWVzc2FnZS5NZXNzYWdlVHlwZVIEdHlwZRIQCgNrZXkYAyABKAxS'
    'A2tleRIWCgZyZWNvcmQYBCABKAxSBnJlY29yZBIxCgxjbG9zZXJfcGVlcnMYBSADKAsyDi5pcG'
    'ZzLmRodC5QZWVyUgtjbG9zZXJQZWVycxI4Cgl0aW1lc3RhbXAYBiABKAsyGi5nb29nbGUucHJv'
    'dG9idWYuVGltZXN0YW1wUgl0aW1lc3RhbXAihgEKC01lc3NhZ2VUeXBlEgsKB1VOS05PV04QAB'
    'INCglGSU5EX05PREUQARIOCgpGSU5EX1ZBTFVFEAISDQoJUFVUX1ZBTFVFEAMSDQoJR0VUX1ZB'
    'TFVFEAQSEAoMQUREX1BST1ZJREVSEAUSEQoNR0VUX1BST1ZJREVSUxAGEggKBFBJTkcQBw==');

@$core.Deprecated('Use peerDescriptor instead')
const Peer$json = {
  '1': 'Peer',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 12, '10': 'peerId'},
    {'1': 'addresses', '3': 2, '4': 3, '5': 9, '10': 'addresses'},
    {'1': 'connection_info', '3': 3, '4': 3, '5': 11, '6': '.ipfs.dht.Peer.ConnectionInfoEntry', '10': 'connectionInfo'},
  ],
  '3': [Peer_ConnectionInfoEntry$json],
};

@$core.Deprecated('Use peerDescriptor instead')
const Peer_ConnectionInfoEntry$json = {
  '1': 'ConnectionInfoEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Peer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerDescriptor = $convert.base64Decode(
    'CgRQZWVyEhcKB3BlZXJfaWQYASABKAxSBnBlZXJJZBIcCglhZGRyZXNzZXMYAiADKAlSCWFkZH'
    'Jlc3NlcxJLCg9jb25uZWN0aW9uX2luZm8YAyADKAsyIi5pcGZzLmRodC5QZWVyLkNvbm5lY3Rp'
    'b25JbmZvRW50cnlSDmNvbm5lY3Rpb25JbmZvGkEKE0Nvbm5lY3Rpb25JbmZvRW50cnkSEAoDa2'
    'V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAxSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use findNodeRequestDescriptor instead')
const FindNodeRequest$json = {
  '1': 'FindNodeRequest',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 12, '10': 'key'},
    {'1': 'num_closest_peers', '3': 2, '4': 1, '5': 13, '10': 'numClosestPeers'},
  ],
};

/// Descriptor for `FindNodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findNodeRequestDescriptor = $convert.base64Decode(
    'Cg9GaW5kTm9kZVJlcXVlc3QSEAoDa2V5GAEgASgMUgNrZXkSKgoRbnVtX2Nsb3Nlc3RfcGVlcn'
    'MYAiABKA1SD251bUNsb3Nlc3RQZWVycw==');

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

@$core.Deprecated('Use putValueRequestDescriptor instead')
const PutValueRequest$json = {
  '1': 'PutValueRequest',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 12, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
  ],
};

/// Descriptor for `PutValueRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List putValueRequestDescriptor = $convert.base64Decode(
    'Cg9QdXRWYWx1ZVJlcXVlc3QSEAoDa2V5GAEgASgMUgNrZXkSFAoFdmFsdWUYAiABKAxSBXZhbH'
    'Vl');

@$core.Deprecated('Use getValueRequestDescriptor instead')
const GetValueRequest$json = {
  '1': 'GetValueRequest',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 12, '10': 'key'},
  ],
};

/// Descriptor for `GetValueRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getValueRequestDescriptor = $convert.base64Decode(
    'Cg9HZXRWYWx1ZVJlcXVlc3QSEAoDa2V5GAEgASgMUgNrZXk=');

@$core.Deprecated('Use getValueResponseDescriptor instead')
const GetValueResponse$json = {
  '1': 'GetValueResponse',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 12, '10': 'value'},
    {'1': 'closer_peers', '3': 2, '4': 3, '5': 11, '6': '.ipfs.dht.Peer', '10': 'closerPeers'},
  ],
};

/// Descriptor for `GetValueResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getValueResponseDescriptor = $convert.base64Decode(
    'ChBHZXRWYWx1ZVJlc3BvbnNlEhQKBXZhbHVlGAEgASgMUgV2YWx1ZRIxCgxjbG9zZXJfcGVlcn'
    'MYAiADKAsyDi5pcGZzLmRodC5QZWVyUgtjbG9zZXJQZWVycw==');

