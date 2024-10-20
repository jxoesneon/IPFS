//
//  Generated code. Do not modify.
//  source: lib/src/proto/bitswap/message_types.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use wantTypeDescriptor instead')
const WantType$json = {
  '1': 'WantType',
  '2': [
    {'1': 'WANT_TYPE_BLOCK', '2': 0},
    {'1': 'WANT_TYPE_HAVE', '2': 1},
  ],
};

/// Descriptor for `WantType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List wantTypeDescriptor = $convert.base64Decode(
    'CghXYW50VHlwZRITCg9XQU5UX1RZUEVfQkxPQ0sQABISCg5XQU5UX1RZUEVfSEFWRRAB');

@$core.Deprecated('Use blockPresenceTypeDescriptor instead')
const BlockPresenceType$json = {
  '1': 'BlockPresenceType',
  '2': [
    {'1': 'BLOCK_PRESENCE_HAVE', '2': 0},
    {'1': 'BLOCK_PRESENCE_DONT_HAVE', '2': 1},
  ],
};

/// Descriptor for `BlockPresenceType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List blockPresenceTypeDescriptor = $convert.base64Decode(
    'ChFCbG9ja1ByZXNlbmNlVHlwZRIXChNCTE9DS19QUkVTRU5DRV9IQVZFEAASHAoYQkxPQ0tfUF'
    'JFU0VOQ0VfRE9OVF9IQVZFEAE=');

@$core.Deprecated('Use wantlistDescriptor instead')
const Wantlist$json = {
  '1': 'Wantlist',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.bitswap.Wantlist.Entry', '10': 'entries'},
    {'1': 'full', '3': 2, '4': 1, '5': 8, '10': 'full'},
  ],
  '3': [Wantlist_Entry$json],
};

@$core.Deprecated('Use wantlistDescriptor instead')
const Wantlist_Entry$json = {
  '1': 'Entry',
  '2': [
    {'1': 'block', '3': 1, '4': 1, '5': 12, '10': 'block'},
    {'1': 'priority', '3': 2, '4': 1, '5': 5, '10': 'priority'},
    {'1': 'cancel', '3': 3, '4': 1, '5': 8, '10': 'cancel'},
    {'1': 'wantType', '3': 4, '4': 1, '5': 14, '6': '.bitswap.WantType', '10': 'wantType'},
    {'1': 'sendDontHave', '3': 5, '4': 1, '5': 8, '10': 'sendDontHave'},
  ],
};

/// Descriptor for `Wantlist`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wantlistDescriptor = $convert.base64Decode(
    'CghXYW50bGlzdBIxCgdlbnRyaWVzGAEgAygLMhcuYml0c3dhcC5XYW50bGlzdC5FbnRyeVIHZW'
    '50cmllcxISCgRmdWxsGAIgASgIUgRmdWxsGqQBCgVFbnRyeRIUCgVibG9jaxgBIAEoDFIFYmxv'
    'Y2sSGgoIcHJpb3JpdHkYAiABKAVSCHByaW9yaXR5EhYKBmNhbmNlbBgDIAEoCFIGY2FuY2VsEi'
    '0KCHdhbnRUeXBlGAQgASgOMhEuYml0c3dhcC5XYW50VHlwZVIId2FudFR5cGUSIgoMc2VuZERv'
    'bnRIYXZlGAUgASgIUgxzZW5kRG9udEhhdmU=');

@$core.Deprecated('Use blockMsgDescriptor instead')
const BlockMsg$json = {
  '1': 'BlockMsg',
  '2': [
    {'1': 'prefix', '3': 1, '4': 1, '5': 12, '10': 'prefix'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `BlockMsg`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockMsgDescriptor = $convert.base64Decode(
    'CghCbG9ja01zZxIWCgZwcmVmaXgYASABKAxSBnByZWZpeBISCgRkYXRhGAIgASgMUgRkYXRh');

@$core.Deprecated('Use blockPresenceDescriptor instead')
const BlockPresence$json = {
  '1': 'BlockPresence',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 12, '10': 'cid'},
    {'1': 'type', '3': 2, '4': 1, '5': 14, '6': '.bitswap.BlockPresenceType', '10': 'type'},
  ],
};

/// Descriptor for `BlockPresence`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockPresenceDescriptor = $convert.base64Decode(
    'Cg1CbG9ja1ByZXNlbmNlEhAKA2NpZBgBIAEoDFIDY2lkEi4KBHR5cGUYAiABKA4yGi5iaXRzd2'
    'FwLkJsb2NrUHJlc2VuY2VUeXBlUgR0eXBl');

@$core.Deprecated('Use messageDescriptor instead')
const Message$json = {
  '1': 'Message',
  '2': [
    {'1': 'wantlist', '3': 1, '4': 1, '5': 11, '6': '.bitswap.Wantlist', '10': 'wantlist'},
    {'1': 'payload', '3': 3, '4': 3, '5': 11, '6': '.bitswap.BlockMsg', '10': 'payload'},
    {'1': 'blockPresences', '3': 4, '4': 3, '5': 11, '6': '.bitswap.BlockPresence', '10': 'blockPresences'},
    {'1': 'pendingBytes', '3': 5, '4': 1, '5': 5, '10': 'pendingBytes'},
  ],
};

/// Descriptor for `Message`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageDescriptor = $convert.base64Decode(
    'CgdNZXNzYWdlEi0KCHdhbnRsaXN0GAEgASgLMhEuYml0c3dhcC5XYW50bGlzdFIId2FudGxpc3'
    'QSKwoHcGF5bG9hZBgDIAMoCzIRLmJpdHN3YXAuQmxvY2tNc2dSB3BheWxvYWQSPgoOYmxvY2tQ'
    'cmVzZW5jZXMYBCADKAsyFi5iaXRzd2FwLkJsb2NrUHJlc2VuY2VSDmJsb2NrUHJlc2VuY2VzEi'
    'IKDHBlbmRpbmdCeXRlcxgFIAEoBVIMcGVuZGluZ0J5dGVz');

