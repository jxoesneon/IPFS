// This is a generated file - do not edit.
//
// Generated from ipld/data_model.proto.

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

@$core.Deprecated('Use kindDescriptor instead')
const Kind$json = {
  '1': 'Kind',
  '2': [
    {'1': 'NULL', '2': 0},
    {'1': 'BOOL', '2': 1},
    {'1': 'INTEGER', '2': 2},
    {'1': 'FLOAT', '2': 3},
    {'1': 'STRING', '2': 4},
    {'1': 'BYTES', '2': 5},
    {'1': 'LIST', '2': 6},
    {'1': 'MAP', '2': 7},
    {'1': 'LINK', '2': 8},
    {'1': 'BIG_INT', '2': 9},
  ],
};

/// Descriptor for `Kind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List kindDescriptor = $convert.base64Decode(
    'CgRLaW5kEggKBE5VTEwQABIICgRCT09MEAESCwoHSU5URUdFUhACEgkKBUZMT0FUEAMSCgoGU1'
    'RSSU5HEAQSCQoFQllURVMQBRIICgRMSVNUEAYSBwoDTUFQEAcSCAoETElOSxAIEgsKB0JJR19J'
    'TlQQCQ==');

@$core.Deprecated('Use iPLDNodeDescriptor instead')
const IPLDNode$json = {
  '1': 'IPLDNode',
  '2': [
    {'1': 'kind', '3': 1, '4': 1, '5': 14, '6': '.ipld.Kind', '10': 'kind'},
    {'1': 'bool_value', '3': 2, '4': 1, '5': 8, '9': 0, '10': 'boolValue'},
    {'1': 'int_value', '3': 3, '4': 1, '5': 18, '9': 0, '10': 'intValue'},
    {'1': 'float_value', '3': 4, '4': 1, '5': 1, '9': 0, '10': 'floatValue'},
    {'1': 'string_value', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'stringValue'},
    {'1': 'bytes_value', '3': 6, '4': 1, '5': 12, '9': 0, '10': 'bytesValue'},
    {
      '1': 'list_value',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.ipld.IPLDList',
      '9': 0,
      '10': 'listValue'
    },
    {
      '1': 'map_value',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.ipld.IPLDMap',
      '9': 0,
      '10': 'mapValue'
    },
    {
      '1': 'link_value',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.ipld.IPLDLink',
      '9': 0,
      '10': 'linkValue'
    },
    {
      '1': 'big_int_value',
      '3': 10,
      '4': 1,
      '5': 12,
      '9': 0,
      '10': 'bigIntValue'
    },
  ],
  '8': [
    {'1': 'value'},
  ],
};

/// Descriptor for `IPLDNode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iPLDNodeDescriptor = $convert.base64Decode(
    'CghJUExETm9kZRIeCgRraW5kGAEgASgOMgouaXBsZC5LaW5kUgRraW5kEh8KCmJvb2xfdmFsdW'
    'UYAiABKAhIAFIJYm9vbFZhbHVlEh0KCWludF92YWx1ZRgDIAEoEkgAUghpbnRWYWx1ZRIhCgtm'
    'bG9hdF92YWx1ZRgEIAEoAUgAUgpmbG9hdFZhbHVlEiMKDHN0cmluZ192YWx1ZRgFIAEoCUgAUg'
    'tzdHJpbmdWYWx1ZRIhCgtieXRlc192YWx1ZRgGIAEoDEgAUgpieXRlc1ZhbHVlEi8KCmxpc3Rf'
    'dmFsdWUYByABKAsyDi5pcGxkLklQTERMaXN0SABSCWxpc3RWYWx1ZRIsCgltYXBfdmFsdWUYCC'
    'ABKAsyDS5pcGxkLklQTERNYXBIAFIIbWFwVmFsdWUSLwoKbGlua192YWx1ZRgJIAEoCzIOLmlw'
    'bGQuSVBMRExpbmtIAFIJbGlua1ZhbHVlEiQKDWJpZ19pbnRfdmFsdWUYCiABKAxIAFILYmlnSW'
    '50VmFsdWVCBwoFdmFsdWU=');

@$core.Deprecated('Use iPLDListDescriptor instead')
const IPLDList$json = {
  '1': 'IPLDList',
  '2': [
    {
      '1': 'values',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.ipld.IPLDNode',
      '10': 'values'
    },
  ],
};

/// Descriptor for `IPLDList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iPLDListDescriptor = $convert.base64Decode(
    'CghJUExETGlzdBImCgZ2YWx1ZXMYASADKAsyDi5pcGxkLklQTEROb2RlUgZ2YWx1ZXM=');

@$core.Deprecated('Use iPLDMapDescriptor instead')
const IPLDMap$json = {
  '1': 'IPLDMap',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.ipld.MapEntry',
      '10': 'entries'
    },
  ],
};

/// Descriptor for `IPLDMap`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iPLDMapDescriptor = $convert.base64Decode(
    'CgdJUExETWFwEigKB2VudHJpZXMYASADKAsyDi5pcGxkLk1hcEVudHJ5UgdlbnRyaWVz');

@$core.Deprecated('Use mapEntryDescriptor instead')
const MapEntry$json = {
  '1': 'MapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.ipld.IPLDNode',
      '10': 'value'
    },
  ],
};

/// Descriptor for `MapEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mapEntryDescriptor = $convert.base64Decode(
    'CghNYXBFbnRyeRIQCgNrZXkYASABKAlSA2tleRIkCgV2YWx1ZRgCIAEoCzIOLmlwbGQuSVBMRE'
    '5vZGVSBXZhbHVl');

@$core.Deprecated('Use iPLDLinkDescriptor instead')
const IPLDLink$json = {
  '1': 'IPLDLink',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 13, '10': 'version'},
    {'1': 'codec', '3': 2, '4': 1, '5': 9, '10': 'codec'},
    {'1': 'multihash', '3': 3, '4': 1, '5': 12, '10': 'multihash'},
  ],
};

/// Descriptor for `IPLDLink`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iPLDLinkDescriptor = $convert.base64Decode(
    'CghJUExETGluaxIYCgd2ZXJzaW9uGAEgASgNUgd2ZXJzaW9uEhQKBWNvZGVjGAIgASgJUgVjb2'
    'RlYxIcCgltdWx0aWhhc2gYAyABKAxSCW11bHRpaGFzaA==');
