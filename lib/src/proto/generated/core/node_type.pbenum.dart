//
//  Generated code. Do not modify.
//  source: node_type.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Enum representing the different types of nodes in the IPFS network.
class NodeTypeProto extends $pb.ProtobufEnum {
  static const NodeTypeProto REGULAR = NodeTypeProto._(0, _omitEnumNames ? '' : 'REGULAR');
  static const NodeTypeProto BOOTSTRAP = NodeTypeProto._(1, _omitEnumNames ? '' : 'BOOTSTRAP');
  static const NodeTypeProto RELAY = NodeTypeProto._(2, _omitEnumNames ? '' : 'RELAY');
  static const NodeTypeProto GATEWAY = NodeTypeProto._(3, _omitEnumNames ? '' : 'GATEWAY');
  static const NodeTypeProto ARCHIVAL = NodeTypeProto._(4, _omitEnumNames ? '' : 'ARCHIVAL');

  static const $core.List<NodeTypeProto> values = <NodeTypeProto> [
    REGULAR,
    BOOTSTRAP,
    RELAY,
    GATEWAY,
    ARCHIVAL,
  ];

  static final $core.Map<$core.int, NodeTypeProto> _byValue = $pb.ProtobufEnum.initByValue(values);
  static NodeTypeProto? valueOf($core.int value) => _byValue[value];

  const NodeTypeProto._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
