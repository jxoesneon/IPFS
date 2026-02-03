// This is a generated file - do not edit.
//
// Generated from core/dag.proto.

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

@$core.Deprecated('Use pBLinkDescriptor instead')
const PBLink$json = {
  '1': 'PBLink',
  '2': [
    {'1': 'hash', '3': 1, '4': 1, '5': 12, '10': 'hash'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'size', '3': 3, '4': 1, '5': 4, '10': 'size'},
  ],
};

/// Descriptor for `PBLink`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pBLinkDescriptor = $convert.base64Decode(
    'CgZQQkxpbmsSEgoEaGFzaBgBIAEoDFIEaGFzaBISCgRuYW1lGAIgASgJUgRuYW1lEhIKBHNpem'
    'UYAyABKARSBHNpemU=');

@$core.Deprecated('Use pBNodeDescriptor instead')
const PBNode$json = {
  '1': 'PBNode',
  '2': [
    {
      '1': 'links',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.ipfs.core.data_structures.PBLink',
      '10': 'links'
    },
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `PBNode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pBNodeDescriptor = $convert.base64Decode(
    'CgZQQk5vZGUSNwoFbGlua3MYAiADKAsyIS5pcGZzLmNvcmUuZGF0YV9zdHJ1Y3R1cmVzLlBCTG'
    'lua1IFbGlua3MSEgoEZGF0YRgBIAEoDFIEZGF0YQ==');
