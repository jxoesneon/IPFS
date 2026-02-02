// This is a generated file - do not edit.
//
// Generated from core/pin.proto.

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

@$core.Deprecated('Use pinTypeProtoDescriptor instead')
const PinTypeProto$json = {
  '1': 'PinTypeProto',
  '2': [
    {'1': 'PIN_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'PIN_TYPE_DIRECT', '2': 1},
    {'1': 'PIN_TYPE_RECURSIVE', '2': 2},
  ],
};

/// Descriptor for `PinTypeProto`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List pinTypeProtoDescriptor = $convert.base64Decode(
    'CgxQaW5UeXBlUHJvdG8SGAoUUElOX1RZUEVfVU5TUEVDSUZJRUQQABITCg9QSU5fVFlQRV9ESV'
    'JFQ1QQARIWChJQSU5fVFlQRV9SRUNVUlNJVkUQAg==');

@$core.Deprecated('Use pinProtoDescriptor instead')
const PinProto$json = {
  '1': 'PinProto',
  '2': [
    {
      '1': 'cid',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.IPFSCIDProto',
      '10': 'cid'
    },
    {
      '1': 'type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.ipfs.core.data_structures.PinTypeProto',
      '10': 'type'
    },
    {'1': 'timestamp', '3': 3, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `PinProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pinProtoDescriptor = $convert.base64Decode(
    'CghQaW5Qcm90bxIpCgNjaWQYASABKAsyFy5pcGZzLmNvcmUuSVBGU0NJRFByb3RvUgNjaWQSOw'
    'oEdHlwZRgCIAEoDjInLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuUGluVHlwZVByb3RvUgR0'
    'eXBlEhwKCXRpbWVzdGFtcBgDIAEoA1IJdGltZXN0YW1w');
