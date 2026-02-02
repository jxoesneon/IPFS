// This is a generated file - do not edit.
//
// Generated from dht/kademlia.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'dht.pb.dart' as $0;
import 'kademlia.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'kademlia.pbenum.dart';

class Message extends $pb.GeneratedMessage {
  factory Message({
    Message_MessageType? type,
    $core.List<$core.int>? key,
    $0.Record? record,
    $core.Iterable<Peer>? closerPeers,
    $core.Iterable<Peer>? providerPeers,
    $core.int? clusterLevelRaw,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (key != null) result.key = key;
    if (record != null) result.record = record;
    if (closerPeers != null) result.closerPeers.addAll(closerPeers);
    if (providerPeers != null) result.providerPeers.addAll(providerPeers);
    if (clusterLevelRaw != null) result.clusterLevelRaw = clusterLevelRaw;
    return result;
  }

  Message._();

  factory Message.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Message.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Message',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..aE<Message_MessageType>(1, _omitFieldNames ? '' : 'type',
        enumValues: Message_MessageType.values)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'key', $pb.PbFieldType.OY)
    ..aOM<$0.Record>(3, _omitFieldNames ? '' : 'record',
        subBuilder: $0.Record.create)
    ..pPM<Peer>(8, _omitFieldNames ? '' : 'closerPeers',
        protoName: 'closerPeers', subBuilder: Peer.create)
    ..pPM<Peer>(9, _omitFieldNames ? '' : 'providerPeers',
        protoName: 'providerPeers', subBuilder: Peer.create)
    ..aI(10, _omitFieldNames ? '' : 'clusterLevelRaw',
        protoName: 'clusterLevelRaw')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Message clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Message copyWith(void Function(Message) updates) =>
      super.copyWith((message) => updates(message as Message)) as Message;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Message create() => Message._();
  @$core.override
  Message createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Message getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Message>(create);
  static Message? _defaultInstance;

  @$pb.TagNumber(1)
  Message_MessageType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(Message_MessageType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get key => $_getN(1);
  @$pb.TagNumber(2)
  set key($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.Record get record => $_getN(2);
  @$pb.TagNumber(3)
  set record($0.Record value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRecord() => $_has(2);
  @$pb.TagNumber(3)
  void clearRecord() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.Record ensureRecord() => $_ensure(2);

  @$pb.TagNumber(8)
  $pb.PbList<Peer> get closerPeers => $_getList(3);

  @$pb.TagNumber(9)
  $pb.PbList<Peer> get providerPeers => $_getList(4);

  @$pb.TagNumber(10)
  $core.int get clusterLevelRaw => $_getIZ(5);
  @$pb.TagNumber(10)
  set clusterLevelRaw($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(10)
  $core.bool hasClusterLevelRaw() => $_has(5);
  @$pb.TagNumber(10)
  void clearClusterLevelRaw() => $_clearField(10);
}

class Peer extends $pb.GeneratedMessage {
  factory Peer({
    $core.List<$core.int>? id,
    $core.Iterable<$core.List<$core.int>>? addrs,
    ConnectionType? connection,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (addrs != null) result.addrs.addAll(addrs);
    if (connection != null) result.connection = connection;
    return result;
  }

  Peer._();

  factory Peer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Peer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Peer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OY)
    ..p<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'addrs', $pb.PbFieldType.PY)
    ..aE<ConnectionType>(3, _omitFieldNames ? '' : 'connection',
        enumValues: ConnectionType.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Peer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Peer copyWith(void Function(Peer) updates) =>
      super.copyWith((message) => updates(message as Peer)) as Peer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Peer create() => Peer._();
  @$core.override
  Peer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Peer getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Peer>(create);
  static Peer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get id => $_getN(0);
  @$pb.TagNumber(1)
  set id($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get addrs => $_getList(1);

  @$pb.TagNumber(3)
  ConnectionType get connection => $_getN(2);
  @$pb.TagNumber(3)
  set connection(ConnectionType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasConnection() => $_has(2);
  @$pb.TagNumber(3)
  void clearConnection() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
