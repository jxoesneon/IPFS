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

import '../google/protobuf/timestamp.pb.dart' as $1;
import 'common_red_black_tree.pbenum.dart';

export 'common_red_black_tree.pbenum.dart';

/// Defines a message representing a peer's unique identifier.
class RBTreePeerId extends $pb.GeneratedMessage {
  factory RBTreePeerId({
    $core.String? id,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    return $result;
  }
  RBTreePeerId._() : super();
  factory RBTreePeerId.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RBTreePeerId.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RBTreePeerId', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.common_red_black_tree'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RBTreePeerId clone() => RBTreePeerId()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RBTreePeerId copyWith(void Function(RBTreePeerId) updates) => super.copyWith((message) => updates(message as RBTreePeerId)) as RBTreePeerId;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RBTreePeerId create() => RBTreePeerId._();
  RBTreePeerId createEmptyInstance() => create();
  static $pb.PbList<RBTreePeerId> createRepeated() => $pb.PbList<RBTreePeerId>();
  @$core.pragma('dart2js:noInline')
  static RBTreePeerId getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RBTreePeerId>(create);
  static RBTreePeerId? _defaultInstance;

  /// The ID of the peer, represented as a string.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);
}

/// Defines a message representing a node in a data structure.
class Node extends $pb.GeneratedMessage {
  factory Node({
    RBTreePeerId? peerId,
    $core.List<$core.int>? data,
  }) {
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (data != null) {
      $result.data = data;
    }
    return $result;
  }
  Node._() : super();
  factory Node.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Node.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Node', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.common_red_black_tree'), createEmptyInstance: create)
    ..aOM<RBTreePeerId>(1, _omitFieldNames ? '' : 'peerId', subBuilder: RBTreePeerId.create)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Node clone() => Node()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Node copyWith(void Function(Node) updates) => super.copyWith((message) => updates(message as Node)) as Node;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Node create() => Node._();
  Node createEmptyInstance() => create();
  static $pb.PbList<Node> createRepeated() => $pb.PbList<Node>();
  @$core.pragma('dart2js:noInline')
  static Node getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Node>(create);
  static Node? _defaultInstance;

  /// The unique identifier of the peer associated with this node.
  @$pb.TagNumber(1)
  RBTreePeerId get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId(RBTreePeerId v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);
  @$pb.TagNumber(1)
  RBTreePeerId ensurePeerId() => $_ensure(0);

  /// Arbitrary data associated with this node, represented as bytes.
  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => clearField(2);
}

/// Defines a message representing a PeerId specifically for keys.
class K_PeerId extends $pb.GeneratedMessage {
  factory K_PeerId({
    $core.List<$core.int>? id,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    return $result;
  }
  K_PeerId._() : super();
  factory K_PeerId.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory K_PeerId.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'K_PeerId', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.common_red_black_tree'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  K_PeerId clone() => K_PeerId()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  K_PeerId copyWith(void Function(K_PeerId) updates) => super.copyWith((message) => updates(message as K_PeerId)) as K_PeerId;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static K_PeerId create() => K_PeerId._();
  K_PeerId createEmptyInstance() => create();
  static $pb.PbList<K_PeerId> createRepeated() => $pb.PbList<K_PeerId>();
  @$core.pragma('dart2js:noInline')
  static K_PeerId getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<K_PeerId>(create);
  static K_PeerId? _defaultInstance;

  /// The ID of the peer, represented as bytes.
  @$pb.TagNumber(1)
  $core.List<$core.int> get id => $_getN(0);
  @$pb.TagNumber(1)
  set id($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);
}

class V_PeerInfo extends $pb.GeneratedMessage {
  factory V_PeerInfo({
    $core.List<$core.int>? peerId,
    $core.String? ipAddress,
    $core.int? port,
    $core.Iterable<$core.String>? protocols,
    $core.int? latency,
    V_PeerInfo_ConnectionStatus? connectionStatus,
    $1.Timestamp? lastSeen,
    $core.String? agentVersion,
    $core.List<$core.int>? publicKey,
    $core.Iterable<$core.String>? addresses,
    $core.String? observedAddr,
  }) {
    final $result = create();
    if (peerId != null) {
      $result.peerId = peerId;
    }
    if (ipAddress != null) {
      $result.ipAddress = ipAddress;
    }
    if (port != null) {
      $result.port = port;
    }
    if (protocols != null) {
      $result.protocols.addAll(protocols);
    }
    if (latency != null) {
      $result.latency = latency;
    }
    if (connectionStatus != null) {
      $result.connectionStatus = connectionStatus;
    }
    if (lastSeen != null) {
      $result.lastSeen = lastSeen;
    }
    if (agentVersion != null) {
      $result.agentVersion = agentVersion;
    }
    if (publicKey != null) {
      $result.publicKey = publicKey;
    }
    if (addresses != null) {
      $result.addresses.addAll(addresses);
    }
    if (observedAddr != null) {
      $result.observedAddr = observedAddr;
    }
    return $result;
  }
  V_PeerInfo._() : super();
  factory V_PeerInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory V_PeerInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'V_PeerInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.common_red_black_tree'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'peerId', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'ipAddress')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'port', $pb.PbFieldType.O3)
    ..pPS(4, _omitFieldNames ? '' : 'protocols')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'latency', $pb.PbFieldType.O3)
    ..e<V_PeerInfo_ConnectionStatus>(6, _omitFieldNames ? '' : 'connectionStatus', $pb.PbFieldType.OE, defaultOrMaker: V_PeerInfo_ConnectionStatus.DISCONNECTED, valueOf: V_PeerInfo_ConnectionStatus.valueOf, enumValues: V_PeerInfo_ConnectionStatus.values)
    ..aOM<$1.Timestamp>(7, _omitFieldNames ? '' : 'lastSeen', subBuilder: $1.Timestamp.create)
    ..aOS(8, _omitFieldNames ? '' : 'agentVersion')
    ..a<$core.List<$core.int>>(9, _omitFieldNames ? '' : 'publicKey', $pb.PbFieldType.OY)
    ..pPS(10, _omitFieldNames ? '' : 'addresses')
    ..aOS(11, _omitFieldNames ? '' : 'observedAddr')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  V_PeerInfo clone() => V_PeerInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  V_PeerInfo copyWith(void Function(V_PeerInfo) updates) => super.copyWith((message) => updates(message as V_PeerInfo)) as V_PeerInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static V_PeerInfo create() => V_PeerInfo._();
  V_PeerInfo createEmptyInstance() => create();
  static $pb.PbList<V_PeerInfo> createRepeated() => $pb.PbList<V_PeerInfo>();
  @$core.pragma('dart2js:noInline')
  static V_PeerInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<V_PeerInfo>(create);
  static V_PeerInfo? _defaultInstance;

  /// The unique identifier of the peer.
  @$pb.TagNumber(1)
  $core.List<$core.int> get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => clearField(1);

  /// The IP address of the peer.
  @$pb.TagNumber(2)
  $core.String get ipAddress => $_getSZ(1);
  @$pb.TagNumber(2)
  set ipAddress($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasIpAddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearIpAddress() => clearField(2);

  /// The port number on which the peer is listening for connections.
  @$pb.TagNumber(3)
  $core.int get port => $_getIZ(2);
  @$pb.TagNumber(3)
  set port($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPort() => $_has(2);
  @$pb.TagNumber(3)
  void clearPort() => clearField(3);

  /// A list of protocols supported by the peer.
  @$pb.TagNumber(4)
  $core.List<$core.String> get protocols => $_getList(3);

  /// The estimated latency to the peer, in milliseconds.
  @$pb.TagNumber(5)
  $core.int get latency => $_getIZ(4);
  @$pb.TagNumber(5)
  set latency($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasLatency() => $_has(4);
  @$pb.TagNumber(5)
  void clearLatency() => clearField(5);

  @$pb.TagNumber(6)
  V_PeerInfo_ConnectionStatus get connectionStatus => $_getN(5);
  @$pb.TagNumber(6)
  set connectionStatus(V_PeerInfo_ConnectionStatus v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasConnectionStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearConnectionStatus() => clearField(6);

  /// The timestamp when the peer was last seen or contacted.
  @$pb.TagNumber(7)
  $1.Timestamp get lastSeen => $_getN(6);
  @$pb.TagNumber(7)
  set lastSeen($1.Timestamp v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasLastSeen() => $_has(6);
  @$pb.TagNumber(7)
  void clearLastSeen() => clearField(7);
  @$pb.TagNumber(7)
  $1.Timestamp ensureLastSeen() => $_ensure(6);

  /// The version of the IPFS agent or client running on the peer.
  @$pb.TagNumber(8)
  $core.String get agentVersion => $_getSZ(7);
  @$pb.TagNumber(8)
  set agentVersion($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasAgentVersion() => $_has(7);
  @$pb.TagNumber(8)
  void clearAgentVersion() => clearField(8);

  /// The public key of the peer, used for authentication.
  @$pb.TagNumber(9)
  $core.List<$core.int> get publicKey => $_getN(8);
  @$pb.TagNumber(9)
  set publicKey($core.List<$core.int> v) { $_setBytes(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasPublicKey() => $_has(8);
  @$pb.TagNumber(9)
  void clearPublicKey() => clearField(9);

  /// A list of multiaddresses for the peer.
  @$pb.TagNumber(10)
  $core.List<$core.String> get addresses => $_getList(9);

  /// The address from which this peer was observed or learned about.
  @$pb.TagNumber(11)
  $core.String get observedAddr => $_getSZ(10);
  @$pb.TagNumber(11)
  set observedAddr($core.String v) { $_setString(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasObservedAddr() => $_has(10);
  @$pb.TagNumber(11)
  void clearObservedAddr() => clearField(11);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
