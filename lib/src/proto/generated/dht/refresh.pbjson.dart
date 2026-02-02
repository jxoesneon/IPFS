// This is a generated file - do not edit.
//
// Generated from dht/refresh.proto.

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

@$core.Deprecated('Use refreshRequestDescriptor instead')
const RefreshRequest$json = {
  '1': 'RefreshRequest',
};

/// Descriptor for `RefreshRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshRequestDescriptor =
    $convert.base64Decode('Cg5SZWZyZXNoUmVxdWVzdA==');

@$core.Deprecated('Use refreshResponseDescriptor instead')
const RefreshResponse$json = {
  '1': 'RefreshResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `RefreshResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshResponseDescriptor = $convert.base64Decode(
    'Cg9SZWZyZXNoUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2Vzcw==');
