// This is a generated file - do not edit.
//
// Generated from core/peer.proto.

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

@$core.Deprecated('Use peerProtoDescriptor instead')
const PeerProto$json = {
  '1': 'PeerProto',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'addresses', '3': 2, '4': 3, '5': 9, '10': 'addresses'},
    {'1': 'latency', '3': 3, '4': 1, '5': 3, '10': 'latency'},
    {'1': 'agent_version', '3': 4, '4': 1, '5': 9, '10': 'agentVersion'},
  ],
};

/// Descriptor for `PeerProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerProtoDescriptor = $convert
    .base64Decode('CglQZWVyUHJvdG8SDgoCaWQYASABKAlSAmlkEhwKCWFkZHJlc3NlcxgCIAMoCVIJYWRkcmVzc2'
        'VzEhgKB2xhdGVuY3kYAyABKANSB2xhdGVuY3kSIwoNYWdlbnRfdmVyc2lvbhgEIAEoCVIMYWdl'
        'bnRWZXJzaW9u');
