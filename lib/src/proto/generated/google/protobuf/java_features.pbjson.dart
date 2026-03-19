// This is a generated file - do not edit.
//
// Generated from google/protobuf/java_features.proto.

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

@$core.Deprecated('Use javaFeaturesDescriptor instead')
const JavaFeatures$json = {
  '1': 'JavaFeatures',
  '2': [
    {
      '1': 'legacy_closed_enum',
      '3': 1,
      '4': 1,
      '5': 8,
      '8': {
        '17': 1,
        '19': [4, 1],
        '20': [
          {'2': 'true', '3': 900},
          {'2': 'false', '3': 999},
        ],
        '22': {
          '1': 1000,
          '2': 1000,
          '3':
              'The legacy closed enum treatment in Java is deprecated and is scheduled to be removed in edition 2025.  Mark enum type on the enum definitions themselves rather than on fields.'
        },
      },
      '10': 'legacyClosedEnum',
    },
    {
      '1': 'utf8_validation',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.pb.JavaFeatures.Utf8Validation',
      '8': {
        '17': 1,
        '19': [4, 1],
        '20': [
          {'2': 'DEFAULT', '3': 900},
        ],
        '22': {
          '1': 1000,
          '2': 1001,
          '3':
              'The Java-specific utf8 validation feature is deprecated and is scheduled to be removed in edition 2025.  Utf8 validation behavior should use the global cross-language utf8_validation feature.'
        },
      },
      '10': 'utf8Validation',
    },
  ],
  '4': [JavaFeatures_Utf8Validation$json],
};

@$core.Deprecated('Use javaFeaturesDescriptor instead')
const JavaFeatures_Utf8Validation$json = {
  '1': 'Utf8Validation',
  '2': [
    {'1': 'UTF8_VALIDATION_UNKNOWN', '2': 0},
    {'1': 'DEFAULT', '2': 1},
    {'1': 'VERIFY', '2': 2},
  ],
};

/// Descriptor for `JavaFeatures`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List javaFeaturesDescriptor = $convert.base64Decode(
    'CgxKYXZhRmVhdHVyZXMSjgIKEmxlZ2FjeV9jbG9zZWRfZW51bRgBIAEoCELfAYgBAZgBBJgBAa'
    'IBCRIEdHJ1ZRiEB6IBChIFZmFsc2UY5weyAbkBCOgHEOgHGrABVGhlIGxlZ2FjeSBjbG9zZWQg'
    'ZW51bSB0cmVhdG1lbnQgaW4gSmF2YSBpcyBkZXByZWNhdGVkIGFuZCBpcyBzY2hlZHVsZWQgdG'
    '8gYmUgcmVtb3ZlZCBpbiBlZGl0aW9uIDIwMjUuICBNYXJrIGVudW0gdHlwZSBvbiB0aGUgZW51'
    'bSBkZWZpbml0aW9ucyB0aGVtc2VsdmVzIHJhdGhlciB0aGFuIG9uIGZpZWxkcy5SEGxlZ2FjeU'
    'Nsb3NlZEVudW0SrwIKD3V0ZjhfdmFsaWRhdGlvbhgCIAEoDjIfLnBiLkphdmFGZWF0dXJlcy5V'
    'dGY4VmFsaWRhdGlvbkLkAYgBAZgBBJgBAaIBDBIHREVGQVVMVBiEB7IByAEI6AcQ6QcavwFUaG'
    'UgSmF2YS1zcGVjaWZpYyB1dGY4IHZhbGlkYXRpb24gZmVhdHVyZSBpcyBkZXByZWNhdGVkIGFu'
    'ZCBpcyBzY2hlZHVsZWQgdG8gYmUgcmVtb3ZlZCBpbiBlZGl0aW9uIDIwMjUuICBVdGY4IHZhbG'
    'lkYXRpb24gYmVoYXZpb3Igc2hvdWxkIHVzZSB0aGUgZ2xvYmFsIGNyb3NzLWxhbmd1YWdlIHV0'
    'ZjhfdmFsaWRhdGlvbiBmZWF0dXJlLlIOdXRmOFZhbGlkYXRpb24iRgoOVXRmOFZhbGlkYXRpb2'
    '4SGwoXVVRGOF9WQUxJREFUSU9OX1VOS05PV04QABILCgdERUZBVUxUEAESCgoGVkVSSUZZEAI=');
