//
//  Generated code. Do not modify.
//  source: node_stats.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use nodeStatsDescriptor instead')
const NodeStats$json = {
  '1': 'NodeStats',
  '2': [
    {'1': 'num_blocks', '3': 1, '4': 1, '5': 5, '10': 'numBlocks'},
    {'1': 'datastore_size', '3': 2, '4': 1, '5': 3, '10': 'datastoreSize'},
    {'1': 'num_connected_peers', '3': 3, '4': 1, '5': 5, '10': 'numConnectedPeers'},
    {'1': 'bandwidth_sent', '3': 4, '4': 1, '5': 3, '10': 'bandwidthSent'},
    {'1': 'bandwidth_received', '3': 5, '4': 1, '5': 3, '10': 'bandwidthReceived'},
  ],
};

/// Descriptor for `NodeStats`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeStatsDescriptor = $convert.base64Decode(
    'CglOb2RlU3RhdHMSHQoKbnVtX2Jsb2NrcxgBIAEoBVIJbnVtQmxvY2tzEiUKDmRhdGFzdG9yZV'
    '9zaXplGAIgASgDUg1kYXRhc3RvcmVTaXplEi4KE251bV9jb25uZWN0ZWRfcGVlcnMYAyABKAVS'
    'EW51bUNvbm5lY3RlZFBlZXJzEiUKDmJhbmR3aWR0aF9zZW50GAQgASgDUg1iYW5kd2lkdGhTZW'
    '50Ei0KEmJhbmR3aWR0aF9yZWNlaXZlZBgFIAEoA1IRYmFuZHdpZHRoUmVjZWl2ZWQ=');

