// This is a generated file - do not edit.
//
// Generated from dht/common_red_black_tree.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Defines an enum representing the color of a node in a tree structure.
class NodeColor extends $pb.ProtobufEnum {
  /// Represents the color red, typically used in red-black trees.
  static const NodeColor RED = NodeColor._(0, _omitEnumNames ? '' : 'RED');

  /// Represents the color black, typically used in red-black trees.
  static const NodeColor BLACK = NodeColor._(1, _omitEnumNames ? '' : 'BLACK');

  static const $core.List<NodeColor> values = <NodeColor>[
    RED,
    BLACK,
  ];

  static final $core.List<NodeColor?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static NodeColor? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const NodeColor._(super.value, super.name);
}

/// The current connection status of the peer.
class V_PeerInfo_ConnectionStatus extends $pb.ProtobufEnum {
  static const V_PeerInfo_ConnectionStatus DISCONNECTED =
      V_PeerInfo_ConnectionStatus._(0, _omitEnumNames ? '' : 'DISCONNECTED');
  static const V_PeerInfo_ConnectionStatus CONNECTING =
      V_PeerInfo_ConnectionStatus._(1, _omitEnumNames ? '' : 'CONNECTING');
  static const V_PeerInfo_ConnectionStatus CONNECTED =
      V_PeerInfo_ConnectionStatus._(2, _omitEnumNames ? '' : 'CONNECTED');

  static const $core.List<V_PeerInfo_ConnectionStatus> values =
      <V_PeerInfo_ConnectionStatus>[
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
  ];

  static final $core.List<V_PeerInfo_ConnectionStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static V_PeerInfo_ConnectionStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const V_PeerInfo_ConnectionStatus._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');

