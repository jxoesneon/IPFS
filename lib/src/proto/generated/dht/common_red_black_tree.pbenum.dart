//
//  Generated code. Do not modify.
//  source: dht/common_red_black_tree.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Defines an enum representing the color of a node in a tree structure.
class NodeColor extends $pb.ProtobufEnum {
  static const NodeColor RED = NodeColor._(0, _omitEnumNames ? '' : 'RED');
  static const NodeColor BLACK = NodeColor._(1, _omitEnumNames ? '' : 'BLACK');

  static const $core.List<NodeColor> values = <NodeColor> [
    RED,
    BLACK,
  ];

  static final $core.Map<$core.int, NodeColor> _byValue = $pb.ProtobufEnum.initByValue(values);
  static NodeColor? valueOf($core.int value) => _byValue[value];

  const NodeColor._($core.int v, $core.String n) : super(v, n);
}

/// The current connection status of the peer.
class V_PeerInfo_ConnectionStatus extends $pb.ProtobufEnum {
  static const V_PeerInfo_ConnectionStatus DISCONNECTED = V_PeerInfo_ConnectionStatus._(0, _omitEnumNames ? '' : 'DISCONNECTED');
  static const V_PeerInfo_ConnectionStatus CONNECTING = V_PeerInfo_ConnectionStatus._(1, _omitEnumNames ? '' : 'CONNECTING');
  static const V_PeerInfo_ConnectionStatus CONNECTED = V_PeerInfo_ConnectionStatus._(2, _omitEnumNames ? '' : 'CONNECTED');

  static const $core.List<V_PeerInfo_ConnectionStatus> values = <V_PeerInfo_ConnectionStatus> [
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
  ];

  static final $core.Map<$core.int, V_PeerInfo_ConnectionStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static V_PeerInfo_ConnectionStatus? valueOf($core.int value) => _byValue[value];

  const V_PeerInfo_ConnectionStatus._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
