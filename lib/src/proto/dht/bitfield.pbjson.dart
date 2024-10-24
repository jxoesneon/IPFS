//
//  Generated code. Do not modify.
//  source: bitfield.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use bitFieldDescriptor instead')
const BitField$json = {
  '1': 'BitField',
  '2': [
    {'1': 'bits', '3': 1, '4': 3, '5': 8, '10': 'bits'},
    {'1': 'size', '3': 2, '4': 1, '5': 5, '10': 'size'},
  ],
  '3': [BitField_SetBitRequest$json, BitField_GetBitRequest$json, BitField_BitResponse$json],
};

@$core.Deprecated('Use bitFieldDescriptor instead')
const BitField_SetBitRequest$json = {
  '1': 'SetBitRequest',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 5, '10': 'index'},
  ],
};

@$core.Deprecated('Use bitFieldDescriptor instead')
const BitField_GetBitRequest$json = {
  '1': 'GetBitRequest',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 5, '10': 'index'},
  ],
};

@$core.Deprecated('Use bitFieldDescriptor instead')
const BitField_BitResponse$json = {
  '1': 'BitResponse',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `BitField`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bitFieldDescriptor = $convert.base64Decode(
    'CghCaXRGaWVsZBISCgRiaXRzGAEgAygIUgRiaXRzEhIKBHNpemUYAiABKAVSBHNpemUaJQoNU2'
    'V0Qml0UmVxdWVzdBIUCgVpbmRleBgBIAEoBVIFaW5kZXgaJQoNR2V0Qml0UmVxdWVzdBIUCgVp'
    'bmRleBgBIAEoBVIFaW5kZXgaIwoLQml0UmVzcG9uc2USFAoFdmFsdWUYASABKAhSBXZhbHVl');

