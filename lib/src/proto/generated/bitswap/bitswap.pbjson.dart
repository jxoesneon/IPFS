//
//  Generated code. Do not modify.
//  source: bitswap/bitswap.proto
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
    {'1': 'WANT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'WANT_TYPE_BLOCK', '2': 1},
    {'1': 'WANT_TYPE_HAVE', '2': 2},
  ],
};

/// Descriptor for `WantType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List wantTypeDescriptor = $convert.base64Decode(
    'CghXYW50VHlwZRIZChVXQU5UX1RZUEVfVU5TUEVDSUZJRUQQABITCg9XQU5UX1RZUEVfQkxPQ0'
    'sQARISCg5XQU5UX1RZUEVfSEFWRRAC');

@$core.Deprecated('Use wantlistEntryDescriptor instead')
const WantlistEntry$json = {
  '1': 'WantlistEntry',
  '2': [
    {'1': 'block', '3': 1, '4': 1, '5': 12, '10': 'block'},
    {'1': 'priority', '3': 2, '4': 1, '5': 5, '10': 'priority'},
    {'1': 'cancel', '3': 3, '4': 1, '5': 8, '10': 'cancel'},
    {'1': 'wantType', '3': 4, '4': 1, '5': 14, '6': '.bitswap.WantType', '10': 'wantType'},
    {'1': 'sendDontHave', '3': 5, '4': 1, '5': 8, '10': 'sendDontHave'},
  ],
};

/// Descriptor for `WantlistEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wantlistEntryDescriptor = $convert.base64Decode(
    'Cg1XYW50bGlzdEVudHJ5EhQKBWJsb2NrGAEgASgMUgVibG9jaxIaCghwcmlvcml0eRgCIAEoBV'
    'IIcHJpb3JpdHkSFgoGY2FuY2VsGAMgASgIUgZjYW5jZWwSLQoId2FudFR5cGUYBCABKA4yES5i'
    'aXRzd2FwLldhbnRUeXBlUgh3YW50VHlwZRIiCgxzZW5kRG9udEhhdmUYBSABKAhSDHNlbmREb2'
    '50SGF2ZQ==');

@$core.Deprecated('Use wantlistDescriptor instead')
const Wantlist$json = {
  '1': 'Wantlist',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.bitswap.WantlistEntry', '10': 'entries'},
    {'1': 'full', '3': 2, '4': 1, '5': 8, '10': 'full'},
  ],
};

/// Descriptor for `Wantlist`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wantlistDescriptor = $convert.base64Decode(
    'CghXYW50bGlzdBIwCgdlbnRyaWVzGAEgAygLMhYuYml0c3dhcC5XYW50bGlzdEVudHJ5Ugdlbn'
    'RyaWVzEhIKBGZ1bGwYAiABKAhSBGZ1bGw=');

@$core.Deprecated('Use blockDescriptor instead')
const Block$json = {
  '1': 'Block',
  '2': [
    {'1': 'prefix', '3': 1, '4': 1, '5': 12, '10': 'prefix'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `Block`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockDescriptor = $convert.base64Decode(
    'CgVCbG9jaxIWCgZwcmVmaXgYASABKAxSBnByZWZpeBISCgRkYXRhGAIgASgMUgRkYXRh');

@$core.Deprecated('Use blockPresenceDescriptor instead')
const BlockPresence$json = {
  '1': 'BlockPresence',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 12, '10': 'cid'},
    {'1': 'type', '3': 2, '4': 1, '5': 14, '6': '.bitswap.BlockPresence.Type', '10': 'type'},
  ],
  '4': [BlockPresence_Type$json],
};

@$core.Deprecated('Use blockPresenceDescriptor instead')
const BlockPresence_Type$json = {
  '1': 'Type',
  '2': [
    {'1': 'HAVE', '2': 0},
    {'1': 'DONT_HAVE', '2': 1},
  ],
};

/// Descriptor for `BlockPresence`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockPresenceDescriptor = $convert.base64Decode(
    'Cg1CbG9ja1ByZXNlbmNlEhAKA2NpZBgBIAEoDFIDY2lkEi8KBHR5cGUYAiABKA4yGy5iaXRzd2'
    'FwLkJsb2NrUHJlc2VuY2UuVHlwZVIEdHlwZSIfCgRUeXBlEggKBEhBVkUQABINCglET05UX0hB'
    'VkUQAQ==');

@$core.Deprecated('Use messageDescriptor instead')
const Message$json = {
  '1': 'Message',
  '2': [
    {'1': 'wantlist', '3': 1, '4': 1, '5': 11, '6': '.bitswap.Wantlist', '10': 'wantlist'},
    {'1': 'blocks', '3': 2, '4': 3, '5': 11, '6': '.bitswap.Block', '10': 'blocks'},
    {'1': 'blockPresences', '3': 3, '4': 3, '5': 11, '6': '.bitswap.BlockPresence', '10': 'blockPresences'},
  ],
};

/// Descriptor for `Message`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageDescriptor = $convert.base64Decode(
    'CgdNZXNzYWdlEi0KCHdhbnRsaXN0GAEgASgLMhEuYml0c3dhcC5XYW50bGlzdFIId2FudGxpc3'
    'QSJgoGYmxvY2tzGAIgAygLMg4uYml0c3dhcC5CbG9ja1IGYmxvY2tzEj4KDmJsb2NrUHJlc2Vu'
    'Y2VzGAMgAygLMhYuYml0c3dhcC5CbG9ja1ByZXNlbmNlUg5ibG9ja1ByZXNlbmNlcw==');

