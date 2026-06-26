// This is a generated file - do not edit.
//
// Generated from gossipsub.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// RPC envelope exchanged between Gossipsub peers.
class RPC extends $pb.GeneratedMessage {
  factory RPC({
    $core.Iterable<Subscription>? subscriptions,
    $core.Iterable<Message>? publish,
    ControlMessage? control,
  }) {
    final result = create();
    if (subscriptions != null) result.subscriptions.addAll(subscriptions);
    if (publish != null) result.publish.addAll(publish);
    if (control != null) result.control = control;
    return result;
  }

  RPC._();

  factory RPC.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RPC.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RPC',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'gossipsub'),
      createEmptyInstance: create)
    ..pPM<Subscription>(1, _omitFieldNames ? '' : 'subscriptions',
        subBuilder: Subscription.create)
    ..pPM<Message>(2, _omitFieldNames ? '' : 'publish',
        subBuilder: Message.create)
    ..aOM<ControlMessage>(3, _omitFieldNames ? '' : 'control',
        subBuilder: ControlMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RPC clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RPC copyWith(void Function(RPC) updates) =>
      super.copyWith((message) => updates(message as RPC)) as RPC;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RPC create() => RPC._();
  @$core.override
  RPC createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RPC getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RPC>(create);
  static RPC? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Subscription> get subscriptions => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<Message> get publish => $_getList(1);

  @$pb.TagNumber(3)
  ControlMessage get control => $_getN(2);
  @$pb.TagNumber(3)
  set control(ControlMessage value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasControl() => $_has(2);
  @$pb.TagNumber(3)
  void clearControl() => $_clearField(3);
  @$pb.TagNumber(3)
  ControlMessage ensureControl() => $_ensure(2);
}

/// Subscription announcement.
class Subscription extends $pb.GeneratedMessage {
  factory Subscription({
    $core.bool? subscribe,
    $core.String? topicid,
  }) {
    final result = create();
    if (subscribe != null) result.subscribe = subscribe;
    if (topicid != null) result.topicid = topicid;
    return result;
  }

  Subscription._();

  factory Subscription.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Subscription.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Subscription',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'gossipsub'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'subscribe')
    ..aOS(2, _omitFieldNames ? '' : 'topicid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subscription clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subscription copyWith(void Function(Subscription) updates) =>
      super.copyWith((message) => updates(message as Subscription))
          as Subscription;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Subscription create() => Subscription._();
  @$core.override
  Subscription createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Subscription getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Subscription>(create);
  static Subscription? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get subscribe => $_getBF(0);
  @$pb.TagNumber(1)
  set subscribe($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSubscribe() => $_has(0);
  @$pb.TagNumber(1)
  void clearSubscribe() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get topicid => $_getSZ(1);
  @$pb.TagNumber(2)
  set topicid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTopicid() => $_has(1);
  @$pb.TagNumber(2)
  void clearTopicid() => $_clearField(2);
}

/// PubSub message.
class Message extends $pb.GeneratedMessage {
  factory Message({
    $core.List<$core.int>? from,
    $core.List<$core.int>? data,
    $core.List<$core.int>? seqno,
    $core.String? topic,
    $core.List<$core.int>? signature,
    $core.List<$core.int>? key,
  }) {
    final result = create();
    if (from != null) result.from = from;
    if (data != null) result.data = data;
    if (seqno != null) result.seqno = seqno;
    if (topic != null) result.topic = topic;
    if (signature != null) result.signature = signature;
    if (key != null) result.key = key;
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
      package: const $pb.PackageName(_omitMessageNames ? '' : 'gossipsub'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'from', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'seqno', $pb.PbFieldType.OY)
    ..aOS(4, _omitFieldNames ? '' : 'topic')
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'key', $pb.PbFieldType.OY)
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
  $core.List<$core.int> get from => $_getN(0);
  @$pb.TagNumber(1)
  set from($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFrom() => $_has(0);
  @$pb.TagNumber(1)
  void clearFrom() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get seqno => $_getN(2);
  @$pb.TagNumber(3)
  set seqno($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSeqno() => $_has(2);
  @$pb.TagNumber(3)
  void clearSeqno() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get topic => $_getSZ(3);
  @$pb.TagNumber(4)
  set topic($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTopic() => $_has(3);
  @$pb.TagNumber(4)
  void clearTopic() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get signature => $_getN(4);
  @$pb.TagNumber(5)
  set signature($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSignature() => $_has(4);
  @$pb.TagNumber(5)
  void clearSignature() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get key => $_getN(5);
  @$pb.TagNumber(6)
  set key($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearKey() => $_clearField(6);
}

/// Control message container.
class ControlMessage extends $pb.GeneratedMessage {
  factory ControlMessage({
    $core.Iterable<ControlIHave>? ihave,
    $core.Iterable<ControlIWant>? iwant,
    $core.Iterable<ControlGraft>? graft,
    $core.Iterable<ControlPrune>? prune,
  }) {
    final result = create();
    if (ihave != null) result.ihave.addAll(ihave);
    if (iwant != null) result.iwant.addAll(iwant);
    if (graft != null) result.graft.addAll(graft);
    if (prune != null) result.prune.addAll(prune);
    return result;
  }

  ControlMessage._();

  factory ControlMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ControlMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ControlMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'gossipsub'),
      createEmptyInstance: create)
    ..pPM<ControlIHave>(1, _omitFieldNames ? '' : 'ihave',
        subBuilder: ControlIHave.create)
    ..pPM<ControlIWant>(2, _omitFieldNames ? '' : 'iwant',
        subBuilder: ControlIWant.create)
    ..pPM<ControlGraft>(3, _omitFieldNames ? '' : 'graft',
        subBuilder: ControlGraft.create)
    ..pPM<ControlPrune>(4, _omitFieldNames ? '' : 'prune',
        subBuilder: ControlPrune.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlMessage copyWith(void Function(ControlMessage) updates) =>
      super.copyWith((message) => updates(message as ControlMessage))
          as ControlMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ControlMessage create() => ControlMessage._();
  @$core.override
  ControlMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ControlMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ControlMessage>(create);
  static ControlMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ControlIHave> get ihave => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<ControlIWant> get iwant => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<ControlGraft> get graft => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<ControlPrune> get prune => $_getList(3);
}

/// IHAVE control message.
class ControlIHave extends $pb.GeneratedMessage {
  factory ControlIHave({
    $core.String? topicID,
    $core.Iterable<$core.String>? messageIDs,
  }) {
    final result = create();
    if (topicID != null) result.topicID = topicID;
    if (messageIDs != null) result.messageIDs.addAll(messageIDs);
    return result;
  }

  ControlIHave._();

  factory ControlIHave.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ControlIHave.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ControlIHave',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'gossipsub'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicID', protoName: 'topicID')
    ..pPS(2, _omitFieldNames ? '' : 'messageIDs', protoName: 'messageIDs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlIHave clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlIHave copyWith(void Function(ControlIHave) updates) =>
      super.copyWith((message) => updates(message as ControlIHave))
          as ControlIHave;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ControlIHave create() => ControlIHave._();
  @$core.override
  ControlIHave createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ControlIHave getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ControlIHave>(create);
  static ControlIHave? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicID => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicID($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicID() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicID() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get messageIDs => $_getList(1);
}

/// IWANT control message.
class ControlIWant extends $pb.GeneratedMessage {
  factory ControlIWant({
    $core.Iterable<$core.String>? messageIDs,
  }) {
    final result = create();
    if (messageIDs != null) result.messageIDs.addAll(messageIDs);
    return result;
  }

  ControlIWant._();

  factory ControlIWant.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ControlIWant.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ControlIWant',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'gossipsub'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'messageIDs', protoName: 'messageIDs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlIWant clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlIWant copyWith(void Function(ControlIWant) updates) =>
      super.copyWith((message) => updates(message as ControlIWant))
          as ControlIWant;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ControlIWant create() => ControlIWant._();
  @$core.override
  ControlIWant createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ControlIWant getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ControlIWant>(create);
  static ControlIWant? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get messageIDs => $_getList(0);
}

/// GRAFT control message.
class ControlGraft extends $pb.GeneratedMessage {
  factory ControlGraft({
    $core.String? topicID,
  }) {
    final result = create();
    if (topicID != null) result.topicID = topicID;
    return result;
  }

  ControlGraft._();

  factory ControlGraft.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ControlGraft.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ControlGraft',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'gossipsub'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicID', protoName: 'topicID')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlGraft clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlGraft copyWith(void Function(ControlGraft) updates) =>
      super.copyWith((message) => updates(message as ControlGraft))
          as ControlGraft;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ControlGraft create() => ControlGraft._();
  @$core.override
  ControlGraft createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ControlGraft getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ControlGraft>(create);
  static ControlGraft? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicID => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicID($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicID() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicID() => $_clearField(1);
}

/// PRUNE control message.
class ControlPrune extends $pb.GeneratedMessage {
  factory ControlPrune({
    $core.String? topicID,
    $core.Iterable<PeerInfo>? peers,
    $fixnum.Int64? backoff,
  }) {
    final result = create();
    if (topicID != null) result.topicID = topicID;
    if (peers != null) result.peers.addAll(peers);
    if (backoff != null) result.backoff = backoff;
    return result;
  }

  ControlPrune._();

  factory ControlPrune.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ControlPrune.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ControlPrune',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'gossipsub'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicID', protoName: 'topicID')
    ..pPM<PeerInfo>(2, _omitFieldNames ? '' : 'peers',
        subBuilder: PeerInfo.create)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'backoff', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlPrune clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlPrune copyWith(void Function(ControlPrune) updates) =>
      super.copyWith((message) => updates(message as ControlPrune))
          as ControlPrune;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ControlPrune create() => ControlPrune._();
  @$core.override
  ControlPrune createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ControlPrune getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ControlPrune>(create);
  static ControlPrune? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicID => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicID($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicID() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicID() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<PeerInfo> get peers => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get backoff => $_getI64(2);
  @$pb.TagNumber(3)
  set backoff($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBackoff() => $_has(2);
  @$pb.TagNumber(3)
  void clearBackoff() => $_clearField(3);
}

/// Peer info used in PRUNE peer exchange.
class PeerInfo extends $pb.GeneratedMessage {
  factory PeerInfo({
    $core.List<$core.int>? peerID,
    $core.List<$core.int>? signedPeerRecord,
  }) {
    final result = create();
    if (peerID != null) result.peerID = peerID;
    if (signedPeerRecord != null) result.signedPeerRecord = signedPeerRecord;
    return result;
  }

  PeerInfo._();

  factory PeerInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PeerInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'gossipsub'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'peerID', $pb.PbFieldType.OY,
        protoName: 'peerID')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signedPeerRecord', $pb.PbFieldType.OY,
        protoName: 'signedPeerRecord')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerInfo copyWith(void Function(PeerInfo) updates) =>
      super.copyWith((message) => updates(message as PeerInfo)) as PeerInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerInfo create() => PeerInfo._();
  @$core.override
  PeerInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PeerInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PeerInfo>(create);
  static PeerInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get peerID => $_getN(0);
  @$pb.TagNumber(1)
  set peerID($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerID() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerID() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signedPeerRecord => $_getN(1);
  @$pb.TagNumber(2)
  set signedPeerRecord($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignedPeerRecord() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignedPeerRecord() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
