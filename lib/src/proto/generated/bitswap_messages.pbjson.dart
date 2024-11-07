//
//  Generated code. Do not modify.
//  source: bitswap_messages.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use bitSwapMessageDescriptor instead')
const BitSwapMessage$json = {
  '1': 'BitSwapMessage',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'type', '3': 2, '4': 1, '5': 14, '6': '.ipfs.bitswap.BitSwapMessage.MessageType', '10': 'type'},
    {'1': 'want_list', '3': 3, '4': 3, '5': 11, '6': '.ipfs.bitswap.WantList', '10': 'wantList'},
    {'1': 'blocks', '3': 4, '4': 3, '5': 11, '6': '.ipfs.bitswap.Block', '10': 'blocks'},
  ],
  '4': [BitSwapMessage_MessageType$json],
};

@$core.Deprecated('Use bitSwapMessageDescriptor instead')
const BitSwapMessage_MessageType$json = {
  '1': 'MessageType',
  '2': [
    {'1': 'UNKNOWN', '2': 0},
    {'1': 'WANT_HAVE', '2': 1},
    {'1': 'WANT_BLOCK', '2': 2},
    {'1': 'HAVE', '2': 3},
    {'1': 'DONT_HAVE', '2': 4},
    {'1': 'BLOCK', '2': 5},
  ],
};

/// Descriptor for `BitSwapMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bitSwapMessageDescriptor = $convert.base64Decode(
    'Cg5CaXRTd2FwTWVzc2FnZRIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYWdlSWQSPAoEdHlwZR'
    'gCIAEoDjIoLmlwZnMuYml0c3dhcC5CaXRTd2FwTWVzc2FnZS5NZXNzYWdlVHlwZVIEdHlwZRIz'
    'Cgl3YW50X2xpc3QYAyADKAsyFi5pcGZzLmJpdHN3YXAuV2FudExpc3RSCHdhbnRMaXN0EisKBm'
    'Jsb2NrcxgEIAMoCzITLmlwZnMuYml0c3dhcC5CbG9ja1IGYmxvY2tzIl0KC01lc3NhZ2VUeXBl'
    'EgsKB1VOS05PV04QABINCglXQU5UX0hBVkUQARIOCgpXQU5UX0JMT0NLEAISCAoESEFWRRADEg'
    '0KCURPTlRfSEFWRRAEEgkKBUJMT0NLEAU=');

@$core.Deprecated('Use wantListDescriptor instead')
const WantList$json = {
  '1': 'WantList',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 12, '10': 'cid'},
    {'1': 'want_block', '3': 2, '4': 1, '5': 8, '10': 'wantBlock'},
    {'1': 'priority', '3': 3, '4': 1, '5': 5, '10': 'priority'},
  ],
};

/// Descriptor for `WantList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wantListDescriptor = $convert.base64Decode(
    'CghXYW50TGlzdBIQCgNjaWQYASABKAxSA2NpZBIdCgp3YW50X2Jsb2NrGAIgASgIUgl3YW50Qm'
    'xvY2sSGgoIcHJpb3JpdHkYAyABKAVSCHByaW9yaXR5');

@$core.Deprecated('Use blockDescriptor instead')
const Block$json = {
  '1': 'Block',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 12, '10': 'cid'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `Block`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockDescriptor = $convert.base64Decode(
    'CgVCbG9jaxIQCgNjaWQYASABKAxSA2NpZBISCgRkYXRhGAIgASgMUgRkYXRh');

