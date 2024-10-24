//
//  Generated code. Do not modify.
//  source: cid.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use cIDVersionDescriptor instead')
const CIDVersion$json = {
  '1': 'CIDVersion',
  '2': [
    {'1': 'CID_VERSION_UNSPECIFIED', '2': 0},
    {'1': 'CID_VERSION_0', '2': 1},
    {'1': 'CID_VERSION_1', '2': 2},
  ],
};

/// Descriptor for `CIDVersion`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List cIDVersionDescriptor = $convert.base64Decode(
    'CgpDSURWZXJzaW9uEhsKF0NJRF9WRVJTSU9OX1VOU1BFQ0lGSUVEEAASEQoNQ0lEX1ZFUlNJT0'
    '5fMBABEhEKDUNJRF9WRVJTSU9OXzEQAg==');

@$core.Deprecated('Use cIDDescriptor instead')
const CID$json = {
  '1': 'CID',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 14, '6': '.ipfs.core.data_structures.CIDVersion', '10': 'version'},
    {'1': 'multihash', '3': 2, '4': 1, '5': 12, '10': 'multihash'},
    {'1': 'codec', '3': 3, '4': 1, '5': 9, '10': 'codec'},
  ],
};

/// Descriptor for `CID`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cIDDescriptor = $convert.base64Decode(
    'CgNDSUQSPwoHdmVyc2lvbhgBIAEoDjIlLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuQ0lEVm'
    'Vyc2lvblIHdmVyc2lvbhIcCgltdWx0aWhhc2gYAiABKAxSCW11bHRpaGFzaBIUCgVjb2RlYxgD'
    'IAEoCVIFY29kZWM=');

