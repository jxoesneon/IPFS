// This is a generated file - do not edit.
//
// Generated from gossipsub.proto.

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

@$core.Deprecated('Use rPCDescriptor instead')
const RPC$json = {
  '1': 'RPC',
  '2': [
    {
      '1': 'subscriptions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.gossipsub.Subscription',
      '10': 'subscriptions'
    },
    {
      '1': 'publish',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.gossipsub.Message',
      '10': 'publish'
    },
    {
      '1': 'control',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.gossipsub.ControlMessage',
      '10': 'control'
    },
  ],
};

/// Descriptor for `RPC`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rPCDescriptor = $convert.base64Decode(
    'CgNSUEMSPQoNc3Vic2NyaXB0aW9ucxgBIAMoCzIXLmdvc3NpcHN1Yi5TdWJzY3JpcHRpb25SDX'
    'N1YnNjcmlwdGlvbnMSLAoHcHVibGlzaBgCIAMoCzISLmdvc3NpcHN1Yi5NZXNzYWdlUgdwdWJs'
    'aXNoEjMKB2NvbnRyb2wYAyABKAsyGS5nb3NzaXBzdWIuQ29udHJvbE1lc3NhZ2VSB2NvbnRyb2'
    'w=');

@$core.Deprecated('Use subscriptionDescriptor instead')
const Subscription$json = {
  '1': 'Subscription',
  '2': [
    {'1': 'subscribe', '3': 1, '4': 1, '5': 8, '10': 'subscribe'},
    {'1': 'topicid', '3': 2, '4': 1, '5': 9, '10': 'topicid'},
  ],
};

/// Descriptor for `Subscription`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscriptionDescriptor = $convert.base64Decode(
    'CgxTdWJzY3JpcHRpb24SHAoJc3Vic2NyaWJlGAEgASgIUglzdWJzY3JpYmUSGAoHdG9waWNpZB'
    'gCIAEoCVIHdG9waWNpZA==');

@$core.Deprecated('Use messageDescriptor instead')
const Message$json = {
  '1': 'Message',
  '2': [
    {'1': 'from', '3': 1, '4': 1, '5': 12, '10': 'from'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
    {'1': 'seqno', '3': 3, '4': 1, '5': 12, '10': 'seqno'},
    {'1': 'topic', '3': 4, '4': 1, '5': 9, '10': 'topic'},
    {'1': 'signature', '3': 5, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'key', '3': 6, '4': 1, '5': 12, '10': 'key'},
  ],
};

/// Descriptor for `Message`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageDescriptor = $convert.base64Decode(
    'CgdNZXNzYWdlEhIKBGZyb20YASABKAxSBGZyb20SEgoEZGF0YRgCIAEoDFIEZGF0YRIUCgVzZX'
    'FubxgDIAEoDFIFc2Vxbm8SFAoFdG9waWMYBCABKAlSBXRvcGljEhwKCXNpZ25hdHVyZRgFIAEo'
    'DFIJc2lnbmF0dXJlEhAKA2tleRgGIAEoDFIDa2V5');

@$core.Deprecated('Use controlMessageDescriptor instead')
const ControlMessage$json = {
  '1': 'ControlMessage',
  '2': [
    {
      '1': 'ihave',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.gossipsub.ControlIHave',
      '10': 'ihave'
    },
    {
      '1': 'iwant',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.gossipsub.ControlIWant',
      '10': 'iwant'
    },
    {
      '1': 'graft',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.gossipsub.ControlGraft',
      '10': 'graft'
    },
    {
      '1': 'prune',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.gossipsub.ControlPrune',
      '10': 'prune'
    },
  ],
};

/// Descriptor for `ControlMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controlMessageDescriptor = $convert.base64Decode(
    'Cg5Db250cm9sTWVzc2FnZRItCgVpaGF2ZRgBIAMoCzIXLmdvc3NpcHN1Yi5Db250cm9sSUhhdm'
    'VSBWloYXZlEi0KBWl3YW50GAIgAygLMhcuZ29zc2lwc3ViLkNvbnRyb2xJV2FudFIFaXdhbnQS'
    'LQoFZ3JhZnQYAyADKAsyFy5nb3NzaXBzdWIuQ29udHJvbEdyYWZ0UgVncmFmdBItCgVwcnVuZR'
    'gEIAMoCzIXLmdvc3NpcHN1Yi5Db250cm9sUHJ1bmVSBXBydW5l');

@$core.Deprecated('Use controlIHaveDescriptor instead')
const ControlIHave$json = {
  '1': 'ControlIHave',
  '2': [
    {'1': 'topicID', '3': 1, '4': 1, '5': 9, '10': 'topicID'},
    {'1': 'messageIDs', '3': 2, '4': 3, '5': 9, '10': 'messageIDs'},
  ],
};

/// Descriptor for `ControlIHave`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controlIHaveDescriptor = $convert.base64Decode(
    'CgxDb250cm9sSUhhdmUSGAoHdG9waWNJRBgBIAEoCVIHdG9waWNJRBIeCgptZXNzYWdlSURzGA'
    'IgAygJUgptZXNzYWdlSURz');

@$core.Deprecated('Use controlIWantDescriptor instead')
const ControlIWant$json = {
  '1': 'ControlIWant',
  '2': [
    {'1': 'messageIDs', '3': 1, '4': 3, '5': 9, '10': 'messageIDs'},
  ],
};

/// Descriptor for `ControlIWant`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controlIWantDescriptor = $convert.base64Decode(
    'CgxDb250cm9sSVdhbnQSHgoKbWVzc2FnZUlEcxgBIAMoCVIKbWVzc2FnZUlEcw==');

@$core.Deprecated('Use controlGraftDescriptor instead')
const ControlGraft$json = {
  '1': 'ControlGraft',
  '2': [
    {'1': 'topicID', '3': 1, '4': 1, '5': 9, '10': 'topicID'},
  ],
};

/// Descriptor for `ControlGraft`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controlGraftDescriptor = $convert
    .base64Decode('CgxDb250cm9sR3JhZnQSGAoHdG9waWNJRBgBIAEoCVIHdG9waWNJRA==');

@$core.Deprecated('Use controlPruneDescriptor instead')
const ControlPrune$json = {
  '1': 'ControlPrune',
  '2': [
    {'1': 'topicID', '3': 1, '4': 1, '5': 9, '10': 'topicID'},
    {
      '1': 'peers',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.gossipsub.PeerInfo',
      '10': 'peers'
    },
    {'1': 'backoff', '3': 3, '4': 1, '5': 4, '10': 'backoff'},
  ],
};

/// Descriptor for `ControlPrune`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controlPruneDescriptor = $convert.base64Decode(
    'CgxDb250cm9sUHJ1bmUSGAoHdG9waWNJRBgBIAEoCVIHdG9waWNJRBIpCgVwZWVycxgCIAMoCz'
    'ITLmdvc3NpcHN1Yi5QZWVySW5mb1IFcGVlcnMSGAoHYmFja29mZhgDIAEoBFIHYmFja29mZg==');

@$core.Deprecated('Use peerInfoDescriptor instead')
const PeerInfo$json = {
  '1': 'PeerInfo',
  '2': [
    {'1': 'peerID', '3': 1, '4': 1, '5': 12, '10': 'peerID'},
    {
      '1': 'signedPeerRecord',
      '3': 2,
      '4': 1,
      '5': 12,
      '10': 'signedPeerRecord'
    },
  ],
};

/// Descriptor for `PeerInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerInfoDescriptor = $convert.base64Decode(
    'CghQZWVySW5mbxIWCgZwZWVySUQYASABKAxSBnBlZXJJRBIqChBzaWduZWRQZWVyUmVjb3JkGA'
    'IgASgMUhBzaWduZWRQZWVyUmVjb3Jk');
