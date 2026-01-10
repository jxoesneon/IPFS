// This is a generated file - do not edit.
//
// Generated from dht/kademlia.proto.

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

@$core.Deprecated('Use connectionTypeDescriptor instead')
const ConnectionType$json = {
  '1': 'ConnectionType',
  '2': [
    {'1': 'NOT_CONNECTED', '2': 0},
    {'1': 'CONNECTED', '2': 1},
    {'1': 'CAN_CONNECT', '2': 2},
    {'1': 'CANNOT_CONNECT', '2': 3},
  ],
};

/// Descriptor for `ConnectionType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List connectionTypeDescriptor = $convert
    .base64Decode('Cg5Db25uZWN0aW9uVHlwZRIRCg1OT1RfQ09OTkVDVEVEEAASDQoJQ09OTkVDVEVEEAESDwoLQ0'
        'FOX0NPTk5FQ1QQAhISCg5DQU5OT1RfQ09OTkVDVBAD');

@$core.Deprecated('Use messageDescriptor instead')
const Message$json = {
  '1': 'Message',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 14, '6': '.ipfs.dht.Message.MessageType', '10': 'type'},
    {'1': 'clusterLevelRaw', '3': 10, '4': 1, '5': 5, '10': 'clusterLevelRaw'},
    {'1': 'key', '3': 2, '4': 1, '5': 12, '10': 'key'},
    {'1': 'record', '3': 3, '4': 1, '5': 11, '6': '.ipfs.dht.Record', '10': 'record'},
    {'1': 'closerPeers', '3': 8, '4': 3, '5': 11, '6': '.ipfs.dht.Peer', '10': 'closerPeers'},
    {'1': 'providerPeers', '3': 9, '4': 3, '5': 11, '6': '.ipfs.dht.Peer', '10': 'providerPeers'},
  ],
  '4': [Message_MessageType$json],
};

@$core.Deprecated('Use messageDescriptor instead')
const Message_MessageType$json = {
  '1': 'MessageType',
  '2': [
    {'1': 'PUT_VALUE', '2': 0},
    {'1': 'GET_VALUE', '2': 1},
    {'1': 'ADD_PROVIDER', '2': 2},
    {'1': 'GET_PROVIDERS', '2': 3},
    {'1': 'FIND_NODE', '2': 4},
    {'1': 'PING', '2': 5},
  ],
};

/// Descriptor for `Message`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageDescriptor = $convert
    .base64Decode('CgdNZXNzYWdlEjEKBHR5cGUYASABKA4yHS5pcGZzLmRodC5NZXNzYWdlLk1lc3NhZ2VUeXBlUg'
        'R0eXBlEigKD2NsdXN0ZXJMZXZlbFJhdxgKIAEoBVIPY2x1c3RlckxldmVsUmF3EhAKA2tleRgC'
        'IAEoDFIDa2V5EigKBnJlY29yZBgDIAEoCzIQLmlwZnMuZGh0LlJlY29yZFIGcmVjb3JkEjAKC2'
        'Nsb3NlclBlZXJzGAggAygLMg4uaXBmcy5kaHQuUGVlclILY2xvc2VyUGVlcnMSNAoNcHJvdmlk'
        'ZXJQZWVycxgJIAMoCzIOLmlwZnMuZGh0LlBlZXJSDXByb3ZpZGVyUGVlcnMiaQoLTWVzc2FnZV'
        'R5cGUSDQoJUFVUX1ZBTFVFEAASDQoJR0VUX1ZBTFVFEAESEAoMQUREX1BST1ZJREVSEAISEQoN'
        'R0VUX1BST1ZJREVSUxADEg0KCUZJTkRfTk9ERRAEEggKBFBJTkcQBQ==');

@$core.Deprecated('Use peerDescriptor instead')
const Peer$json = {
  '1': 'Peer',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 12, '10': 'id'},
    {'1': 'addrs', '3': 2, '4': 3, '5': 12, '10': 'addrs'},
    {
      '1': 'connection',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.ipfs.dht.ConnectionType',
      '10': 'connection'
    },
  ],
};

/// Descriptor for `Peer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerDescriptor = $convert
    .base64Decode('CgRQZWVyEg4KAmlkGAEgASgMUgJpZBIUCgVhZGRycxgCIAMoDFIFYWRkcnMSOAoKY29ubmVjdG'
        'lvbhgDIAEoDjIYLmlwZnMuZGh0LkNvbm5lY3Rpb25UeXBlUgpjb25uZWN0aW9u');
