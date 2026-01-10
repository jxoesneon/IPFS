//
//  Generated code. Do not modify.
//  source: dht/routing_table.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use routingTableProtoDescriptor instead')
const RoutingTableProto$json = {
  '1': 'RoutingTableProto',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.ipfs.dht.routing_table.RoutingTableProto.EntriesEntry', '10': 'entries'},
  ],
  '3': [RoutingTableProto_EntriesEntry$json],
};

@$core.Deprecated('Use routingTableProtoDescriptor instead')
const RoutingTableProto_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.ipfs.dht.kademlia_node.KademliaNode', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `RoutingTableProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List routingTableProtoDescriptor = $convert.base64Decode(
    'ChFSb3V0aW5nVGFibGVQcm90bxJQCgdlbnRyaWVzGAEgAygLMjYuaXBmcy5kaHQucm91dGluZ1'
    '90YWJsZS5Sb3V0aW5nVGFibGVQcm90by5FbnRyaWVzRW50cnlSB2VudHJpZXMaYAoMRW50cmll'
    'c0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EjoKBXZhbHVlGAIgASgLMiQuaXBmcy5kaHQua2FkZW'
    '1saWFfbm9kZS5LYWRlbWxpYU5vZGVSBXZhbHVlOgI4AQ==');

