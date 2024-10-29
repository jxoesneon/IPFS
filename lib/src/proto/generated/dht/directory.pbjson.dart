//
//  Generated code. Do not modify.
//  source: dht/directory.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use directoryEntryDescriptor instead')
const DirectoryEntry$json = {
  '1': 'DirectoryEntry',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'hash', '3': 2, '4': 1, '5': 12, '10': 'hash'},
    {'1': 'size', '3': 3, '4': 1, '5': 3, '10': 'size'},
    {'1': 'is_directory', '3': 4, '4': 1, '5': 8, '10': 'isDirectory'},
  ],
};

/// Descriptor for `DirectoryEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List directoryEntryDescriptor = $convert.base64Decode(
    'Cg5EaXJlY3RvcnlFbnRyeRISCgRuYW1lGAEgASgJUgRuYW1lEhIKBGhhc2gYAiABKAxSBGhhc2'
    'gSEgoEc2l6ZRgDIAEoA1IEc2l6ZRIhCgxpc19kaXJlY3RvcnkYBCABKAhSC2lzRGlyZWN0b3J5');

@$core.Deprecated('Use directoryDescriptor instead')
const Directory$json = {
  '1': 'Directory',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.DirectoryEntry', '10': 'entries'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {'1': 'total_size', '3': 3, '4': 1, '5': 3, '10': 'totalSize'},
    {'1': 'number_of_files', '3': 4, '4': 1, '5': 5, '10': 'numberOfFiles'},
    {'1': 'number_of_directories', '3': 5, '4': 1, '5': 5, '10': 'numberOfDirectories'},
  ],
};

/// Descriptor for `Directory`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List directoryDescriptor = $convert.base64Decode(
    'CglEaXJlY3RvcnkSQwoHZW50cmllcxgBIAMoCzIpLmlwZnMuY29yZS5kYXRhX3N0cnVjdHVyZX'
    'MuRGlyZWN0b3J5RW50cnlSB2VudHJpZXMSEgoEcGF0aBgCIAEoCVIEcGF0aBIdCgp0b3RhbF9z'
    'aXplGAMgASgDUgl0b3RhbFNpemUSJgoPbnVtYmVyX29mX2ZpbGVzGAQgASgFUg1udW1iZXJPZk'
    'ZpbGVzEjIKFW51bWJlcl9vZl9kaXJlY3RvcmllcxgFIAEoBVITbnVtYmVyT2ZEaXJlY3Rvcmll'
    'cw==');

@$core.Deprecated('Use addDirectoryEntryRequestDescriptor instead')
const AddDirectoryEntryRequest$json = {
  '1': 'AddDirectoryEntryRequest',
  '2': [
    {'1': 'entry', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.DirectoryEntry', '10': 'entry'},
  ],
};

/// Descriptor for `AddDirectoryEntryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addDirectoryEntryRequestDescriptor = $convert.base64Decode(
    'ChhBZGREaXJlY3RvcnlFbnRyeVJlcXVlc3QSPwoFZW50cnkYASABKAsyKS5pcGZzLmNvcmUuZG'
    'F0YV9zdHJ1Y3R1cmVzLkRpcmVjdG9yeUVudHJ5UgVlbnRyeQ==');

@$core.Deprecated('Use addDirectoryEntryResponseDescriptor instead')
const AddDirectoryEntryResponse$json = {
  '1': 'AddDirectoryEntryResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `AddDirectoryEntryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addDirectoryEntryResponseDescriptor = $convert.base64Decode(
    'ChlBZGREaXJlY3RvcnlFbnRyeVJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3M=');

@$core.Deprecated('Use removeDirectoryEntryRequestDescriptor instead')
const RemoveDirectoryEntryRequest$json = {
  '1': 'RemoveDirectoryEntryRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `RemoveDirectoryEntryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeDirectoryEntryRequestDescriptor = $convert.base64Decode(
    'ChtSZW1vdmVEaXJlY3RvcnlFbnRyeVJlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use removeDirectoryEntryResponseDescriptor instead')
const RemoveDirectoryEntryResponse$json = {
  '1': 'RemoveDirectoryEntryResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `RemoveDirectoryEntryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeDirectoryEntryResponseDescriptor = $convert.base64Decode(
    'ChxSZW1vdmVEaXJlY3RvcnlFbnRyeVJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3'
    'M=');

@$core.Deprecated('Use listDirectoryRequestDescriptor instead')
const ListDirectoryRequest$json = {
  '1': 'ListDirectoryRequest',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `ListDirectoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDirectoryRequestDescriptor = $convert.base64Decode(
    'ChRMaXN0RGlyZWN0b3J5UmVxdWVzdBISCgRwYXRoGAEgASgJUgRwYXRo');

@$core.Deprecated('Use listDirectoryResponseDescriptor instead')
const ListDirectoryResponse$json = {
  '1': 'ListDirectoryResponse',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.ipfs.core.data_structures.DirectoryEntry', '10': 'entries'},
  ],
};

/// Descriptor for `ListDirectoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDirectoryResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0RGlyZWN0b3J5UmVzcG9uc2USQwoHZW50cmllcxgBIAMoCzIpLmlwZnMuY29yZS5kYX'
    'RhX3N0cnVjdHVyZXMuRGlyZWN0b3J5RW50cnlSB2VudHJpZXM=');

@$core.Deprecated('Use getDirectoryEntryRequestDescriptor instead')
const GetDirectoryEntryRequest$json = {
  '1': 'GetDirectoryEntryRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `GetDirectoryEntryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getDirectoryEntryRequestDescriptor = $convert.base64Decode(
    'ChhHZXREaXJlY3RvcnlFbnRyeVJlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use getDirectoryEntryResponseDescriptor instead')
const GetDirectoryEntryResponse$json = {
  '1': 'GetDirectoryEntryResponse',
  '2': [
    {'1': 'entry', '3': 1, '4': 1, '5': 11, '6': '.ipfs.core.data_structures.DirectoryEntry', '10': 'entry'},
  ],
};

/// Descriptor for `GetDirectoryEntryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getDirectoryEntryResponseDescriptor = $convert.base64Decode(
    'ChlHZXREaXJlY3RvcnlFbnRyeVJlc3BvbnNlEj8KBWVudHJ5GAEgASgLMikuaXBmcy5jb3JlLm'
    'RhdGFfc3RydWN0dXJlcy5EaXJlY3RvcnlFbnRyeVIFZW50cnk=');

