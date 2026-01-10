//
//  Generated code. Do not modify.
//  source: ipns.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use ipnsEntryDescriptor instead')
const IpnsEntry$json = {
  '1': 'IpnsEntry',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 12, '10': 'value'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {
      '1': 'validityType',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.ipfs.ipns.IpnsEntry.ValidityType',
      '10': 'validityType'
    },
    {'1': 'validity', '3': 4, '4': 1, '5': 12, '10': 'validity'},
    {'1': 'sequence', '3': 5, '4': 1, '5': 4, '10': 'sequence'},
    {'1': 'ttl', '3': 6, '4': 1, '5': 4, '10': 'ttl'},
    {'1': 'pubKey', '3': 7, '4': 1, '5': 12, '10': 'pubKey'},
  ],
  '4': [IpnsEntry_ValidityType$json],
};

@$core.Deprecated('Use ipnsEntryDescriptor instead')
const IpnsEntry_ValidityType$json = {
  '1': 'ValidityType',
  '2': [
    {'1': 'EOL', '2': 0},
  ],
};

/// Descriptor for `IpnsEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ipnsEntryDescriptor = $convert.base64Decode(
    'CglJcG5zRW50cnkSFAoFdmFsdWUYASABKAxSBXZhbHVlEhwKCXNpZ25hdHVyZRgCIAEoDFIJc2'
    'lnbmF0dXJlEkUKDHZhbGlkaXR5VHlwZRgDIAEoDjIhLmlwZnMuaXBucy5JcG5zRW50cnkuVmFs'
    'aWRpdHlUeXBlUgx2YWxpZGl0eVR5cGUSGgoIdmFsaWRpdHkYBCABKAxSCHZhbGlkaXR5EhoKCH'
    'NlcXVlbmNlGAUgASgEUghzZXF1ZW5jZRIQCgN0dGwYBiABKARSA3R0bBIWCgZwdWJLZXkYByAB'
    'KAxSBnB1YktleSIXCgxWYWxpZGl0eVR5cGUSBwoDRU9MEAA=');
