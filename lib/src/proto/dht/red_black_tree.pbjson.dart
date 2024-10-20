//
//  Generated code. Do not modify.
//  source: red_black_tree.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use redBlackTreeNodeDescriptor instead')
const RedBlackTreeNode$json = {
  '1': 'RedBlackTreeNode',
  '2': [
    {'1': 'K', '3': 1, '4': 1, '5': 5, '10': 'K'},
    {'1': 'V', '3': 2, '4': 1, '5': 11, '6': '.ipfs.dht.common.Node', '10': 'V'},
    {'1': 'color', '3': 3, '4': 1, '5': 14, '6': '.ipfs.dht.common.NodeColor', '10': 'color'},
    {'1': 'left_child', '3': 4, '4': 1, '5': 11, '6': '.ipfs.dht.red_black_tree.RedBlackTreeNode', '10': 'leftChild'},
    {'1': 'right_child', '3': 5, '4': 1, '5': 11, '6': '.ipfs.dht.red_black_tree.RedBlackTreeNode', '10': 'rightChild'},
  ],
};

/// Descriptor for `RedBlackTreeNode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List redBlackTreeNodeDescriptor = $convert.base64Decode(
    'ChBSZWRCbGFja1RyZWVOb2RlEgwKAUsYASABKAVSAUsSIwoBVhgCIAEoCzIVLmlwZnMuZGh0Lm'
    'NvbW1vbi5Ob2RlUgFWEjAKBWNvbG9yGAMgASgOMhouaXBmcy5kaHQuY29tbW9uLk5vZGVDb2xv'
    'clIFY29sb3ISSAoKbGVmdF9jaGlsZBgEIAEoCzIpLmlwZnMuZGh0LnJlZF9ibGFja190cmVlLl'
    'JlZEJsYWNrVHJlZU5vZGVSCWxlZnRDaGlsZBJKCgtyaWdodF9jaGlsZBgFIAEoCzIpLmlwZnMu'
    'ZGh0LnJlZF9ibGFja190cmVlLlJlZEJsYWNrVHJlZU5vZGVSCnJpZ2h0Q2hpbGQ=');

