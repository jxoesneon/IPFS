//
//  Generated code. Do not modify.
//  source: circuit_relay.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use statusDescriptor instead')
const Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'OK', '2': 0},
    {'1': 'FAILED', '2': 1},
    {'1': 'HOP_SRC_ADDR_TOO_LONG', '2': 220},
    {'1': 'HOP_DST_ADDR_TOO_LONG', '2': 221},
    {'1': 'HOP_SRC_MULTIADDR_INVALID', '2': 222},
    {'1': 'HOP_DST_MULTIADDR_INVALID', '2': 223},
    {'1': 'HOP_NO_CONN_TO_DST', '2': 260},
    {'1': 'HOP_CANT_DIAL_DST', '2': 261},
    {'1': 'HOP_CANT_OPEN_DST_STREAM', '2': 262},
    {'1': 'HOP_CANT_SPEAK_RELAY', '2': 270},
    {'1': 'HOP_CANT_RELAY_TO_SELF', '2': 280},
    {'1': 'STOP_SRC_ADDR_TOO_LONG', '2': 320},
    {'1': 'STOP_DST_ADDR_TOO_LONG', '2': 321},
    {'1': 'STOP_SRC_MULTIADDR_INVALID', '2': 322},
    {'1': 'STOP_DST_MULTIADDR_INVALID', '2': 323},
  ],
};

/// Descriptor for `Status`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List statusDescriptor = $convert.base64Decode(
    'CgZTdGF0dXMSBgoCT0sQABIKCgZGQUlMRUQQARIaChVIT1BfU1JDX0FERFJfVE9PX0xPTkcQ3A'
    'ESGgoVSE9QX0RTVF9BRERSX1RPT19MT05HEN0BEh4KGUhPUF9TUkNfTVVMVElBRERSX0lOVkFM'
    'SUQQ3gESHgoZSE9QX0RTVF9NVUxUSUFERFJfSU5WQUxJRBDfARIXChJIT1BfTk9fQ09OTl9UT1'
    '9EU1QQhAISFgoRSE9QX0NBTlRfRElBTF9EU1QQhQISHQoYSE9QX0NBTlRfT1BFTl9EU1RfU1RS'
    'RUFNEIYCEhkKFEhPUF9DQU5UX1NQRUFLX1JFTEFZEI4CEhsKFkhPUF9DQU5UX1JFTEFZX1RPX1'
    'NFTEYQmAISGwoWU1RPUF9TUkNfQUREUl9UT09fTE9ORxDAAhIbChZTVE9QX0RTVF9BRERSX1RP'
    'T19MT05HEMECEh8KGlNUT1BfU1JDX01VTFRJQUREUl9JTlZBTElEEMICEh8KGlNUT1BfRFNUX0'
    '1VTFRJQUREUl9JTlZBTElEEMMC');

@$core.Deprecated('Use hopMessageDescriptor instead')
const HopMessage$json = {
  '1': 'HopMessage',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 14, '6': '.circuit_relay.HopMessage.Type', '10': 'type'},
    {'1': 'peer', '3': 2, '4': 1, '5': 11, '6': '.circuit_relay.Peer', '10': 'peer'},
    {'1': 'reservation', '3': 3, '4': 1, '5': 11, '6': '.circuit_relay.Reservation', '10': 'reservation'},
    {'1': 'limit', '3': 4, '4': 1, '5': 11, '6': '.circuit_relay.Limit', '10': 'limit'},
    {'1': 'status', '3': 5, '4': 1, '5': 14, '6': '.circuit_relay.Status', '10': 'status'},
  ],
  '4': [HopMessage_Type$json],
};

@$core.Deprecated('Use hopMessageDescriptor instead')
const HopMessage_Type$json = {
  '1': 'Type',
  '2': [
    {'1': 'RESERVE', '2': 0},
    {'1': 'CONNECT', '2': 1},
    {'1': 'STATUS', '2': 2},
  ],
};

/// Descriptor for `HopMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List hopMessageDescriptor = $convert.base64Decode(
    'CgpIb3BNZXNzYWdlEjIKBHR5cGUYASABKA4yHi5jaXJjdWl0X3JlbGF5LkhvcE1lc3NhZ2UuVH'
    'lwZVIEdHlwZRInCgRwZWVyGAIgASgLMhMuY2lyY3VpdF9yZWxheS5QZWVyUgRwZWVyEjwKC3Jl'
    'c2VydmF0aW9uGAMgASgLMhouY2lyY3VpdF9yZWxheS5SZXNlcnZhdGlvblILcmVzZXJ2YXRpb2'
    '4SKgoFbGltaXQYBCABKAsyFC5jaXJjdWl0X3JlbGF5LkxpbWl0UgVsaW1pdBItCgZzdGF0dXMY'
    'BSABKA4yFS5jaXJjdWl0X3JlbGF5LlN0YXR1c1IGc3RhdHVzIiwKBFR5cGUSCwoHUkVTRVJWRR'
    'AAEgsKB0NPTk5FQ1QQARIKCgZTVEFUVVMQAg==');

@$core.Deprecated('Use stopMessageDescriptor instead')
const StopMessage$json = {
  '1': 'StopMessage',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 14, '6': '.circuit_relay.StopMessage.Type', '10': 'type'},
    {'1': 'peer', '3': 2, '4': 1, '5': 11, '6': '.circuit_relay.Peer', '10': 'peer'},
    {'1': 'limit', '3': 3, '4': 1, '5': 11, '6': '.circuit_relay.Limit', '10': 'limit'},
    {'1': 'status', '3': 4, '4': 1, '5': 14, '6': '.circuit_relay.Status', '10': 'status'},
  ],
  '4': [StopMessage_Type$json],
};

@$core.Deprecated('Use stopMessageDescriptor instead')
const StopMessage_Type$json = {
  '1': 'Type',
  '2': [
    {'1': 'CONNECT', '2': 0},
    {'1': 'STATUS', '2': 1},
  ],
};

/// Descriptor for `StopMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopMessageDescriptor = $convert.base64Decode(
    'CgtTdG9wTWVzc2FnZRIzCgR0eXBlGAEgASgOMh8uY2lyY3VpdF9yZWxheS5TdG9wTWVzc2FnZS'
    '5UeXBlUgR0eXBlEicKBHBlZXIYAiABKAsyEy5jaXJjdWl0X3JlbGF5LlBlZXJSBHBlZXISKgoF'
    'bGltaXQYAyABKAsyFC5jaXJjdWl0X3JlbGF5LkxpbWl0UgVsaW1pdBItCgZzdGF0dXMYBCABKA'
    '4yFS5jaXJjdWl0X3JlbGF5LlN0YXR1c1IGc3RhdHVzIh8KBFR5cGUSCwoHQ09OTkVDVBAAEgoK'
    'BlNUQVRVUxAB');

@$core.Deprecated('Use peerDescriptor instead')
const Peer$json = {
  '1': 'Peer',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 12, '10': 'id'},
    {'1': 'addrs', '3': 2, '4': 3, '5': 12, '10': 'addrs'},
  ],
};

/// Descriptor for `Peer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerDescriptor = $convert.base64Decode(
    'CgRQZWVyEg4KAmlkGAEgASgMUgJpZBIUCgVhZGRycxgCIAMoDFIFYWRkcnM=');

@$core.Deprecated('Use reservationDescriptor instead')
const Reservation$json = {
  '1': 'Reservation',
  '2': [
    {'1': 'expire', '3': 1, '4': 1, '5': 4, '10': 'expire'},
    {'1': 'limit_duration', '3': 2, '4': 1, '5': 4, '10': 'limitDuration'},
    {'1': 'limit_data', '3': 3, '4': 1, '5': 4, '10': 'limitData'},
    {'1': 'addrs', '3': 4, '4': 3, '5': 12, '10': 'addrs'},
  ],
};

/// Descriptor for `Reservation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reservationDescriptor = $convert.base64Decode(
    'CgtSZXNlcnZhdGlvbhIWCgZleHBpcmUYASABKARSBmV4cGlyZRIlCg5saW1pdF9kdXJhdGlvbh'
    'gCIAEoBFINbGltaXREdXJhdGlvbhIdCgpsaW1pdF9kYXRhGAMgASgEUglsaW1pdERhdGESFAoF'
    'YWRkcnMYBCADKAxSBWFkZHJz');

@$core.Deprecated('Use limitDescriptor instead')
const Limit$json = {
  '1': 'Limit',
  '2': [
    {'1': 'duration', '3': 1, '4': 1, '5': 4, '10': 'duration'},
    {'1': 'data', '3': 2, '4': 1, '5': 4, '10': 'data'},
  ],
};

/// Descriptor for `Limit`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List limitDescriptor = $convert.base64Decode(
    'CgVMaW1pdBIaCghkdXJhdGlvbhgBIAEoBFIIZHVyYXRpb24SEgoEZGF0YRgCIAEoBFIEZGF0YQ'
    '==');

