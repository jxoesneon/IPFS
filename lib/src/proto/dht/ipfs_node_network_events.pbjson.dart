//
//  Generated code. Do not modify.
//  source: ipfs_node_network_events.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use networkEventDescriptor instead')
const NetworkEvent$json = {
  '1': 'NetworkEvent',
  '2': [
    {'1': 'peer_connected', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.PeerConnectedEvent', '9': 0, '10': 'peerConnected'},
    {'1': 'peer_disconnected', '3': 2, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.PeerDisconnectedEvent', '9': 0, '10': 'peerDisconnected'},
    {'1': 'connection_attempted', '3': 3, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.ConnectionAttemptedEvent', '9': 0, '10': 'connectionAttempted'},
    {'1': 'connection_failed', '3': 4, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.ConnectionFailedEvent', '9': 0, '10': 'connectionFailed'},
    {'1': 'message_received', '3': 5, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.MessageReceivedEvent', '9': 0, '10': 'messageReceived'},
    {'1': 'message_sent', '3': 6, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.MessageSentEvent', '9': 0, '10': 'messageSent'},
    {'1': 'block_received', '3': 7, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.BlockReceivedEvent', '9': 0, '10': 'blockReceived'},
    {'1': 'block_sent', '3': 8, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.BlockSentEvent', '9': 0, '10': 'blockSent'},
    {'1': 'dht_query_started', '3': 9, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.DhtQueryStartedEvent', '9': 0, '10': 'dhtQueryStarted'},
    {'1': 'dht_query_completed', '3': 10, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.DhtQueryCompletedEvent', '9': 0, '10': 'dhtQueryCompleted'},
    {'1': 'dht_value_found', '3': 11, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.DhtValueFoundEvent', '9': 0, '10': 'dhtValueFound'},
    {'1': 'dht_value_provided', '3': 12, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.DhtValueProvidedEvent', '9': 0, '10': 'dhtValueProvided'},
    {'1': 'pubsub_message_published', '3': 13, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.PubsubMessagePublishedEvent', '9': 0, '10': 'pubsubMessagePublished'},
    {'1': 'pubsub_message_received', '3': 14, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.PubsubMessageReceivedEvent', '9': 0, '10': 'pubsubMessageReceived'},
    {'1': 'pubsub_subscription_created', '3': 15, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.PubsubSubscriptionCreatedEvent', '9': 0, '10': 'pubsubSubscriptionCreated'},
    {'1': 'pubsub_subscription_cancelled', '3': 16, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.PubsubSubscriptionCancelledEvent', '9': 0, '10': 'pubsubSubscriptionCancelled'},
    {'1': 'circuit_relay_created', '3': 17, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.CircuitRelayCreatedEvent', '9': 0, '10': 'circuitRelayCreated'},
    {'1': 'circuit_relay_closed', '3': 18, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.CircuitRelayClosedEvent', '9': 0, '10': 'circuitRelayClosed'},
    {'1': 'circuit_relay_traffic', '3': 19, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.CircuitRelayTrafficEvent', '9': 0, '10': 'circuitRelayTraffic'},
    {'1': 'node_started', '3': 20, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.NodeStartedEvent', '9': 0, '10': 'nodeStarted'},
    {'1': 'node_stopped', '3': 21, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.NodeStoppedEvent', '9': 0, '10': 'nodeStopped'},
    {'1': 'error', '3': 22, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.ErrorEvent', '9': 0, '10': 'error'},
    {'1': 'network_changed', '3': 23, '4': 1, '5': 11, '6': '.ipfs.core.ipfs_node.NetworkChangedEvent', '9': 0, '10': 'networkChanged'},
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `NetworkEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List networkEventDescriptor = $convert.base64Decode(
    'CgxOZXR3b3JrRXZlbnQSUAoOcGVlcl9jb25uZWN0ZWQYASABKAsyJy5pcGZzLmNvcmUuaXBmc1'
    '9ub2RlLlBlZXJDb25uZWN0ZWRFdmVudEgAUg1wZWVyQ29ubmVjdGVkElkKEXBlZXJfZGlzY29u'
    'bmVjdGVkGAIgASgLMiouaXBmcy5jb3JlLmlwZnNfbm9kZS5QZWVyRGlzY29ubmVjdGVkRXZlbn'
    'RIAFIQcGVlckRpc2Nvbm5lY3RlZBJiChRjb25uZWN0aW9uX2F0dGVtcHRlZBgDIAEoCzItLmlw'
    'ZnMuY29yZS5pcGZzX25vZGUuQ29ubmVjdGlvbkF0dGVtcHRlZEV2ZW50SABSE2Nvbm5lY3Rpb2'
    '5BdHRlbXB0ZWQSWQoRY29ubmVjdGlvbl9mYWlsZWQYBCABKAsyKi5pcGZzLmNvcmUuaXBmc19u'
    'b2RlLkNvbm5lY3Rpb25GYWlsZWRFdmVudEgAUhBjb25uZWN0aW9uRmFpbGVkElYKEG1lc3NhZ2'
    'VfcmVjZWl2ZWQYBSABKAsyKS5pcGZzLmNvcmUuaXBmc19ub2RlLk1lc3NhZ2VSZWNlaXZlZEV2'
    'ZW50SABSD21lc3NhZ2VSZWNlaXZlZBJKCgxtZXNzYWdlX3NlbnQYBiABKAsyJS5pcGZzLmNvcm'
    'UuaXBmc19ub2RlLk1lc3NhZ2VTZW50RXZlbnRIAFILbWVzc2FnZVNlbnQSUAoOYmxvY2tfcmVj'
    'ZWl2ZWQYByABKAsyJy5pcGZzLmNvcmUuaXBmc19ub2RlLkJsb2NrUmVjZWl2ZWRFdmVudEgAUg'
    '1ibG9ja1JlY2VpdmVkEkQKCmJsb2NrX3NlbnQYCCABKAsyIy5pcGZzLmNvcmUuaXBmc19ub2Rl'
    'LkJsb2NrU2VudEV2ZW50SABSCWJsb2NrU2VudBJXChFkaHRfcXVlcnlfc3RhcnRlZBgJIAEoCz'
    'IpLmlwZnMuY29yZS5pcGZzX25vZGUuRGh0UXVlcnlTdGFydGVkRXZlbnRIAFIPZGh0UXVlcnlT'
    'dGFydGVkEl0KE2RodF9xdWVyeV9jb21wbGV0ZWQYCiABKAsyKy5pcGZzLmNvcmUuaXBmc19ub2'
    'RlLkRodFF1ZXJ5Q29tcGxldGVkRXZlbnRIAFIRZGh0UXVlcnlDb21wbGV0ZWQSUQoPZGh0X3Zh'
    'bHVlX2ZvdW5kGAsgASgLMicuaXBmcy5jb3JlLmlwZnNfbm9kZS5EaHRWYWx1ZUZvdW5kRXZlbn'
    'RIAFINZGh0VmFsdWVGb3VuZBJaChJkaHRfdmFsdWVfcHJvdmlkZWQYDCABKAsyKi5pcGZzLmNv'
    'cmUuaXBmc19ub2RlLkRodFZhbHVlUHJvdmlkZWRFdmVudEgAUhBkaHRWYWx1ZVByb3ZpZGVkEm'
    'wKGHB1YnN1Yl9tZXNzYWdlX3B1Ymxpc2hlZBgNIAEoCzIwLmlwZnMuY29yZS5pcGZzX25vZGUu'
    'UHVic3ViTWVzc2FnZVB1Ymxpc2hlZEV2ZW50SABSFnB1YnN1Yk1lc3NhZ2VQdWJsaXNoZWQSaQ'
    'oXcHVic3ViX21lc3NhZ2VfcmVjZWl2ZWQYDiABKAsyLy5pcGZzLmNvcmUuaXBmc19ub2RlLlB1'
    'YnN1Yk1lc3NhZ2VSZWNlaXZlZEV2ZW50SABSFXB1YnN1Yk1lc3NhZ2VSZWNlaXZlZBJ1ChtwdW'
    'JzdWJfc3Vic2NyaXB0aW9uX2NyZWF0ZWQYDyABKAsyMy5pcGZzLmNvcmUuaXBmc19ub2RlLlB1'
    'YnN1YlN1YnNjcmlwdGlvbkNyZWF0ZWRFdmVudEgAUhlwdWJzdWJTdWJzY3JpcHRpb25DcmVhdG'
    'VkEnsKHXB1YnN1Yl9zdWJzY3JpcHRpb25fY2FuY2VsbGVkGBAgASgLMjUuaXBmcy5jb3JlLmlw'
    'ZnNfbm9kZS5QdWJzdWJTdWJzY3JpcHRpb25DYW5jZWxsZWRFdmVudEgAUhtwdWJzdWJTdWJzY3'
    'JpcHRpb25DYW5jZWxsZWQSYwoVY2lyY3VpdF9yZWxheV9jcmVhdGVkGBEgASgLMi0uaXBmcy5j'
    'b3JlLmlwZnNfbm9kZS5DaXJjdWl0UmVsYXlDcmVhdGVkRXZlbnRIAFITY2lyY3VpdFJlbGF5Q3'
    'JlYXRlZBJgChRjaXJjdWl0X3JlbGF5X2Nsb3NlZBgSIAEoCzIsLmlwZnMuY29yZS5pcGZzX25v'
    'ZGUuQ2lyY3VpdFJlbGF5Q2xvc2VkRXZlbnRIAFISY2lyY3VpdFJlbGF5Q2xvc2VkEmMKFWNpcm'
    'N1aXRfcmVsYXlfdHJhZmZpYxgTIAEoCzItLmlwZnMuY29yZS5pcGZzX25vZGUuQ2lyY3VpdFJl'
    'bGF5VHJhZmZpY0V2ZW50SABSE2NpcmN1aXRSZWxheVRyYWZmaWMSSgoMbm9kZV9zdGFydGVkGB'
    'QgASgLMiUuaXBmcy5jb3JlLmlwZnNfbm9kZS5Ob2RlU3RhcnRlZEV2ZW50SABSC25vZGVTdGFy'
    'dGVkEkoKDG5vZGVfc3RvcHBlZBgVIAEoCzIlLmlwZnMuY29yZS5pcGZzX25vZGUuTm9kZVN0b3'
    'BwZWRFdmVudEgAUgtub2RlU3RvcHBlZBI3CgVlcnJvchgWIAEoCzIfLmlwZnMuY29yZS5pcGZz'
    'X25vZGUuRXJyb3JFdmVudEgAUgVlcnJvchJTCg9uZXR3b3JrX2NoYW5nZWQYFyABKAsyKC5pcG'
    'ZzLmNvcmUuaXBmc19ub2RlLk5ldHdvcmtDaGFuZ2VkRXZlbnRIAFIObmV0d29ya0NoYW5nZWRC'
    'BwoFZXZlbnQ=');

@$core.Deprecated('Use peerConnectedEventDescriptor instead')
const PeerConnectedEvent$json = {
  '1': 'PeerConnectedEvent',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'multiaddress', '3': 2, '4': 1, '5': 9, '10': 'multiaddress'},
  ],
};

/// Descriptor for `PeerConnectedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerConnectedEventDescriptor = $convert.base64Decode(
    'ChJQZWVyQ29ubmVjdGVkRXZlbnQSFwoHcGVlcl9pZBgBIAEoCVIGcGVlcklkEiIKDG11bHRpYW'
    'RkcmVzcxgCIAEoCVIMbXVsdGlhZGRyZXNz');

@$core.Deprecated('Use peerDisconnectedEventDescriptor instead')
const PeerDisconnectedEvent$json = {
  '1': 'PeerDisconnectedEvent',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `PeerDisconnectedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerDisconnectedEventDescriptor = $convert.base64Decode(
    'ChVQZWVyRGlzY29ubmVjdGVkRXZlbnQSFwoHcGVlcl9pZBgBIAEoCVIGcGVlcklkEhYKBnJlYX'
    'NvbhgCIAEoCVIGcmVhc29u');

@$core.Deprecated('Use connectionAttemptedEventDescriptor instead')
const ConnectionAttemptedEvent$json = {
  '1': 'ConnectionAttemptedEvent',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'success', '3': 2, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `ConnectionAttemptedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectionAttemptedEventDescriptor = $convert.base64Decode(
    'ChhDb25uZWN0aW9uQXR0ZW1wdGVkRXZlbnQSFwoHcGVlcl9pZBgBIAEoCVIGcGVlcklkEhgKB3'
    'N1Y2Nlc3MYAiABKAhSB3N1Y2Nlc3M=');

@$core.Deprecated('Use connectionFailedEventDescriptor instead')
const ConnectionFailedEvent$json = {
  '1': 'ConnectionFailedEvent',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `ConnectionFailedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectionFailedEventDescriptor = $convert.base64Decode(
    'ChVDb25uZWN0aW9uRmFpbGVkRXZlbnQSFwoHcGVlcl9pZBgBIAEoCVIGcGVlcklkEhYKBnJlYX'
    'NvbhgCIAEoCVIGcmVhc29u');

@$core.Deprecated('Use messageReceivedEventDescriptor instead')
const MessageReceivedEvent$json = {
  '1': 'MessageReceivedEvent',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'message_content', '3': 2, '4': 1, '5': 12, '10': 'messageContent'},
  ],
};

/// Descriptor for `MessageReceivedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageReceivedEventDescriptor = $convert.base64Decode(
    'ChRNZXNzYWdlUmVjZWl2ZWRFdmVudBIXCgdwZWVyX2lkGAEgASgJUgZwZWVySWQSJwoPbWVzc2'
    'FnZV9jb250ZW50GAIgASgMUg5tZXNzYWdlQ29udGVudA==');

@$core.Deprecated('Use messageSentEventDescriptor instead')
const MessageSentEvent$json = {
  '1': 'MessageSentEvent',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'message_content', '3': 2, '4': 1, '5': 12, '10': 'messageContent'},
  ],
};

/// Descriptor for `MessageSentEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageSentEventDescriptor = $convert.base64Decode(
    'ChBNZXNzYWdlU2VudEV2ZW50EhcKB3BlZXJfaWQYASABKAlSBnBlZXJJZBInCg9tZXNzYWdlX2'
    'NvbnRlbnQYAiABKAxSDm1lc3NhZ2VDb250ZW50');

@$core.Deprecated('Use blockReceivedEventDescriptor instead')
const BlockReceivedEvent$json = {
  '1': 'BlockReceivedEvent',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 9, '10': 'cid'},
    {'1': 'peer_id', '3': 2, '4': 1, '5': 9, '10': 'peerId'},
  ],
};

/// Descriptor for `BlockReceivedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockReceivedEventDescriptor = $convert.base64Decode(
    'ChJCbG9ja1JlY2VpdmVkRXZlbnQSEAoDY2lkGAEgASgJUgNjaWQSFwoHcGVlcl9pZBgCIAEoCV'
    'IGcGVlcklk');

@$core.Deprecated('Use blockSentEventDescriptor instead')
const BlockSentEvent$json = {
  '1': 'BlockSentEvent',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 9, '10': 'cid'},
    {'1': 'peer_id', '3': 2, '4': 1, '5': 9, '10': 'peerId'},
  ],
};

/// Descriptor for `BlockSentEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockSentEventDescriptor = $convert.base64Decode(
    'Cg5CbG9ja1NlbnRFdmVudBIQCgNjaWQYASABKAlSA2NpZBIXCgdwZWVyX2lkGAIgASgJUgZwZW'
    'VySWQ=');

@$core.Deprecated('Use dhtQueryStartedEventDescriptor instead')
const DhtQueryStartedEvent$json = {
  '1': 'DhtQueryStartedEvent',
  '2': [
    {'1': 'query_type', '3': 1, '4': 1, '5': 9, '10': 'queryType'},
    {'1': 'target_key', '3': 2, '4': 1, '5': 9, '10': 'targetKey'},
  ],
};

/// Descriptor for `DhtQueryStartedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dhtQueryStartedEventDescriptor = $convert.base64Decode(
    'ChREaHRRdWVyeVN0YXJ0ZWRFdmVudBIdCgpxdWVyeV90eXBlGAEgASgJUglxdWVyeVR5cGUSHQ'
    'oKdGFyZ2V0X2tleRgCIAEoCVIJdGFyZ2V0S2V5');

@$core.Deprecated('Use dhtQueryCompletedEventDescriptor instead')
const DhtQueryCompletedEvent$json = {
  '1': 'DhtQueryCompletedEvent',
  '2': [
    {'1': 'query_type', '3': 1, '4': 1, '5': 9, '10': 'queryType'},
    {'1': 'target_key', '3': 2, '4': 1, '5': 9, '10': 'targetKey'},
    {'1': 'results', '3': 3, '4': 3, '5': 9, '10': 'results'},
  ],
};

/// Descriptor for `DhtQueryCompletedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dhtQueryCompletedEventDescriptor = $convert.base64Decode(
    'ChZEaHRRdWVyeUNvbXBsZXRlZEV2ZW50Eh0KCnF1ZXJ5X3R5cGUYASABKAlSCXF1ZXJ5VHlwZR'
    'IdCgp0YXJnZXRfa2V5GAIgASgJUgl0YXJnZXRLZXkSGAoHcmVzdWx0cxgDIAMoCVIHcmVzdWx0'
    'cw==');

@$core.Deprecated('Use dhtValueFoundEventDescriptor instead')
const DhtValueFoundEvent$json = {
  '1': 'DhtValueFoundEvent',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
    {'1': 'peer_id', '3': 3, '4': 1, '5': 9, '10': 'peerId'},
  ],
};

/// Descriptor for `DhtValueFoundEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dhtValueFoundEventDescriptor = $convert.base64Decode(
    'ChJEaHRWYWx1ZUZvdW5kRXZlbnQSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAxSBX'
    'ZhbHVlEhcKB3BlZXJfaWQYAyABKAlSBnBlZXJJZA==');

@$core.Deprecated('Use dhtValueProvidedEventDescriptor instead')
const DhtValueProvidedEvent$json = {
  '1': 'DhtValueProvidedEvent',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
  ],
};

/// Descriptor for `DhtValueProvidedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dhtValueProvidedEventDescriptor = $convert.base64Decode(
    'ChVEaHRWYWx1ZVByb3ZpZGVkRXZlbnQSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKA'
    'xSBXZhbHVl');

@$core.Deprecated('Use pubsubMessagePublishedEventDescriptor instead')
const PubsubMessagePublishedEvent$json = {
  '1': 'PubsubMessagePublishedEvent',
  '2': [
    {'1': 'topic', '3': 1, '4': 1, '5': 9, '10': 'topic'},
    {'1': 'message_content', '3': 2, '4': 1, '5': 12, '10': 'messageContent'},
  ],
};

/// Descriptor for `PubsubMessagePublishedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pubsubMessagePublishedEventDescriptor = $convert.base64Decode(
    'ChtQdWJzdWJNZXNzYWdlUHVibGlzaGVkRXZlbnQSFAoFdG9waWMYASABKAlSBXRvcGljEicKD2'
    '1lc3NhZ2VfY29udGVudBgCIAEoDFIObWVzc2FnZUNvbnRlbnQ=');

@$core.Deprecated('Use pubsubMessageReceivedEventDescriptor instead')
const PubsubMessageReceivedEvent$json = {
  '1': 'PubsubMessageReceivedEvent',
  '2': [
    {'1': 'topic', '3': 1, '4': 1, '5': 9, '10': 'topic'},
    {'1': 'message_content', '3': 2, '4': 1, '5': 12, '10': 'messageContent'},
    {'1': 'peer_id', '3': 3, '4': 1, '5': 9, '10': 'peerId'},
  ],
};

/// Descriptor for `PubsubMessageReceivedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pubsubMessageReceivedEventDescriptor = $convert.base64Decode(
    'ChpQdWJzdWJNZXNzYWdlUmVjZWl2ZWRFdmVudBIUCgV0b3BpYxgBIAEoCVIFdG9waWMSJwoPbW'
    'Vzc2FnZV9jb250ZW50GAIgASgMUg5tZXNzYWdlQ29udGVudBIXCgdwZWVyX2lkGAMgASgJUgZw'
    'ZWVySWQ=');

@$core.Deprecated('Use pubsubSubscriptionCreatedEventDescriptor instead')
const PubsubSubscriptionCreatedEvent$json = {
  '1': 'PubsubSubscriptionCreatedEvent',
  '2': [
    {'1': 'topic', '3': 1, '4': 1, '5': 9, '10': 'topic'},
  ],
};

/// Descriptor for `PubsubSubscriptionCreatedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pubsubSubscriptionCreatedEventDescriptor = $convert.base64Decode(
    'Ch5QdWJzdWJTdWJzY3JpcHRpb25DcmVhdGVkRXZlbnQSFAoFdG9waWMYASABKAlSBXRvcGlj');

@$core.Deprecated('Use pubsubSubscriptionCancelledEventDescriptor instead')
const PubsubSubscriptionCancelledEvent$json = {
  '1': 'PubsubSubscriptionCancelledEvent',
  '2': [
    {'1': 'topic', '3': 1, '4': 1, '5': 9, '10': 'topic'},
  ],
};

/// Descriptor for `PubsubSubscriptionCancelledEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pubsubSubscriptionCancelledEventDescriptor = $convert.base64Decode(
    'CiBQdWJzdWJTdWJzY3JpcHRpb25DYW5jZWxsZWRFdmVudBIUCgV0b3BpYxgBIAEoCVIFdG9waW'
    'M=');

@$core.Deprecated('Use circuitRelayCreatedEventDescriptor instead')
const CircuitRelayCreatedEvent$json = {
  '1': 'CircuitRelayCreatedEvent',
  '2': [
    {'1': 'relay_address', '3': 1, '4': 1, '5': 9, '10': 'relayAddress'},
  ],
};

/// Descriptor for `CircuitRelayCreatedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List circuitRelayCreatedEventDescriptor = $convert.base64Decode(
    'ChhDaXJjdWl0UmVsYXlDcmVhdGVkRXZlbnQSIwoNcmVsYXlfYWRkcmVzcxgBIAEoCVIMcmVsYX'
    'lBZGRyZXNz');

@$core.Deprecated('Use circuitRelayClosedEventDescriptor instead')
const CircuitRelayClosedEvent$json = {
  '1': 'CircuitRelayClosedEvent',
  '2': [
    {'1': 'relay_address', '3': 1, '4': 1, '5': 9, '10': 'relayAddress'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `CircuitRelayClosedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List circuitRelayClosedEventDescriptor = $convert.base64Decode(
    'ChdDaXJjdWl0UmVsYXlDbG9zZWRFdmVudBIjCg1yZWxheV9hZGRyZXNzGAEgASgJUgxyZWxheU'
    'FkZHJlc3MSFgoGcmVhc29uGAIgASgJUgZyZWFzb24=');

@$core.Deprecated('Use circuitRelayTrafficEventDescriptor instead')
const CircuitRelayTrafficEvent$json = {
  '1': 'CircuitRelayTrafficEvent',
  '2': [
    {'1': 'relay_address', '3': 1, '4': 1, '5': 9, '10': 'relayAddress'},
    {'1': 'data_size', '3': 2, '4': 1, '5': 3, '10': 'dataSize'},
  ],
};

/// Descriptor for `CircuitRelayTrafficEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List circuitRelayTrafficEventDescriptor = $convert.base64Decode(
    'ChhDaXJjdWl0UmVsYXlUcmFmZmljRXZlbnQSIwoNcmVsYXlfYWRkcmVzcxgBIAEoCVIMcmVsYX'
    'lBZGRyZXNzEhsKCWRhdGFfc2l6ZRgCIAEoA1IIZGF0YVNpemU=');

@$core.Deprecated('Use nodeStartedEventDescriptor instead')
const NodeStartedEvent$json = {
  '1': 'NodeStartedEvent',
};

/// Descriptor for `NodeStartedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeStartedEventDescriptor = $convert.base64Decode(
    'ChBOb2RlU3RhcnRlZEV2ZW50');

@$core.Deprecated('Use nodeStoppedEventDescriptor instead')
const NodeStoppedEvent$json = {
  '1': 'NodeStoppedEvent',
};

/// Descriptor for `NodeStoppedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeStoppedEventDescriptor = $convert.base64Decode(
    'ChBOb2RlU3RvcHBlZEV2ZW50');

@$core.Deprecated('Use errorEventDescriptor instead')
const ErrorEvent$json = {
  '1': 'ErrorEvent',
  '2': [
    {'1': 'error_type', '3': 1, '4': 1, '5': 9, '10': 'errorType'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'stack_trace', '3': 3, '4': 1, '5': 9, '10': 'stackTrace'},
  ],
};

/// Descriptor for `ErrorEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorEventDescriptor = $convert.base64Decode(
    'CgpFcnJvckV2ZW50Eh0KCmVycm9yX3R5cGUYASABKAlSCWVycm9yVHlwZRIYCgdtZXNzYWdlGA'
    'IgASgJUgdtZXNzYWdlEh8KC3N0YWNrX3RyYWNlGAMgASgJUgpzdGFja1RyYWNl');

@$core.Deprecated('Use networkChangedEventDescriptor instead')
const NetworkChangedEvent$json = {
  '1': 'NetworkChangedEvent',
};

/// Descriptor for `NetworkChangedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List networkChangedEventDescriptor = $convert.base64Decode(
    'ChNOZXR3b3JrQ2hhbmdlZEV2ZW50');
