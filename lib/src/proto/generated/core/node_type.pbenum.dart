//
//  Generated code. Do not modify.
//  source: core/node_type.proto
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
  static const NodeTypeProto NODE_TYPE_UNSPECIFIED = NodeTypeProto._(0, _omitEnumNames ? '' : 'NODE_TYPE_UNSPECIFIED');
  static const NodeTypeProto NODE_TYPE_FILE = NodeTypeProto._(1, _omitEnumNames ? '' : 'NODE_TYPE_FILE');
  static const NodeTypeProto NODE_TYPE_DIRECTORY = NodeTypeProto._(2, _omitEnumNames ? '' : 'NODE_TYPE_DIRECTORY');
  static const NodeTypeProto NODE_TYPE_SYMLINK = NodeTypeProto._(3, _omitEnumNames ? '' : 'NODE_TYPE_SYMLINK');
  static const NodeTypeProto NODE_TYPE_REGULAR = NodeTypeProto._(4, _omitEnumNames ? '' : 'NODE_TYPE_REGULAR');
  static const NodeTypeProto NODE_TYPE_BOOTSTRAP = NodeTypeProto._(5, _omitEnumNames ? '' : 'NODE_TYPE_BOOTSTRAP');
  static const NodeTypeProto NODE_TYPE_RELAY = NodeTypeProto._(6, _omitEnumNames ? '' : 'NODE_TYPE_RELAY');
  static const NodeTypeProto NODE_TYPE_GATEWAY = NodeTypeProto._(7, _omitEnumNames ? '' : 'NODE_TYPE_GATEWAY');
  static const NodeTypeProto NODE_TYPE_ARCHIVAL = NodeTypeProto._(8, _omitEnumNames ? '' : 'NODE_TYPE_ARCHIVAL');

  static const $core.List<NodeTypeProto> values = <NodeTypeProto> [
    NODE_TYPE_UNSPECIFIED,
    NODE_TYPE_FILE,
    NODE_TYPE_DIRECTORY,
    NODE_TYPE_SYMLINK,
    NODE_TYPE_REGULAR,
    NODE_TYPE_BOOTSTRAP,
    NODE_TYPE_RELAY,
    NODE_TYPE_GATEWAY,
    NODE_TYPE_ARCHIVAL,
  ];

  static final $core.Map<$core.int, NodeTypeProto> _byValue = $pb.ProtobufEnum.initByValue(values);
  static NodeTypeProto? valueOf($core.int value) => _byValue[value];

  const NodeTypeProto._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
