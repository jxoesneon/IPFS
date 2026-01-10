// This is a generated file - do not edit.
//
// Generated from core/bitfield.proto.

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

@$core.Deprecated('Use bitFieldProtoDescriptor instead')
const BitFieldProto$json = {
  '1': 'BitFieldProto',
  '2': [
    {'1': 'bits', '3': 1, '4': 1, '5': 12, '10': 'bits'},
    {'1': 'size', '3': 2, '4': 1, '5': 5, '10': 'size'},
  ],
  '3': [
    BitFieldProto_SetBitRequest$json,
    BitFieldProto_ClearBitRequest$json,
    BitFieldProto_GetBitRequest$json,
    BitFieldProto_BitResponse$json
  ],
};

@$core.Deprecated('Use bitFieldProtoDescriptor instead')
const BitFieldProto_SetBitRequest$json = {
  '1': 'SetBitRequest',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 5, '10': 'index'},
  ],
};

@$core.Deprecated('Use bitFieldProtoDescriptor instead')
const BitFieldProto_ClearBitRequest$json = {
  '1': 'ClearBitRequest',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 5, '10': 'index'},
  ],
};

@$core.Deprecated('Use bitFieldProtoDescriptor instead')
const BitFieldProto_GetBitRequest$json = {
  '1': 'GetBitRequest',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 5, '10': 'index'},
  ],
};

@$core.Deprecated('Use bitFieldProtoDescriptor instead')
const BitFieldProto_BitResponse$json = {
  '1': 'BitResponse',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `BitFieldProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bitFieldProtoDescriptor = $convert.base64Decode(
    'Cg1CaXRGaWVsZFByb3RvEhIKBGJpdHMYASABKAxSBGJpdHMSEgoEc2l6ZRgCIAEoBVIEc2l6ZR'
    'olCg1TZXRCaXRSZXF1ZXN0EhQKBWluZGV4GAEgASgFUgVpbmRleBonCg9DbGVhckJpdFJlcXVl'
    'c3QSFAoFaW5kZXgYASABKAVSBWluZGV4GiUKDUdldEJpdFJlcXVlc3QSFAoFaW5kZXgYASABKA'
    'VSBWluZGV4GiMKC0JpdFJlc3BvbnNlEhQKBXZhbHVlGAEgASgIUgV2YWx1ZQ==');
