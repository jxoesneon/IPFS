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
import 'package:dart_ipfs/src/proto/generated/google/protobuf/timestamp.pb.dart' as $0;

import 'common_red_black_tree.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'common_red_black_tree.pbenum.dart';

/// Defines a message representing a peer's unique identifier.
class RBTreePeerId extends $pb.GeneratedMessage {
  factory RBTreePeerId({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  RBTreePeerId._();

  factory RBTreePeerId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RBTreePeerId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RBTreePeerId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.common_red_black_tree'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RBTreePeerId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RBTreePeerId copyWith(void Function(RBTreePeerId) updates) =>
      super.copyWith((message) => updates(message as RBTreePeerId)) as RBTreePeerId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RBTreePeerId create() => RBTreePeerId._();
  @$core.override
  RBTreePeerId createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RBTreePeerId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RBTreePeerId>(create);
  static RBTreePeerId? _defaultInstance;

  /// The ID of the peer, represented as a string.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

/// Defines a message representing a node in a data structure.
class Node extends $pb.GeneratedMessage {
  factory Node({
    RBTreePeerId? peerId,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (data != null) result.data = data;
    return result;
  }

  Node._();

  factory Node.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Node.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Node',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.common_red_black_tree'),
      createEmptyInstance: create)
    ..aOM<RBTreePeerId>(1, _omitFieldNames ? '' : 'peerId', subBuilder: RBTreePeerId.create)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Node clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Node copyWith(void Function(Node) updates) =>
      super.copyWith((message) => updates(message as Node)) as Node;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Node create() => Node._();
  @$core.override
  Node createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Node getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Node>(create);
  static Node? _defaultInstance;

  /// The unique identifier of the peer associated with this node.
  @$pb.TagNumber(1)
  RBTreePeerId get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId(RBTreePeerId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);
  @$pb.TagNumber(1)
  RBTreePeerId ensurePeerId() => $_ensure(0);

  /// Arbitrary data associated with this node, represented as bytes.
  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
}

/// Defines a message representing a PeerId specifically for keys.
class K_PeerId extends $pb.GeneratedMessage {
  factory K_PeerId({
    $core.List<$core.int>? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  K_PeerId._();

  factory K_PeerId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory K_PeerId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'K_PeerId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.common_red_black_tree'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  K_PeerId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  K_PeerId copyWith(void Function(K_PeerId) updates) =>
      super.copyWith((message) => updates(message as K_PeerId)) as K_PeerId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static K_PeerId create() => K_PeerId._();
  @$core.override
  K_PeerId createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static K_PeerId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<K_PeerId>(create);
  static K_PeerId? _defaultInstance;

  /// The ID of the peer, represented as bytes.
  @$pb.TagNumber(1)
  $core.List<$core.int> get id => $_getN(0);
  @$pb.TagNumber(1)
  set id($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class V_PeerInfo extends $pb.GeneratedMessage {
  factory V_PeerInfo({
    $core.List<$core.int>? peerId,
    $core.String? ipAddress,
    $core.int? port,
    $core.Iterable<$core.String>? protocols,
    $core.int? latency,
    V_PeerInfo_ConnectionStatus? connectionStatus,
    $0.Timestamp? lastSeen,
    $core.String? agentVersion,
    $core.List<$core.int>? publicKey,
    $core.Iterable<$core.String>? addresses,
    $core.String? observedAddr,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (ipAddress != null) result.ipAddress = ipAddress;
    if (port != null) result.port = port;
    if (protocols != null) result.protocols.addAll(protocols);
    if (latency != null) result.latency = latency;
    if (connectionStatus != null) result.connectionStatus = connectionStatus;
    if (lastSeen != null) result.lastSeen = lastSeen;
    if (agentVersion != null) result.agentVersion = agentVersion;
    if (publicKey != null) result.publicKey = publicKey;
    if (addresses != null) result.addresses.addAll(addresses);
    if (observedAddr != null) result.observedAddr = observedAddr;
    return result;
  }

  V_PeerInfo._();

  factory V_PeerInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory V_PeerInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'V_PeerInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.common_red_black_tree'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'peerId', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'ipAddress')
    ..aI(3, _omitFieldNames ? '' : 'port')
    ..pPS(4, _omitFieldNames ? '' : 'protocols')
    ..aI(5, _omitFieldNames ? '' : 'latency')
    ..aE<V_PeerInfo_ConnectionStatus>(6, _omitFieldNames ? '' : 'connectionStatus',
        enumValues: V_PeerInfo_ConnectionStatus.values)
    ..aOM<$0.Timestamp>(7, _omitFieldNames ? '' : 'lastSeen', subBuilder: $0.Timestamp.create)
    ..aOS(8, _omitFieldNames ? '' : 'agentVersion')
    ..a<$core.List<$core.int>>(9, _omitFieldNames ? '' : 'publicKey', $pb.PbFieldType.OY)
    ..pPS(10, _omitFieldNames ? '' : 'addresses')
    ..aOS(11, _omitFieldNames ? '' : 'observedAddr')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  V_PeerInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  V_PeerInfo copyWith(void Function(V_PeerInfo) updates) =>
      super.copyWith((message) => updates(message as V_PeerInfo)) as V_PeerInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static V_PeerInfo create() => V_PeerInfo._();
  @$core.override
  V_PeerInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static V_PeerInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<V_PeerInfo>(create);
  static V_PeerInfo? _defaultInstance;

  /// The unique identifier of the peer.
  @$pb.TagNumber(1)
  $core.List<$core.int> get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  /// The IP address of the peer.
  @$pb.TagNumber(2)
  $core.String get ipAddress => $_getSZ(1);
  @$pb.TagNumber(2)
  set ipAddress($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIpAddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearIpAddress() => $_clearField(2);

  /// The port number on which the peer is listening for connections.
  @$pb.TagNumber(3)
  $core.int get port => $_getIZ(2);
  @$pb.TagNumber(3)
  set port($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPort() => $_has(2);
  @$pb.TagNumber(3)
  void clearPort() => $_clearField(3);

  /// A list of protocols supported by the peer.
  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get protocols => $_getList(3);

  /// The estimated latency to the peer, in milliseconds.
  @$pb.TagNumber(5)
  $core.int get latency => $_getIZ(4);
  @$pb.TagNumber(5)
  set latency($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLatency() => $_has(4);
  @$pb.TagNumber(5)
  void clearLatency() => $_clearField(5);

  @$pb.TagNumber(6)
  V_PeerInfo_ConnectionStatus get connectionStatus => $_getN(5);
  @$pb.TagNumber(6)
  set connectionStatus(V_PeerInfo_ConnectionStatus value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasConnectionStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearConnectionStatus() => $_clearField(6);

  /// The timestamp when the peer was last seen or contacted.
  @$pb.TagNumber(7)
  $0.Timestamp get lastSeen => $_getN(6);
  @$pb.TagNumber(7)
  set lastSeen($0.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasLastSeen() => $_has(6);
  @$pb.TagNumber(7)
  void clearLastSeen() => $_clearField(7);
  @$pb.TagNumber(7)
  $0.Timestamp ensureLastSeen() => $_ensure(6);

  /// The version of the IPFS agent or client running on the peer.
  @$pb.TagNumber(8)
  $core.String get agentVersion => $_getSZ(7);
  @$pb.TagNumber(8)
  set agentVersion($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAgentVersion() => $_has(7);
  @$pb.TagNumber(8)
  void clearAgentVersion() => $_clearField(8);

  /// The public key of the peer, used for authentication.
  @$pb.TagNumber(9)
  $core.List<$core.int> get publicKey => $_getN(8);
  @$pb.TagNumber(9)
  set publicKey($core.List<$core.int> value) => $_setBytes(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPublicKey() => $_has(8);
  @$pb.TagNumber(9)
  void clearPublicKey() => $_clearField(9);

  /// A list of multiaddresses for the peer.
  @$pb.TagNumber(10)
  $pb.PbList<$core.String> get addresses => $_getList(9);

  /// The address from which this peer was observed or learned about.
  @$pb.TagNumber(11)
  $core.String get observedAddr => $_getSZ(10);
  @$pb.TagNumber(11)
  set observedAddr($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasObservedAddr() => $_has(10);
  @$pb.TagNumber(11)
  void clearObservedAddr() => $_clearField(11);
}

const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
