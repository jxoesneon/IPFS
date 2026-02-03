// This is a generated file - do not edit.
//
// Generated from core/cid.proto.

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

@$core.Deprecated('Use iPFSCIDVersionDescriptor instead')
const IPFSCIDVersion$json = {
  '1': 'IPFSCIDVersion',
  '2': [
    {'1': 'IPFS_CID_VERSION_UNSPECIFIED', '2': 0},
    {'1': 'IPFS_CID_VERSION_0', '2': 1},
    {'1': 'IPFS_CID_VERSION_1', '2': 2},
  ],
};

/// Descriptor for `IPFSCIDVersion`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List iPFSCIDVersionDescriptor = $convert.base64Decode(
    'Cg5JUEZTQ0lEVmVyc2lvbhIgChxJUEZTX0NJRF9WRVJTSU9OX1VOU1BFQ0lGSUVEEAASFgoSSV'
    'BGU19DSURfVkVSU0lPTl8wEAESFgoSSVBGU19DSURfVkVSU0lPTl8xEAI=');

@$core.Deprecated('Use iPFSCIDProtoDescriptor instead')
const IPFSCIDProto$json = {
  '1': 'IPFSCIDProto',
  '2': [
    {
      '1': 'version',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.ipfs.core.IPFSCIDVersion',
      '10': 'version'
    },
    {'1': 'multihash', '3': 2, '4': 1, '5': 12, '10': 'multihash'},
    {'1': 'codec', '3': 3, '4': 1, '5': 9, '10': 'codec'},
    {'1': 'multibase_prefix', '3': 4, '4': 1, '5': 9, '10': 'multibasePrefix'},
    {'1': 'codec_type', '3': 5, '4': 1, '5': 5, '10': 'codecType'},
  ],
};

/// Descriptor for `IPFSCIDProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iPFSCIDProtoDescriptor = $convert.base64Decode(
    'CgxJUEZTQ0lEUHJvdG8SMwoHdmVyc2lvbhgBIAEoDjIZLmlwZnMuY29yZS5JUEZTQ0lEVmVyc2'
    'lvblIHdmVyc2lvbhIcCgltdWx0aWhhc2gYAiABKAxSCW11bHRpaGFzaBIUCgVjb2RlYxgDIAEo'
    'CVIFY29kZWMSKQoQbXVsdGliYXNlX3ByZWZpeBgEIAEoCVIPbXVsdGliYXNlUHJlZml4Eh0KCm'
    'NvZGVjX3R5cGUYBSABKAVSCWNvZGVjVHlwZQ==');

