// This is a generated file - do not edit.
//
// Generated from core/sec/insecure/pb/plaintext.proto.

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

@$core.Deprecated('Use exchangeDescriptor instead')
const Exchange$json = {
  '1': 'Exchange',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 12, '10': 'id'},
    {
      '1': 'pubkey',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.crypto.pb.PublicKey',
      '10': 'pubkey'
    },
  ],
};

/// Descriptor for `Exchange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exchangeDescriptor = $convert.base64Decode(
    'CghFeGNoYW5nZRIOCgJpZBgBIAEoDFICaWQSLAoGcHVia2V5GAIgASgLMhQuY3J5cHRvLnBiLl'
    'B1YmxpY0tleVIGcHVia2V5');
