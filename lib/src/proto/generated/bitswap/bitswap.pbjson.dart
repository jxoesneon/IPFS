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

@$core.Deprecated('Use messageDescriptor instead')
const Message$json = {
  '1': 'Message',
  '2': [
    {
      '1': 'wantlist',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.bitswap.Message.Wantlist',
      '10': 'wantlist'
    },
    {'1': 'blocks', '3': 2, '4': 3, '5': 12, '10': 'blocks'},
    {
      '1': 'payload',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.ipfs.bitswap.Message.Block',
      '10': 'payload'
    },
    {
      '1': 'blockPresences',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.ipfs.bitswap.Message.BlockPresence',
      '10': 'blockPresences'
    },
    {'1': 'pendingBytes', '3': 5, '4': 1, '5': 5, '10': 'pendingBytes'},
  ],
  '3': [Message_Wantlist$json, Message_Block$json, Message_BlockPresence$json],
};

@$core.Deprecated('Use messageDescriptor instead')
const Message_Wantlist$json = {
  '1': 'Wantlist',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.ipfs.bitswap.Message.Wantlist.Entry',
      '10': 'entries'
    },
    {'1': 'full', '3': 2, '4': 1, '5': 8, '10': 'full'},
  ],
  '3': [Message_Wantlist_Entry$json],
  '4': [Message_Wantlist_WantType$json],
};

@$core.Deprecated('Use messageDescriptor instead')
const Message_Wantlist_Entry$json = {
  '1': 'Entry',
  '2': [
    {'1': 'block', '3': 1, '4': 1, '5': 12, '10': 'block'},
    {'1': 'priority', '3': 2, '4': 1, '5': 5, '10': 'priority'},
    {'1': 'cancel', '3': 3, '4': 1, '5': 8, '10': 'cancel'},
    {
      '1': 'wantType',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.ipfs.bitswap.Message.Wantlist.WantType',
      '10': 'wantType'
    },
    {'1': 'sendDontHave', '3': 5, '4': 1, '5': 8, '10': 'sendDontHave'},
  ],
};

@$core.Deprecated('Use messageDescriptor instead')
const Message_Wantlist_WantType$json = {
  '1': 'WantType',
  '2': [
    {'1': 'Block', '2': 0},
    {'1': 'Have', '2': 1},
  ],
};

@$core.Deprecated('Use messageDescriptor instead')
const Message_Block$json = {
  '1': 'Block',
  '2': [
    {'1': 'prefix', '3': 1, '4': 1, '5': 12, '10': 'prefix'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

@$core.Deprecated('Use messageDescriptor instead')
const Message_BlockPresence$json = {
  '1': 'BlockPresence',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 12, '10': 'cid'},
    {
      '1': 'type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.ipfs.bitswap.Message.BlockPresence.Type',
      '10': 'type'
    },
  ],
  '4': [Message_BlockPresence_Type$json],
};

@$core.Deprecated('Use messageDescriptor instead')
const Message_BlockPresence_Type$json = {
  '1': 'Type',
  '2': [
    {'1': 'Have', '2': 0},
    {'1': 'DontHave', '2': 1},
  ],
};

/// Descriptor for `Message`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageDescriptor = $convert.base64Decode(
    'CgdNZXNzYWdlEjoKCHdhbnRsaXN0GAEgASgLMh4uaXBmcy5iaXRzd2FwLk1lc3NhZ2UuV2FudG'
    'xpc3RSCHdhbnRsaXN0EhYKBmJsb2NrcxgCIAMoDFIGYmxvY2tzEjUKB3BheWxvYWQYAyADKAsy'
    'Gy5pcGZzLmJpdHN3YXAuTWVzc2FnZS5CbG9ja1IHcGF5bG9hZBJLCg5ibG9ja1ByZXNlbmNlcx'
    'gEIAMoCzIjLmlwZnMuYml0c3dhcC5NZXNzYWdlLkJsb2NrUHJlc2VuY2VSDmJsb2NrUHJlc2Vu'
    'Y2VzEiIKDHBlbmRpbmdCeXRlcxgFIAEoBVIMcGVuZGluZ0J5dGVzGrwCCghXYW50bGlzdBI+Cg'
    'dlbnRyaWVzGAEgAygLMiQuaXBmcy5iaXRzd2FwLk1lc3NhZ2UuV2FudGxpc3QuRW50cnlSB2Vu'
    'dHJpZXMSEgoEZnVsbBgCIAEoCFIEZnVsbBq6AQoFRW50cnkSFAoFYmxvY2sYASABKAxSBWJsb2'
    'NrEhoKCHByaW9yaXR5GAIgASgFUghwcmlvcml0eRIWCgZjYW5jZWwYAyABKAhSBmNhbmNlbBJD'
    'Cgh3YW50VHlwZRgEIAEoDjInLmlwZnMuYml0c3dhcC5NZXNzYWdlLldhbnRsaXN0LldhbnRUeX'
    'BlUgh3YW50VHlwZRIiCgxzZW5kRG9udEhhdmUYBSABKAhSDHNlbmREb250SGF2ZSIfCghXYW50'
    'VHlwZRIJCgVCbG9jaxAAEggKBEhhdmUQARozCgVCbG9jaxIWCgZwcmVmaXgYASABKAxSBnByZW'
    'ZpeBISCgRkYXRhGAIgASgMUgRkYXRhGn8KDUJsb2NrUHJlc2VuY2USEAoDY2lkGAEgASgMUgNj'
    'aWQSPAoEdHlwZRgCIAEoDjIoLmlwZnMuYml0c3dhcC5NZXNzYWdlLkJsb2NrUHJlc2VuY2UuVH'
    'lwZVIEdHlwZSIeCgRUeXBlEggKBEhhdmUQABIMCghEb250SGF2ZRAB');
