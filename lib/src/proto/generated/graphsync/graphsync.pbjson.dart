// This is a generated file - do not edit.
//
// Generated from graphsync/graphsync.proto.

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

@$core.Deprecated('Use responseStatusDescriptor instead')
const ResponseStatus$json = {
  '1': 'ResponseStatus',
  '2': [
    {'1': 'RS_IN_PROGRESS', '2': 0},
    {'1': 'RS_COMPLETED', '2': 1},
    {'1': 'RS_REJECTED', '2': 2},
    {'1': 'RS_CANCELLED', '2': 3},
    {'1': 'RS_PAUSED', '2': 4},
    {'1': 'RS_ERROR', '2': 5},
    {'1': 'RS_PAUSED_PENDING_RESOURCES', '2': 6},
  ],
};

/// Descriptor for `ResponseStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List responseStatusDescriptor = $convert
    .base64Decode('Cg5SZXNwb25zZVN0YXR1cxISCg5SU19JTl9QUk9HUkVTUxAAEhAKDFJTX0NPTVBMRVRFRBABEg'
        '8KC1JTX1JFSkVDVEVEEAISEAoMUlNfQ0FOQ0VMTEVEEAMSDQoJUlNfUEFVU0VEEAQSDAoIUlNf'
        'RVJST1IQBRIfChtSU19QQVVTRURfUEVORElOR19SRVNPVVJDRVMQBg==');

@$core.Deprecated('Use graphsyncMessageDescriptor instead')
const GraphsyncMessage$json = {
  '1': 'GraphsyncMessage',
  '2': [
    {
      '1': 'requests',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.ipfs.graphsync.GraphsyncRequest',
      '10': 'requests'
    },
    {
      '1': 'responses',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.ipfs.graphsync.GraphsyncResponse',
      '10': 'responses'
    },
    {'1': 'blocks', '3': 3, '4': 3, '5': 11, '6': '.ipfs.graphsync.Block', '10': 'blocks'},
    {
      '1': 'extensions',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.ipfs.graphsync.GraphsyncMessage.ExtensionsEntry',
      '10': 'extensions'
    },
  ],
  '3': [GraphsyncMessage_ExtensionsEntry$json],
};

@$core.Deprecated('Use graphsyncMessageDescriptor instead')
const GraphsyncMessage_ExtensionsEntry$json = {
  '1': 'ExtensionsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `GraphsyncMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List graphsyncMessageDescriptor = $convert
    .base64Decode('ChBHcmFwaHN5bmNNZXNzYWdlEjwKCHJlcXVlc3RzGAEgAygLMiAuaXBmcy5ncmFwaHN5bmMuR3'
        'JhcGhzeW5jUmVxdWVzdFIIcmVxdWVzdHMSPwoJcmVzcG9uc2VzGAIgAygLMiEuaXBmcy5ncmFw'
        'aHN5bmMuR3JhcGhzeW5jUmVzcG9uc2VSCXJlc3BvbnNlcxItCgZibG9ja3MYAyADKAsyFS5pcG'
        'ZzLmdyYXBoc3luYy5CbG9ja1IGYmxvY2tzElAKCmV4dGVuc2lvbnMYBCADKAsyMC5pcGZzLmdy'
        'YXBoc3luYy5HcmFwaHN5bmNNZXNzYWdlLkV4dGVuc2lvbnNFbnRyeVIKZXh0ZW5zaW9ucxo9Cg'
        '9FeHRlbnNpb25zRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAxSBXZhbHVl'
        'OgI4AQ==');

@$core.Deprecated('Use graphsyncRequestDescriptor instead')
const GraphsyncRequest$json = {
  '1': 'GraphsyncRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
    {'1': 'root', '3': 2, '4': 1, '5': 12, '10': 'root'},
    {'1': 'selector', '3': 3, '4': 1, '5': 12, '10': 'selector'},
    {'1': 'priority', '3': 4, '4': 1, '5': 5, '10': 'priority'},
    {
      '1': 'extensions',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.ipfs.graphsync.GraphsyncRequest.ExtensionsEntry',
      '10': 'extensions'
    },
    {'1': 'cancel', '3': 6, '4': 1, '5': 8, '10': 'cancel'},
    {'1': 'pause', '3': 7, '4': 1, '5': 8, '10': 'pause'},
    {'1': 'unpause', '3': 8, '4': 1, '5': 8, '10': 'unpause'},
  ],
  '3': [GraphsyncRequest_ExtensionsEntry$json],
};

@$core.Deprecated('Use graphsyncRequestDescriptor instead')
const GraphsyncRequest_ExtensionsEntry$json = {
  '1': 'ExtensionsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `GraphsyncRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List graphsyncRequestDescriptor = $convert
    .base64Decode('ChBHcmFwaHN5bmNSZXF1ZXN0Eg4KAmlkGAEgASgFUgJpZBISCgRyb290GAIgASgMUgRyb290Eh'
        'oKCHNlbGVjdG9yGAMgASgMUghzZWxlY3RvchIaCghwcmlvcml0eRgEIAEoBVIIcHJpb3JpdHkS'
        'UAoKZXh0ZW5zaW9ucxgFIAMoCzIwLmlwZnMuZ3JhcGhzeW5jLkdyYXBoc3luY1JlcXVlc3QuRX'
        'h0ZW5zaW9uc0VudHJ5UgpleHRlbnNpb25zEhYKBmNhbmNlbBgGIAEoCFIGY2FuY2VsEhQKBXBh'
        'dXNlGAcgASgIUgVwYXVzZRIYCgd1bnBhdXNlGAggASgIUgd1bnBhdXNlGj0KD0V4dGVuc2lvbn'
        'NFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoDFIFdmFsdWU6AjgB');

@$core.Deprecated('Use graphsyncResponseDescriptor instead')
const GraphsyncResponse$json = {
  '1': 'GraphsyncResponse',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 5, '10': 'id'},
    {'1': 'status', '3': 2, '4': 1, '5': 14, '6': '.ipfs.graphsync.ResponseStatus', '10': 'status'},
    {
      '1': 'extensions',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.ipfs.graphsync.GraphsyncResponse.ExtensionsEntry',
      '10': 'extensions'
    },
    {
      '1': 'metadata',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.ipfs.graphsync.GraphsyncResponse.MetadataEntry',
      '10': 'metadata'
    },
  ],
  '3': [GraphsyncResponse_ExtensionsEntry$json, GraphsyncResponse_MetadataEntry$json],
};

@$core.Deprecated('Use graphsyncResponseDescriptor instead')
const GraphsyncResponse_ExtensionsEntry$json = {
  '1': 'ExtensionsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use graphsyncResponseDescriptor instead')
const GraphsyncResponse_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `GraphsyncResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List graphsyncResponseDescriptor = $convert
    .base64Decode('ChFHcmFwaHN5bmNSZXNwb25zZRIOCgJpZBgBIAEoBVICaWQSNgoGc3RhdHVzGAIgASgOMh4uaX'
        'Bmcy5ncmFwaHN5bmMuUmVzcG9uc2VTdGF0dXNSBnN0YXR1cxJRCgpleHRlbnNpb25zGAMgAygL'
        'MjEuaXBmcy5ncmFwaHN5bmMuR3JhcGhzeW5jUmVzcG9uc2UuRXh0ZW5zaW9uc0VudHJ5UgpleH'
        'RlbnNpb25zEksKCG1ldGFkYXRhGAQgAygLMi8uaXBmcy5ncmFwaHN5bmMuR3JhcGhzeW5jUmVz'
        'cG9uc2UuTWV0YWRhdGFFbnRyeVIIbWV0YWRhdGEaPQoPRXh0ZW5zaW9uc0VudHJ5EhAKA2tleR'
        'gBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgMUgV2YWx1ZToCOAEaOwoNTWV0YWRhdGFFbnRyeRIQ'
        'CgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use blockDescriptor instead')
const Block$json = {
  '1': 'Block',
  '2': [
    {'1': 'prefix', '3': 1, '4': 1, '5': 12, '10': 'prefix'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `Block`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockDescriptor =
    $convert.base64Decode('CgVCbG9jaxIWCgZwcmVmaXgYASABKAxSBnByZWZpeBISCgRkYXRhGAIgASgMUgRkYXRh');
