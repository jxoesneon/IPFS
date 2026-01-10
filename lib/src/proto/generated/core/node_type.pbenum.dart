// This is a generated file - do not edit.
//
// Generated from core/node_type.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Enum representing the different types of nodes in the IPFS network.
class NodeTypeProto extends $pb.ProtobufEnum {
  static const NodeTypeProto NODE_TYPE_UNSPECIFIED =
      NodeTypeProto._(0, _omitEnumNames ? '' : 'NODE_TYPE_UNSPECIFIED');
  static const NodeTypeProto NODE_TYPE_FILE =
      NodeTypeProto._(1, _omitEnumNames ? '' : 'NODE_TYPE_FILE');
  static const NodeTypeProto NODE_TYPE_DIRECTORY =
      NodeTypeProto._(2, _omitEnumNames ? '' : 'NODE_TYPE_DIRECTORY');
  static const NodeTypeProto NODE_TYPE_SYMLINK =
      NodeTypeProto._(3, _omitEnumNames ? '' : 'NODE_TYPE_SYMLINK');
  static const NodeTypeProto NODE_TYPE_REGULAR =
      NodeTypeProto._(4, _omitEnumNames ? '' : 'NODE_TYPE_REGULAR');
  static const NodeTypeProto NODE_TYPE_BOOTSTRAP =
      NodeTypeProto._(5, _omitEnumNames ? '' : 'NODE_TYPE_BOOTSTRAP');
  static const NodeTypeProto NODE_TYPE_RELAY =
      NodeTypeProto._(6, _omitEnumNames ? '' : 'NODE_TYPE_RELAY');
  static const NodeTypeProto NODE_TYPE_GATEWAY =
      NodeTypeProto._(7, _omitEnumNames ? '' : 'NODE_TYPE_GATEWAY');
  static const NodeTypeProto NODE_TYPE_ARCHIVAL =
      NodeTypeProto._(8, _omitEnumNames ? '' : 'NODE_TYPE_ARCHIVAL');

  static const $core.List<NodeTypeProto> values = <NodeTypeProto>[
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

  static final $core.List<NodeTypeProto?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 8);
  static NodeTypeProto? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const NodeTypeProto._(super.value, super.name);
}

const $core.bool _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
