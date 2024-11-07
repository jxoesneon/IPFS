//
//  Generated code. Do not modify.
//  source: validation.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use validationResultDescriptor instead')
const ValidationResult$json = {
  '1': 'ValidationResult',
  '2': [
    {'1': 'is_valid', '3': 1, '4': 1, '5': 8, '10': 'isValid'},
    {'1': 'error_message', '3': 2, '4': 1, '5': 9, '10': 'errorMessage'},
    {'1': 'code', '3': 3, '4': 1, '5': 14, '6': '.ipfs.validation.ValidationResult.ValidationCode', '10': 'code'},
  ],
  '4': [ValidationResult_ValidationCode$json],
};

@$core.Deprecated('Use validationResultDescriptor instead')
const ValidationResult_ValidationCode$json = {
  '1': 'ValidationCode',
  '2': [
    {'1': 'UNKNOWN', '2': 0},
    {'1': 'SUCCESS', '2': 1},
    {'1': 'INVALID_SIZE', '2': 2},
    {'1': 'INVALID_PROTOCOL', '2': 3},
    {'1': 'INVALID_FORMAT', '2': 4},
    {'1': 'RATE_LIMITED', '2': 5},
  ],
};

/// Descriptor for `ValidationResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List validationResultDescriptor = $convert.base64Decode(
    'ChBWYWxpZGF0aW9uUmVzdWx0EhkKCGlzX3ZhbGlkGAEgASgIUgdpc1ZhbGlkEiMKDWVycm9yX2'
    '1lc3NhZ2UYAiABKAlSDGVycm9yTWVzc2FnZRJECgRjb2RlGAMgASgOMjAuaXBmcy52YWxpZGF0'
    'aW9uLlZhbGlkYXRpb25SZXN1bHQuVmFsaWRhdGlvbkNvZGVSBGNvZGUieAoOVmFsaWRhdGlvbk'
    'NvZGUSCwoHVU5LTk9XThAAEgsKB1NVQ0NFU1MQARIQCgxJTlZBTElEX1NJWkUQAhIUChBJTlZB'
    'TElEX1BST1RPQ09MEAMSEgoOSU5WQUxJRF9GT1JNQVQQBBIQCgxSQVRFX0xJTUlURUQQBQ==');

