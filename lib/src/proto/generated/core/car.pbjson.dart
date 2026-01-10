//
//  Generated code. Do not modify.
//  source: core/car.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use carProtoDescriptor instead')
const CarProto$json = {
  '1': 'CarProto',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 5, '10': 'version'},
    {'1': 'characteristics', '3': 2, '4': 3, '5': 9, '10': 'characteristics'},
    {
      '1': 'pragma',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.ipfs.core.data_structures.CarProto.PragmaEntry',
      '10': 'pragma'
    },
    {
      '1': 'blocks',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.ipfs.core.data_structures.BlockProto',
      '10': 'blocks'
    },
    {
      '1': 'index',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.data_structures.CarIndex',
      '10': 'index'
    },
    {
      '1': 'header',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.ipfs.core.data_structures.CarHeader',
      '10': 'header'
    },
  ],
  '3': [CarProto_PragmaEntry$json],
};

@$core.Deprecated('Use carProtoDescriptor instead')
const CarProto_PragmaEntry$json = {
  '1': 'PragmaEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Any',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `CarProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List carProtoDescriptor = $convert.base64Decode(
    'CghDYXJQcm90bxIYCgd2ZXJzaW9uGAEgASgFUgd2ZXJzaW9uEigKD2NoYXJhY3RlcmlzdGljcx'
    'gCIAMoCVIPY2hhcmFjdGVyaXN0aWNzEkcKBnByYWdtYRgDIAMoCzIvLmlwZnMuY29yZS5kYXRh'
    'X3N0cnVjdHVyZXMuQ2FyUHJvdG8uUHJhZ21hRW50cnlSBnByYWdtYRI9CgZibG9ja3MYBCADKA'
    'syJS5pcGZzLmNvcmUuZGF0YV9zdHJ1Y3R1cmVzLkJsb2NrUHJvdG9SBmJsb2NrcxI5CgVpbmRl'
    'eBgFIAEoCzIjLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuQ2FySW5kZXhSBWluZGV4EjwKBm'
    'hlYWRlchgGIAEoCzIkLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZXMuQ2FySGVhZGVyUgZoZWFk'
    'ZXIaTwoLUHJhZ21hRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSKgoFdmFsdWUYAiABKAsyFC5nb2'
    '9nbGUucHJvdG9idWYuQW55UgV2YWx1ZToCOAE=');

@$core.Deprecated('Use carHeaderDescriptor instead')
const CarHeader$json = {
  '1': 'CarHeader',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 5, '10': 'version'},
    {'1': 'characteristics', '3': 2, '4': 3, '5': 9, '10': 'characteristics'},
    {
      '1': 'roots',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.ipfs.core.IPFSCIDProto',
      '10': 'roots'
    },
    {
      '1': 'pragma',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.ipfs.core.data_structures.CarHeader.PragmaEntry',
      '10': 'pragma'
    },
  ],
  '3': [CarHeader_PragmaEntry$json],
};

@$core.Deprecated('Use carHeaderDescriptor instead')
const CarHeader_PragmaEntry$json = {
  '1': 'PragmaEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Any',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `CarHeader`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List carHeaderDescriptor = $convert.base64Decode(
    'CglDYXJIZWFkZXISGAoHdmVyc2lvbhgBIAEoBVIHdmVyc2lvbhIoCg9jaGFyYWN0ZXJpc3RpY3'
    'MYAiADKAlSD2NoYXJhY3RlcmlzdGljcxItCgVyb290cxgDIAMoCzIXLmlwZnMuY29yZS5JUEZT'
    'Q0lEUHJvdG9SBXJvb3RzEkgKBnByYWdtYRgEIAMoCzIwLmlwZnMuY29yZS5kYXRhX3N0cnVjdH'
    'VyZXMuQ2FySGVhZGVyLlByYWdtYUVudHJ5UgZwcmFnbWEaTwoLUHJhZ21hRW50cnkSEAoDa2V5'
    'GAEgASgJUgNrZXkSKgoFdmFsdWUYAiABKAsyFC5nb29nbGUucHJvdG9idWYuQW55UgV2YWx1ZT'
    'oCOAE=');

@$core.Deprecated('Use carIndexDescriptor instead')
const CarIndex$json = {
  '1': 'CarIndex',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.ipfs.core.data_structures.IndexEntry',
      '10': 'entries'
    },
  ],
};

/// Descriptor for `CarIndex`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List carIndexDescriptor = $convert.base64Decode(
    'CghDYXJJbmRleBI/CgdlbnRyaWVzGAEgAygLMiUuaXBmcy5jb3JlLmRhdGFfc3RydWN0dXJlcy'
    '5JbmRleEVudHJ5UgdlbnRyaWVz');

@$core.Deprecated('Use indexEntryDescriptor instead')
const IndexEntry$json = {
  '1': 'IndexEntry',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 9, '10': 'cid'},
    {'1': 'offset', '3': 2, '4': 1, '5': 3, '10': 'offset'},
    {'1': 'length', '3': 3, '4': 1, '5': 3, '10': 'length'},
  ],
};

/// Descriptor for `IndexEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List indexEntryDescriptor = $convert.base64Decode(
    'CgpJbmRleEVudHJ5EhAKA2NpZBgBIAEoCVIDY2lkEhYKBm9mZnNldBgCIAEoA1IGb2Zmc2V0Eh'
    'YKBmxlbmd0aBgDIAEoA1IGbGVuZ3Ro');
