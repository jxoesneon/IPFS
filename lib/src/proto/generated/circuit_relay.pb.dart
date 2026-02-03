// This is a generated file - do not edit.
//
// Generated from circuit_relay.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'circuit_relay.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'circuit_relay.pbenum.dart';

class HopMessage extends $pb.GeneratedMessage {
  factory HopMessage({
    HopMessage_Type? type,
    Peer? peer,
    Reservation? reservation,
    Limit? limit,
    Status? status,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (peer != null) result.peer = peer;
    if (reservation != null) result.reservation = reservation;
    if (limit != null) result.limit = limit;
    if (status != null) result.status = status;
    return result;
  }

  HopMessage._();

  factory HopMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HopMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HopMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'circuit_relay'),
      createEmptyInstance: create)
    ..aE<HopMessage_Type>(1, _omitFieldNames ? '' : 'type',
        enumValues: HopMessage_Type.values)
    ..aOM<Peer>(2, _omitFieldNames ? '' : 'peer', subBuilder: Peer.create)
    ..aOM<Reservation>(3, _omitFieldNames ? '' : 'reservation',
        subBuilder: Reservation.create)
    ..aOM<Limit>(4, _omitFieldNames ? '' : 'limit', subBuilder: Limit.create)
    ..aE<Status>(5, _omitFieldNames ? '' : 'status', enumValues: Status.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HopMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HopMessage copyWith(void Function(HopMessage) updates) =>
      super.copyWith((message) => updates(message as HopMessage)) as HopMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HopMessage create() => HopMessage._();
  @$core.override
  HopMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HopMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HopMessage>(create);
  static HopMessage? _defaultInstance;

  @$pb.TagNumber(1)
  HopMessage_Type get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(HopMessage_Type value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  Peer get peer => $_getN(1);
  @$pb.TagNumber(2)
  set peer(Peer value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPeer() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeer() => $_clearField(2);
  @$pb.TagNumber(2)
  Peer ensurePeer() => $_ensure(1);

  @$pb.TagNumber(3)
  Reservation get reservation => $_getN(2);
  @$pb.TagNumber(3)
  set reservation(Reservation value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasReservation() => $_has(2);
  @$pb.TagNumber(3)
  void clearReservation() => $_clearField(3);
  @$pb.TagNumber(3)
  Reservation ensureReservation() => $_ensure(2);

  @$pb.TagNumber(4)
  Limit get limit => $_getN(3);
  @$pb.TagNumber(4)
  set limit(Limit value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasLimit() => $_has(3);
  @$pb.TagNumber(4)
  void clearLimit() => $_clearField(4);
  @$pb.TagNumber(4)
  Limit ensureLimit() => $_ensure(3);

  @$pb.TagNumber(5)
  Status get status => $_getN(4);
  @$pb.TagNumber(5)
  set status(Status value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatus() => $_clearField(5);
}

class StopMessage extends $pb.GeneratedMessage {
  factory StopMessage({
    StopMessage_Type? type,
    Peer? peer,
    Limit? limit,
    Status? status,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (peer != null) result.peer = peer;
    if (limit != null) result.limit = limit;
    if (status != null) result.status = status;
    return result;
  }

  StopMessage._();

  factory StopMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StopMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StopMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'circuit_relay'),
      createEmptyInstance: create)
    ..aE<StopMessage_Type>(1, _omitFieldNames ? '' : 'type',
        enumValues: StopMessage_Type.values)
    ..aOM<Peer>(2, _omitFieldNames ? '' : 'peer', subBuilder: Peer.create)
    ..aOM<Limit>(3, _omitFieldNames ? '' : 'limit', subBuilder: Limit.create)
    ..aE<Status>(4, _omitFieldNames ? '' : 'status', enumValues: Status.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopMessage copyWith(void Function(StopMessage) updates) =>
      super.copyWith((message) => updates(message as StopMessage))
          as StopMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StopMessage create() => StopMessage._();
  @$core.override
  StopMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StopMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StopMessage>(create);
  static StopMessage? _defaultInstance;

  @$pb.TagNumber(1)
  StopMessage_Type get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(StopMessage_Type value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  Peer get peer => $_getN(1);
  @$pb.TagNumber(2)
  set peer(Peer value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPeer() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeer() => $_clearField(2);
  @$pb.TagNumber(2)
  Peer ensurePeer() => $_ensure(1);

  @$pb.TagNumber(3)
  Limit get limit => $_getN(2);
  @$pb.TagNumber(3)
  set limit(Limit value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);
  @$pb.TagNumber(3)
  Limit ensureLimit() => $_ensure(2);

  @$pb.TagNumber(4)
  Status get status => $_getN(3);
  @$pb.TagNumber(4)
  set status(Status value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);
}

class Peer extends $pb.GeneratedMessage {
  factory Peer({
    $core.List<$core.int>? id,
    $core.Iterable<$core.List<$core.int>>? addrs,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (addrs != null) result.addrs.addAll(addrs);
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
      package: const $pb.PackageName(_omitMessageNames ? '' : 'circuit_relay'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OY)
    ..p<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'addrs', $pb.PbFieldType.PY)
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
}

class Reservation extends $pb.GeneratedMessage {
  factory Reservation({
    $fixnum.Int64? expire,
    $fixnum.Int64? limitDuration,
    $fixnum.Int64? limitData,
    $core.Iterable<$core.List<$core.int>>? addrs,
  }) {
    final result = create();
    if (expire != null) result.expire = expire;
    if (limitDuration != null) result.limitDuration = limitDuration;
    if (limitData != null) result.limitData = limitData;
    if (addrs != null) result.addrs.addAll(addrs);
    return result;
  }

  Reservation._();

  factory Reservation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Reservation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Reservation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'circuit_relay'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'expire', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'limitDuration', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'limitData', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..p<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'addrs', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Reservation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Reservation copyWith(void Function(Reservation) updates) =>
      super.copyWith((message) => updates(message as Reservation))
          as Reservation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Reservation create() => Reservation._();
  @$core.override
  Reservation createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Reservation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Reservation>(create);
  static Reservation? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get expire => $_getI64(0);
  @$pb.TagNumber(1)
  set expire($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExpire() => $_has(0);
  @$pb.TagNumber(1)
  void clearExpire() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get limitDuration => $_getI64(1);
  @$pb.TagNumber(2)
  set limitDuration($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimitDuration() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimitDuration() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get limitData => $_getI64(2);
  @$pb.TagNumber(3)
  set limitData($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimitData() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimitData() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.List<$core.int>> get addrs => $_getList(3);
}

class Limit extends $pb.GeneratedMessage {
  factory Limit({
    $fixnum.Int64? duration,
    $fixnum.Int64? data,
  }) {
    final result = create();
    if (duration != null) result.duration = duration;
    if (data != null) result.data = data;
    return result;
  }

  Limit._();

  factory Limit.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Limit.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Limit',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'circuit_relay'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'duration', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Limit clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Limit copyWith(void Function(Limit) updates) =>
      super.copyWith((message) => updates(message as Limit)) as Limit;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Limit create() => Limit._();
  @$core.override
  Limit createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Limit getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Limit>(create);
  static Limit? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get duration => $_getI64(0);
  @$pb.TagNumber(1)
  set duration($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDuration() => $_has(0);
  @$pb.TagNumber(1)
  void clearDuration() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get data => $_getI64(1);
  @$pb.TagNumber(2)
  set data($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

