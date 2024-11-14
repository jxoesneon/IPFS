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

@$core.Deprecated('Use messageTypeDescriptor instead')
const MessageType$json = {
  '1': 'MessageType',
  '2': [
    {'1': 'MESSAGE_TYPE_UNKNOWN', '2': 0},
    {'1': 'MESSAGE_TYPE_WANT_BLOCK', '2': 1},
    {'1': 'MESSAGE_TYPE_WANT_HAVE', '2': 2},
    {'1': 'MESSAGE_TYPE_BLOCK', '2': 3},
    {'1': 'MESSAGE_TYPE_HAVE', '2': 4},
    {'1': 'MESSAGE_TYPE_DONT_HAVE', '2': 5},
  ],
};

/// Descriptor for `MessageType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List messageTypeDescriptor = $convert.base64Decode(
    'CgtNZXNzYWdlVHlwZRIYChRNRVNTQUdFX1RZUEVfVU5LTk9XThAAEhsKF01FU1NBR0VfVFlQRV'
    '9XQU5UX0JMT0NLEAESGgoWTUVTU0FHRV9UWVBFX1dBTlRfSEFWRRACEhYKEk1FU1NBR0VfVFlQ'
    'RV9CTE9DSxADEhUKEU1FU1NBR0VfVFlQRV9IQVZFEAQSGgoWTUVTU0FHRV9UWVBFX0RPTlRfSE'
    'FWRRAF');

@$core.Deprecated('Use wantlistEntryDescriptor instead')
const WantlistEntry$json = {
  '1': 'WantlistEntry',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 12, '10': 'cid'},
    {'1': 'priority', '3': 2, '4': 1, '5': 5, '10': 'priority'},
    {'1': 'cancel', '3': 3, '4': 1, '5': 8, '10': 'cancel'},
    {'1': 'type', '3': 4, '4': 1, '5': 14, '6': '.bitswap.MessageType', '10': 'type'},
    {'1': 'sendDontHave', '3': 5, '4': 1, '5': 8, '10': 'sendDontHave'},
  ],
};

/// Descriptor for `WantlistEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wantlistEntryDescriptor = $convert.base64Decode(
    'Cg1XYW50bGlzdEVudHJ5EhAKA2NpZBgBIAEoDFIDY2lkEhoKCHByaW9yaXR5GAIgASgFUghwcm'
    'lvcml0eRIWCgZjYW5jZWwYAyABKAhSBmNhbmNlbBIoCgR0eXBlGAQgASgOMhQuYml0c3dhcC5N'
    'ZXNzYWdlVHlwZVIEdHlwZRIiCgxzZW5kRG9udEhhdmUYBSABKAhSDHNlbmREb250SGF2ZQ==');

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
    {'1': 'cid', '3': 1, '4': 1, '5': 12, '10': 'cid'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
    {'1': 'found', '3': 3, '4': 1, '5': 8, '10': 'found'},
    {'1': 'format', '3': 4, '4': 1, '5': 9, '10': 'format'},
  ],
};

/// Descriptor for `Block`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockDescriptor = $convert.base64Decode(
    'CgVCbG9jaxIQCgNjaWQYASABKAxSA2NpZBISCgRkYXRhGAIgASgMUgRkYXRhEhQKBWZvdW5kGA'
    'MgASgIUgVmb3VuZBIWCgZmb3JtYXQYBCABKAlSBmZvcm1hdA==');

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
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'type', '3': 2, '4': 1, '5': 14, '6': '.bitswap.MessageType', '10': 'type'},
    {'1': 'wantlist', '3': 3, '4': 1, '5': 11, '6': '.bitswap.Wantlist', '10': 'wantlist'},
    {'1': 'blocks', '3': 4, '4': 3, '5': 11, '6': '.bitswap.Block', '10': 'blocks'},
    {'1': 'blockPresences', '3': 5, '4': 3, '5': 11, '6': '.bitswap.BlockPresence', '10': 'blockPresences'},
  ],
};

/// Descriptor for `Message`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageDescriptor = $convert.base64Decode(
    'CgdNZXNzYWdlEh0KCm1lc3NhZ2VfaWQYASABKAlSCW1lc3NhZ2VJZBIoCgR0eXBlGAIgASgOMh'
    'QuYml0c3dhcC5NZXNzYWdlVHlwZVIEdHlwZRItCgh3YW50bGlzdBgDIAEoCzIRLmJpdHN3YXAu'
    'V2FudGxpc3RSCHdhbnRsaXN0EiYKBmJsb2NrcxgEIAMoCzIOLmJpdHN3YXAuQmxvY2tSBmJsb2'
    'NrcxI+Cg5ibG9ja1ByZXNlbmNlcxgFIAMoCzIWLmJpdHN3YXAuQmxvY2tQcmVzZW5jZVIOYmxv'
    'Y2tQcmVzZW5jZXM=');

