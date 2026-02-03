// This is a generated file - do not edit.
//
// Generated from dht/ipfs_node_network_events.proto.

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

@$core.Deprecated('Use networkEventDescriptor instead')
const NetworkEvent$json = {
  '1': 'NetworkEvent',
  '2': [
    {
      '1': 'peer_connected',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.PeerConnectedEvent',
      '9': 0,
      '10': 'peerConnected'
    },
    {
      '1': 'peer_disconnected',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.PeerDisconnectedEvent',
      '9': 0,
      '10': 'peerDisconnected'
    },
    {
      '1': 'connection_attempted',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.ConnectionAttemptedEvent',
      '9': 0,
      '10': 'connectionAttempted'
    },
    {
      '1': 'connection_failed',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.ConnectionFailedEvent',
      '9': 0,
      '10': 'connectionFailed'
    },
    {
      '1': 'message_received',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.MessageReceivedEvent',
      '9': 0,
      '10': 'messageReceived'
    },
    {
      '1': 'message_sent',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.MessageSentEvent',
      '9': 0,
      '10': 'messageSent'
    },
    {
      '1': 'block_received',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.BlockReceivedEvent',
      '9': 0,
      '10': 'blockReceived'
    },
    {
      '1': 'block_sent',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.BlockSentEvent',
      '9': 0,
      '10': 'blockSent'
    },
    {
      '1': 'dht_query_started',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.DHTQueryStartedEvent',
      '9': 0,
      '10': 'dhtQueryStarted'
    },
    {
      '1': 'dht_query_completed',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.DHTQueryCompletedEvent',
      '9': 0,
      '10': 'dhtQueryCompleted'
    },
    {
      '1': 'dht_value_found',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.DHTValueFoundEvent',
      '9': 0,
      '10': 'dhtValueFound'
    },
    {
      '1': 'dht_value_provided',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.DHTValueProvidedEvent',
      '9': 0,
      '10': 'dhtValueProvided'
    },
    {
      '1': 'dht_value_not_found',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.DHTValueNotFoundEvent',
      '9': 0,
      '10': 'dhtValueNotFound'
    },
    {
      '1': 'pubsub_message_published',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.PubsubMessagePublishedEvent',
      '9': 0,
      '10': 'pubsubMessagePublished'
    },
    {
      '1': 'pubsub_message_received',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.PubsubMessageReceivedEvent',
      '9': 0,
      '10': 'pubsubMessageReceived'
    },
    {
      '1': 'pubsub_subscription_created',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.PubsubSubscriptionCreatedEvent',
      '9': 0,
      '10': 'pubsubSubscriptionCreated'
    },
    {
      '1': 'pubsub_subscription_cancelled',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.PubsubSubscriptionCancelledEvent',
      '9': 0,
      '10': 'pubsubSubscriptionCancelled'
    },
    {
      '1': 'circuit_relay_created',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.CircuitRelayCreatedEvent',
      '9': 0,
      '10': 'circuitRelayCreated'
    },
    {
      '1': 'circuit_relay_closed',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.CircuitRelayClosedEvent',
      '9': 0,
      '10': 'circuitRelayClosed'
    },
    {
      '1': 'circuit_relay_traffic',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.CircuitRelayTrafficEvent',
      '9': 0,
      '10': 'circuitRelayTraffic'
    },
    {
      '1': 'circuit_relay_failed',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.CircuitRelayFailedEvent',
      '9': 0,
      '10': 'circuitRelayFailed'
    },
    {
      '1': 'node_started',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.NodeStartedEvent',
      '9': 0,
      '10': 'nodeStarted'
    },
    {
      '1': 'node_stopped',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.NodeStoppedEvent',
      '9': 0,
      '10': 'nodeStopped'
    },
    {
      '1': 'error',
      '3': 24,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.NodeErrorEvent',
      '9': 0,
      '10': 'error'
    },
    {
      '1': 'network_changed',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.NetworkStatusChangedEvent',
      '9': 0,
      '10': 'networkChanged'
    },
    {
      '1': 'dht_provider_added',
      '3': 26,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.DHTProviderAddedEvent',
      '9': 0,
      '10': 'dhtProviderAdded'
    },
    {
      '1': 'dht_provider_queried',
      '3': 27,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.DHTProviderQueriedEvent',
      '9': 0,
      '10': 'dhtProviderQueried'
    },
    {
      '1': 'stream_started',
      '3': 28,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.StreamStartedEvent',
      '9': 0,
      '10': 'streamStarted'
    },
    {
      '1': 'stream_ended',
      '3': 29,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.StreamEndedEvent',
      '9': 0,
      '10': 'streamEnded'
    },
    {
      '1': 'peer_discovered',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.PeerDiscoveredEvent',
      '9': 0,
      '10': 'peerDiscovered'
    },
    {
      '1': 'circuit_relay_data_received',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.CircuitRelayDataReceivedEvent',
      '9': 0,
      '10': 'circuitRelayDataReceived'
    },
    {
      '1': 'circuit_relay_data_sent',
      '3': 32,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.CircuitRelayDataSentEvent',
      '9': 0,
      '10': 'circuitRelayDataSent'
    },
    {
      '1': 'resource_limit_exceeded',
      '3': 33,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.ResourceLimitExceededEvent',
      '9': 0,
      '10': 'resourceLimitExceeded'
    },
    {
      '1': 'system_alert',
      '3': 34,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.ipfs_node.SystemAlertEvent',
      '9': 0,
      '10': 'systemAlert'
    },
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
    'IpLmlwZnMuY29yZS5pcGZzX25vZGUuREhUUXVlcnlTdGFydGVkRXZlbnRIAFIPZGh0UXVlcnlT'
    'dGFydGVkEl0KE2RodF9xdWVyeV9jb21wbGV0ZWQYCiABKAsyKy5pcGZzLmNvcmUuaXBmc19ub2'
    'RlLkRIVFF1ZXJ5Q29tcGxldGVkRXZlbnRIAFIRZGh0UXVlcnlDb21wbGV0ZWQSUQoPZGh0X3Zh'
    'bHVlX2ZvdW5kGAsgASgLMicuaXBmcy5jb3JlLmlwZnNfbm9kZS5ESFRWYWx1ZUZvdW5kRXZlbn'
    'RIAFINZGh0VmFsdWVGb3VuZBJaChJkaHRfdmFsdWVfcHJvdmlkZWQYDCABKAsyKi5pcGZzLmNv'
    'cmUuaXBmc19ub2RlLkRIVFZhbHVlUHJvdmlkZWRFdmVudEgAUhBkaHRWYWx1ZVByb3ZpZGVkEl'
    'sKE2RodF92YWx1ZV9ub3RfZm91bmQYDSABKAsyKi5pcGZzLmNvcmUuaXBmc19ub2RlLkRIVFZh'
    'bHVlTm90Rm91bmRFdmVudEgAUhBkaHRWYWx1ZU5vdEZvdW5kEmwKGHB1YnN1Yl9tZXNzYWdlX3'
    'B1Ymxpc2hlZBgOIAEoCzIwLmlwZnMuY29yZS5pcGZzX25vZGUuUHVic3ViTWVzc2FnZVB1Ymxp'
    'c2hlZEV2ZW50SABSFnB1YnN1Yk1lc3NhZ2VQdWJsaXNoZWQSaQoXcHVic3ViX21lc3NhZ2Vfcm'
    'VjZWl2ZWQYDyABKAsyLy5pcGZzLmNvcmUuaXBmc19ub2RlLlB1YnN1Yk1lc3NhZ2VSZWNlaXZl'
    'ZEV2ZW50SABSFXB1YnN1Yk1lc3NhZ2VSZWNlaXZlZBJ1ChtwdWJzdWJfc3Vic2NyaXB0aW9uX2'
    'NyZWF0ZWQYECABKAsyMy5pcGZzLmNvcmUuaXBmc19ub2RlLlB1YnN1YlN1YnNjcmlwdGlvbkNy'
    'ZWF0ZWRFdmVudEgAUhlwdWJzdWJTdWJzY3JpcHRpb25DcmVhdGVkEnsKHXB1YnN1Yl9zdWJzY3'
    'JpcHRpb25fY2FuY2VsbGVkGBEgASgLMjUuaXBmcy5jb3JlLmlwZnNfbm9kZS5QdWJzdWJTdWJz'
    'Y3JpcHRpb25DYW5jZWxsZWRFdmVudEgAUhtwdWJzdWJTdWJzY3JpcHRpb25DYW5jZWxsZWQSYw'
    'oVY2lyY3VpdF9yZWxheV9jcmVhdGVkGBIgASgLMi0uaXBmcy5jb3JlLmlwZnNfbm9kZS5DaXJj'
    'dWl0UmVsYXlDcmVhdGVkRXZlbnRIAFITY2lyY3VpdFJlbGF5Q3JlYXRlZBJgChRjaXJjdWl0X3'
    'JlbGF5X2Nsb3NlZBgTIAEoCzIsLmlwZnMuY29yZS5pcGZzX25vZGUuQ2lyY3VpdFJlbGF5Q2xv'
    'c2VkRXZlbnRIAFISY2lyY3VpdFJlbGF5Q2xvc2VkEmMKFWNpcmN1aXRfcmVsYXlfdHJhZmZpYx'
    'gUIAEoCzItLmlwZnMuY29yZS5pcGZzX25vZGUuQ2lyY3VpdFJlbGF5VHJhZmZpY0V2ZW50SABS'
    'E2NpcmN1aXRSZWxheVRyYWZmaWMSYAoUY2lyY3VpdF9yZWxheV9mYWlsZWQYFSABKAsyLC5pcG'
    'ZzLmNvcmUuaXBmc19ub2RlLkNpcmN1aXRSZWxheUZhaWxlZEV2ZW50SABSEmNpcmN1aXRSZWxh'
    'eUZhaWxlZBJKCgxub2RlX3N0YXJ0ZWQYFiABKAsyJS5pcGZzLmNvcmUuaXBmc19ub2RlLk5vZG'
    'VTdGFydGVkRXZlbnRIAFILbm9kZVN0YXJ0ZWQSSgoMbm9kZV9zdG9wcGVkGBcgASgLMiUuaXBm'
    'cy5jb3JlLmlwZnNfbm9kZS5Ob2RlU3RvcHBlZEV2ZW50SABSC25vZGVTdG9wcGVkEjsKBWVycm'
    '9yGBggASgLMiMuaXBmcy5jb3JlLmlwZnNfbm9kZS5Ob2RlRXJyb3JFdmVudEgAUgVlcnJvchJZ'
    'Cg9uZXR3b3JrX2NoYW5nZWQYGSABKAsyLi5pcGZzLmNvcmUuaXBmc19ub2RlLk5ldHdvcmtTdG'
    'F0dXNDaGFuZ2VkRXZlbnRIAFIObmV0d29ya0NoYW5nZWQSWgoSZGh0X3Byb3ZpZGVyX2FkZGVk'
    'GBogASgLMiouaXBmcy5jb3JlLmlwZnNfbm9kZS5ESFRQcm92aWRlckFkZGVkRXZlbnRIAFIQZG'
    'h0UHJvdmlkZXJBZGRlZBJgChRkaHRfcHJvdmlkZXJfcXVlcmllZBgbIAEoCzIsLmlwZnMuY29y'
    'ZS5pcGZzX25vZGUuREhUUHJvdmlkZXJRdWVyaWVkRXZlbnRIAFISZGh0UHJvdmlkZXJRdWVyaW'
    'VkElAKDnN0cmVhbV9zdGFydGVkGBwgASgLMicuaXBmcy5jb3JlLmlwZnNfbm9kZS5TdHJlYW1T'
    'dGFydGVkRXZlbnRIAFINc3RyZWFtU3RhcnRlZBJKCgxzdHJlYW1fZW5kZWQYHSABKAsyJS5pcG'
    'ZzLmNvcmUuaXBmc19ub2RlLlN0cmVhbUVuZGVkRXZlbnRIAFILc3RyZWFtRW5kZWQSUwoPcGVl'
    'cl9kaXNjb3ZlcmVkGB4gASgLMiguaXBmcy5jb3JlLmlwZnNfbm9kZS5QZWVyRGlzY292ZXJlZE'
    'V2ZW50SABSDnBlZXJEaXNjb3ZlcmVkEnMKG2NpcmN1aXRfcmVsYXlfZGF0YV9yZWNlaXZlZBgf'
    'IAEoCzIyLmlwZnMuY29yZS5pcGZzX25vZGUuQ2lyY3VpdFJlbGF5RGF0YVJlY2VpdmVkRXZlbn'
    'RIAFIYY2lyY3VpdFJlbGF5RGF0YVJlY2VpdmVkEmcKF2NpcmN1aXRfcmVsYXlfZGF0YV9zZW50'
    'GCAgASgLMi4uaXBmcy5jb3JlLmlwZnNfbm9kZS5DaXJjdWl0UmVsYXlEYXRhU2VudEV2ZW50SA'
    'BSFGNpcmN1aXRSZWxheURhdGFTZW50EmkKF3Jlc291cmNlX2xpbWl0X2V4Y2VlZGVkGCEgASgL'
    'Mi8uaXBmcy5jb3JlLmlwZnNfbm9kZS5SZXNvdXJjZUxpbWl0RXhjZWVkZWRFdmVudEgAUhVyZX'
    'NvdXJjZUxpbWl0RXhjZWVkZWQSSgoMc3lzdGVtX2FsZXJ0GCIgASgLMiUuaXBmcy5jb3JlLmlw'
    'ZnNfbm9kZS5TeXN0ZW1BbGVydEV2ZW50SABSC3N5c3RlbUFsZXJ0QgcKBWV2ZW50');

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
final $typed_data.Uint8List connectionAttemptedEventDescriptor =
    $convert.base64Decode(
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

@$core.Deprecated('Use dHTQueryStartedEventDescriptor instead')
const DHTQueryStartedEvent$json = {
  '1': 'DHTQueryStartedEvent',
  '2': [
    {'1': 'query_type', '3': 1, '4': 1, '5': 9, '10': 'queryType'},
    {'1': 'target_key', '3': 2, '4': 1, '5': 9, '10': 'targetKey'},
  ],
};

/// Descriptor for `DHTQueryStartedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dHTQueryStartedEventDescriptor = $convert.base64Decode(
    'ChRESFRRdWVyeVN0YXJ0ZWRFdmVudBIdCgpxdWVyeV90eXBlGAEgASgJUglxdWVyeVR5cGUSHQ'
    'oKdGFyZ2V0X2tleRgCIAEoCVIJdGFyZ2V0S2V5');

@$core.Deprecated('Use dHTQueryCompletedEventDescriptor instead')
const DHTQueryCompletedEvent$json = {
  '1': 'DHTQueryCompletedEvent',
  '2': [
    {'1': 'query_type', '3': 1, '4': 1, '5': 9, '10': 'queryType'},
    {'1': 'target_key', '3': 2, '4': 1, '5': 9, '10': 'targetKey'},
    {'1': 'results', '3': 3, '4': 3, '5': 9, '10': 'results'},
  ],
};

/// Descriptor for `DHTQueryCompletedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dHTQueryCompletedEventDescriptor = $convert.base64Decode(
    'ChZESFRRdWVyeUNvbXBsZXRlZEV2ZW50Eh0KCnF1ZXJ5X3R5cGUYASABKAlSCXF1ZXJ5VHlwZR'
    'IdCgp0YXJnZXRfa2V5GAIgASgJUgl0YXJnZXRLZXkSGAoHcmVzdWx0cxgDIAMoCVIHcmVzdWx0'
    'cw==');

@$core.Deprecated('Use dHTValueFoundEventDescriptor instead')
const DHTValueFoundEvent$json = {
  '1': 'DHTValueFoundEvent',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
    {'1': 'peer_id', '3': 3, '4': 1, '5': 9, '10': 'peerId'},
  ],
};

/// Descriptor for `DHTValueFoundEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dHTValueFoundEventDescriptor = $convert.base64Decode(
    'ChJESFRWYWx1ZUZvdW5kRXZlbnQSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAxSBX'
    'ZhbHVlEhcKB3BlZXJfaWQYAyABKAlSBnBlZXJJZA==');

@$core.Deprecated('Use dHTValueNotFoundEventDescriptor instead')
const DHTValueNotFoundEvent$json = {
  '1': 'DHTValueNotFoundEvent',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
  ],
};

/// Descriptor for `DHTValueNotFoundEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dHTValueNotFoundEventDescriptor = $convert
    .base64Decode('ChVESFRWYWx1ZU5vdEZvdW5kRXZlbnQSEAoDa2V5GAEgASgJUgNrZXk=');

@$core.Deprecated('Use dHTValueProvidedEventDescriptor instead')
const DHTValueProvidedEvent$json = {
  '1': 'DHTValueProvidedEvent',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
  ],
};

/// Descriptor for `DHTValueProvidedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dHTValueProvidedEventDescriptor = $convert.base64Decode(
    'ChVESFRWYWx1ZVByb3ZpZGVkRXZlbnQSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKA'
    'xSBXZhbHVl');

@$core.Deprecated('Use dHTProviderAddedEventDescriptor instead')
const DHTProviderAddedEvent$json = {
  '1': 'DHTProviderAddedEvent',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'peer_id', '3': 2, '4': 1, '5': 9, '10': 'peerId'},
  ],
};

/// Descriptor for `DHTProviderAddedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dHTProviderAddedEventDescriptor = $convert.base64Decode(
    'ChVESFRQcm92aWRlckFkZGVkRXZlbnQSEAoDa2V5GAEgASgJUgNrZXkSFwoHcGVlcl9pZBgCIA'
    'EoCVIGcGVlcklk');

@$core.Deprecated('Use dHTProviderQueriedEventDescriptor instead')
const DHTProviderQueriedEvent$json = {
  '1': 'DHTProviderQueriedEvent',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'providers', '3': 2, '4': 3, '5': 9, '10': 'providers'},
  ],
};

/// Descriptor for `DHTProviderQueriedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dHTProviderQueriedEventDescriptor =
    $convert.base64Decode(
        'ChdESFRQcm92aWRlclF1ZXJpZWRFdmVudBIQCgNrZXkYASABKAlSA2tleRIcCglwcm92aWRlcn'
        'MYAiADKAlSCXByb3ZpZGVycw==');

@$core.Deprecated('Use pubsubMessagePublishedEventDescriptor instead')
const PubsubMessagePublishedEvent$json = {
  '1': 'PubsubMessagePublishedEvent',
  '2': [
    {'1': 'topic', '3': 1, '4': 1, '5': 9, '10': 'topic'},
    {'1': 'message_content', '3': 2, '4': 1, '5': 12, '10': 'messageContent'},
  ],
};

/// Descriptor for `PubsubMessagePublishedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pubsubMessagePublishedEventDescriptor =
    $convert.base64Decode(
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
final $typed_data.Uint8List pubsubMessageReceivedEventDescriptor =
    $convert.base64Decode(
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
final $typed_data.Uint8List pubsubSubscriptionCreatedEventDescriptor =
    $convert.base64Decode(
        'Ch5QdWJzdWJTdWJzY3JpcHRpb25DcmVhdGVkRXZlbnQSFAoFdG9waWMYASABKAlSBXRvcGlj');

@$core.Deprecated('Use pubsubSubscriptionCancelledEventDescriptor instead')
const PubsubSubscriptionCancelledEvent$json = {
  '1': 'PubsubSubscriptionCancelledEvent',
  '2': [
    {'1': 'topic', '3': 1, '4': 1, '5': 9, '10': 'topic'},
  ],
};

/// Descriptor for `PubsubSubscriptionCancelledEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pubsubSubscriptionCancelledEventDescriptor =
    $convert.base64Decode(
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
final $typed_data.Uint8List circuitRelayCreatedEventDescriptor =
    $convert.base64Decode(
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
final $typed_data.Uint8List circuitRelayClosedEventDescriptor =
    $convert.base64Decode(
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
final $typed_data.Uint8List circuitRelayTrafficEventDescriptor =
    $convert.base64Decode(
        'ChhDaXJjdWl0UmVsYXlUcmFmZmljRXZlbnQSIwoNcmVsYXlfYWRkcmVzcxgBIAEoCVIMcmVsYX'
        'lBZGRyZXNzEhsKCWRhdGFfc2l6ZRgCIAEoA1IIZGF0YVNpemU=');

@$core.Deprecated('Use circuitRelayDataReceivedEventDescriptor instead')
const CircuitRelayDataReceivedEvent$json = {
  '1': 'CircuitRelayDataReceivedEvent',
  '2': [
    {'1': 'relay_address', '3': 1, '4': 1, '5': 9, '10': 'relayAddress'},
    {'1': 'data_size', '3': 2, '4': 1, '5': 3, '10': 'dataSize'},
  ],
};

/// Descriptor for `CircuitRelayDataReceivedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List circuitRelayDataReceivedEventDescriptor =
    $convert.base64Decode(
        'Ch1DaXJjdWl0UmVsYXlEYXRhUmVjZWl2ZWRFdmVudBIjCg1yZWxheV9hZGRyZXNzGAEgASgJUg'
        'xyZWxheUFkZHJlc3MSGwoJZGF0YV9zaXplGAIgASgDUghkYXRhU2l6ZQ==');

@$core.Deprecated('Use circuitRelayDataSentEventDescriptor instead')
const CircuitRelayDataSentEvent$json = {
  '1': 'CircuitRelayDataSentEvent',
  '2': [
    {'1': 'relay_address', '3': 1, '4': 1, '5': 9, '10': 'relayAddress'},
    {'1': 'data_size', '3': 2, '4': 1, '5': 3, '10': 'dataSize'},
  ],
};

/// Descriptor for `CircuitRelayDataSentEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List circuitRelayDataSentEventDescriptor =
    $convert.base64Decode(
        'ChlDaXJjdWl0UmVsYXlEYXRhU2VudEV2ZW50EiMKDXJlbGF5X2FkZHJlc3MYASABKAlSDHJlbG'
        'F5QWRkcmVzcxIbCglkYXRhX3NpemUYAiABKANSCGRhdGFTaXpl');

@$core.Deprecated('Use circuitRelayFailedEventDescriptor instead')
const CircuitRelayFailedEvent$json = {
  '1': 'CircuitRelayFailedEvent',
  '2': [
    {'1': 'relay_address', '3': 1, '4': 1, '5': 9, '10': 'relayAddress'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `CircuitRelayFailedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List circuitRelayFailedEventDescriptor =
    $convert.base64Decode(
        'ChdDaXJjdWl0UmVsYXlGYWlsZWRFdmVudBIjCg1yZWxheV9hZGRyZXNzGAEgASgJUgxyZWxheU'
        'FkZHJlc3MSFgoGcmVhc29uGAIgASgJUgZyZWFzb24=');

@$core.Deprecated('Use streamStartedEventDescriptor instead')
const StreamStartedEvent$json = {
  '1': 'StreamStartedEvent',
  '2': [
    {'1': 'stream_id', '3': 1, '4': 1, '5': 9, '10': 'streamId'},
    {'1': 'peer_id', '3': 2, '4': 1, '5': 9, '10': 'peerId'},
  ],
};

/// Descriptor for `StreamStartedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamStartedEventDescriptor = $convert.base64Decode(
    'ChJTdHJlYW1TdGFydGVkRXZlbnQSGwoJc3RyZWFtX2lkGAEgASgJUghzdHJlYW1JZBIXCgdwZW'
    'VyX2lkGAIgASgJUgZwZWVySWQ=');

@$core.Deprecated('Use streamEndedEventDescriptor instead')
const StreamEndedEvent$json = {
  '1': 'StreamEndedEvent',
  '2': [
    {'1': 'stream_id', '3': 1, '4': 1, '5': 9, '10': 'streamId'},
    {'1': 'peer_id', '3': 2, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'reason', '3': 3, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `StreamEndedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamEndedEventDescriptor = $convert.base64Decode(
    'ChBTdHJlYW1FbmRlZEV2ZW50EhsKCXN0cmVhbV9pZBgBIAEoCVIIc3RyZWFtSWQSFwoHcGVlcl'
    '9pZBgCIAEoCVIGcGVlcklkEhYKBnJlYXNvbhgDIAEoCVIGcmVhc29u');

@$core.Deprecated('Use peerDiscoveredEventDescriptor instead')
const PeerDiscoveredEvent$json = {
  '1': 'PeerDiscoveredEvent',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
  ],
};

/// Descriptor for `PeerDiscoveredEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerDiscoveredEventDescriptor =
    $convert.base64Decode(
        'ChNQZWVyRGlzY292ZXJlZEV2ZW50EhcKB3BlZXJfaWQYASABKAlSBnBlZXJJZA==');

@$core.Deprecated('Use nodeStartedEventDescriptor instead')
const NodeStartedEvent$json = {
  '1': 'NodeStartedEvent',
};

/// Descriptor for `NodeStartedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeStartedEventDescriptor =
    $convert.base64Decode('ChBOb2RlU3RhcnRlZEV2ZW50');

@$core.Deprecated('Use nodeStoppedEventDescriptor instead')
const NodeStoppedEvent$json = {
  '1': 'NodeStoppedEvent',
};

/// Descriptor for `NodeStoppedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeStoppedEventDescriptor =
    $convert.base64Decode('ChBOb2RlU3RvcHBlZEV2ZW50');

@$core.Deprecated('Use nodeErrorEventDescriptor instead')
const NodeErrorEvent$json = {
  '1': 'NodeErrorEvent',
  '2': [
    {
      '1': 'error_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.ipfs.core.ipfs_node.NodeErrorEvent.ErrorType',
      '10': 'errorType'
    },
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'stack_trace', '3': 3, '4': 1, '5': 9, '10': 'stackTrace'},
    {'1': 'source', '3': 4, '4': 1, '5': 9, '10': 'source'},
  ],
  '4': [NodeErrorEvent_ErrorType$json],
};

@$core.Deprecated('Use nodeErrorEventDescriptor instead')
const NodeErrorEvent_ErrorType$json = {
  '1': 'ErrorType',
  '2': [
    {'1': 'UNKNOWN', '2': 0},
    {'1': 'INVALID_REQUEST', '2': 1},
    {'1': 'NOT_FOUND', '2': 2},
    {'1': 'METHOD_NOT_FOUND', '2': 3},
    {'1': 'INTERNAL_ERROR', '2': 4},
    {'1': 'NETWORK', '2': 5},
    {'1': 'PROTOCOL', '2': 6},
    {'1': 'SECURITY', '2': 7},
    {'1': 'DATASTORE', '2': 8},
  ],
};

/// Descriptor for `NodeErrorEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeErrorEventDescriptor = $convert.base64Decode(
    'Cg5Ob2RlRXJyb3JFdmVudBJMCgplcnJvcl90eXBlGAEgASgOMi0uaXBmcy5jb3JlLmlwZnNfbm'
    '9kZS5Ob2RlRXJyb3JFdmVudC5FcnJvclR5cGVSCWVycm9yVHlwZRIYCgdtZXNzYWdlGAIgASgJ'
    'UgdtZXNzYWdlEh8KC3N0YWNrX3RyYWNlGAMgASgJUgpzdGFja1RyYWNlEhYKBnNvdXJjZRgEIA'
    'EoCVIGc291cmNlIp4BCglFcnJvclR5cGUSCwoHVU5LTk9XThAAEhMKD0lOVkFMSURfUkVRVUVT'
    'VBABEg0KCU5PVF9GT1VORBACEhQKEE1FVEhPRF9OT1RfRk9VTkQQAxISCg5JTlRFUk5BTF9FUl'
    'JPUhAEEgsKB05FVFdPUksQBRIMCghQUk9UT0NPTBAGEgwKCFNFQ1VSSVRZEAcSDQoJREFUQVNU'
    'T1JFEAg=');

@$core.Deprecated('Use networkStatusChangedEventDescriptor instead')
const NetworkStatusChangedEvent$json = {
  '1': 'NetworkStatusChangedEvent',
  '2': [
    {
      '1': 'change_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.ipfs.core.ipfs_node.NetworkStatusChangedEvent.ChangeType',
      '10': 'changeType'
    },
  ],
  '4': [NetworkStatusChangedEvent_ChangeType$json],
};

@$core.Deprecated('Use networkStatusChangedEventDescriptor instead')
const NetworkStatusChangedEvent_ChangeType$json = {
  '1': 'ChangeType',
  '2': [
    {'1': 'UNKNOWN', '2': 0},
    {'1': 'ONLINE', '2': 1},
    {'1': 'OFFLINE', '2': 2},
    {'1': 'CONNECTIVITY_CHANGED', '2': 3},
    {'1': 'SWARM_PEER_JOINED', '2': 4},
    {'1': 'SWARM_PEER_LEFT', '2': 5},
    {'1': 'NODE_STARTED', '2': 6},
    {'1': 'NODE_STOPPED', '2': 7},
    {'1': 'INTERFACE_ADDED', '2': 8},
    {'1': 'INTERFACE_REMOVED', '2': 9},
    {'1': 'INTERFACE_UP', '2': 10},
    {'1': 'INTERFACE_DOWN', '2': 11},
    {'1': 'IP_ADDRESS_CHANGED', '2': 12},
    {'1': 'IP_ADDRESS_ADDED', '2': 13},
    {'1': 'IP_ADDRESS_REMOVED', '2': 14},
    {'1': 'GATEWAY_CHANGED', '2': 15},
    {'1': 'GATEWAY_REACHABLE', '2': 16},
    {'1': 'GATEWAY_UNREACHABLE', '2': 17},
    {'1': 'FIREWALL_CHANGED', '2': 18},
    {'1': 'FIREWALL_BLOCKING', '2': 19},
    {'1': 'FIREWALL_ALLOWING', '2': 20},
    {'1': 'NAT_TYPE_CHANGED', '2': 21},
    {'1': 'NAT_PORT_MAPPING_CHANGED', '2': 22},
    {'1': 'DNS_RESOLVED', '2': 23},
    {'1': 'DNS_FAILED', '2': 24},
    {'1': 'EXTERNAL_ADDRESS_CHANGED', '2': 25},
    {'1': 'BANDWIDTH_CHANGED', '2': 26},
    {'1': 'ROUTING_CHANGED', '2': 27},
    {'1': 'CONTENT_ROUTING_CHANGED', '2': 28},
    {'1': 'PEER_ROUTING_CHANGED', '2': 29},
    {'1': 'CONNECTION_UPGRADED', '2': 30},
    {'1': 'CONNECTION_PRUNED', '2': 31},
    {'1': 'PROTOCOL_AVAILABLE', '2': 32},
    {'1': 'PROTOCOL_UNAVAILABLE', '2': 33},
  ],
};

/// Descriptor for `NetworkStatusChangedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List networkStatusChangedEventDescriptor = $convert.base64Decode(
    'ChlOZXR3b3JrU3RhdHVzQ2hhbmdlZEV2ZW50EloKC2NoYW5nZV90eXBlGAEgASgOMjkuaXBmcy'
    '5jb3JlLmlwZnNfbm9kZS5OZXR3b3JrU3RhdHVzQ2hhbmdlZEV2ZW50LkNoYW5nZVR5cGVSCmNo'
    'YW5nZVR5cGUi9gUKCkNoYW5nZVR5cGUSCwoHVU5LTk9XThAAEgoKBk9OTElORRABEgsKB09GRk'
    'xJTkUQAhIYChRDT05ORUNUSVZJVFlfQ0hBTkdFRBADEhUKEVNXQVJNX1BFRVJfSk9JTkVEEAQS'
    'EwoPU1dBUk1fUEVFUl9MRUZUEAUSEAoMTk9ERV9TVEFSVEVEEAYSEAoMTk9ERV9TVE9QUEVEEA'
    'cSEwoPSU5URVJGQUNFX0FEREVEEAgSFQoRSU5URVJGQUNFX1JFTU9WRUQQCRIQCgxJTlRFUkZB'
    'Q0VfVVAQChISCg5JTlRFUkZBQ0VfRE9XThALEhYKEklQX0FERFJFU1NfQ0hBTkdFRBAMEhQKEE'
    'lQX0FERFJFU1NfQURERUQQDRIWChJJUF9BRERSRVNTX1JFTU9WRUQQDhITCg9HQVRFV0FZX0NI'
    'QU5HRUQQDxIVChFHQVRFV0FZX1JFQUNIQUJMRRAQEhcKE0dBVEVXQVlfVU5SRUFDSEFCTEUQER'
    'IUChBGSVJFV0FMTF9DSEFOR0VEEBISFQoRRklSRVdBTExfQkxPQ0tJTkcQExIVChFGSVJFV0FM'
    'TF9BTExPV0lORxAUEhQKEE5BVF9UWVBFX0NIQU5HRUQQFRIcChhOQVRfUE9SVF9NQVBQSU5HX0'
    'NIQU5HRUQQFhIQCgxETlNfUkVTT0xWRUQQFxIOCgpETlNfRkFJTEVEEBgSHAoYRVhURVJOQUxf'
    'QUREUkVTU19DSEFOR0VEEBkSFQoRQkFORFdJRFRIX0NIQU5HRUQQGhITCg9ST1VUSU5HX0NIQU'
    '5HRUQQGxIbChdDT05URU5UX1JPVVRJTkdfQ0hBTkdFRBAcEhgKFFBFRVJfUk9VVElOR19DSEFO'
    'R0VEEB0SFwoTQ09OTkVDVElPTl9VUEdSQURFRBAeEhUKEUNPTk5FQ1RJT05fUFJVTkVEEB8SFg'
    'oSUFJPVE9DT0xfQVZBSUxBQkxFECASGAoUUFJPVE9DT0xfVU5BVkFJTEFCTEUQIQ==');

@$core.Deprecated('Use resourceLimitExceededEventDescriptor instead')
const ResourceLimitExceededEvent$json = {
  '1': 'ResourceLimitExceededEvent',
  '2': [
    {'1': 'resource_type', '3': 1, '4': 1, '5': 9, '10': 'resourceType'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `ResourceLimitExceededEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resourceLimitExceededEventDescriptor =
    $convert.base64Decode(
        'ChpSZXNvdXJjZUxpbWl0RXhjZWVkZWRFdmVudBIjCg1yZXNvdXJjZV90eXBlGAEgASgJUgxyZX'
        'NvdXJjZVR5cGUSGAoHbWVzc2FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use systemAlertEventDescriptor instead')
const SystemAlertEvent$json = {
  '1': 'SystemAlertEvent',
  '2': [
    {'1': 'alert_type', '3': 1, '4': 1, '5': 9, '10': 'alertType'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SystemAlertEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List systemAlertEventDescriptor = $convert.base64Decode(
    'ChBTeXN0ZW1BbGVydEV2ZW50Eh0KCmFsZXJ0X3R5cGUYASABKAlSCWFsZXJ0VHlwZRIYCgdtZX'
    'NzYWdlGAIgASgJUgdtZXNzYWdl');

