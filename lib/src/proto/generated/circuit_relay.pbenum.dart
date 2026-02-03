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

import 'package:protobuf/protobuf.dart' as $pb;

class Status extends $pb.ProtobufEnum {
  static const Status OK = Status._(0, _omitEnumNames ? '' : 'OK');
  static const Status FAILED = Status._(1, _omitEnumNames ? '' : 'FAILED');
  static const Status HOP_SRC_ADDR_TOO_LONG =
      Status._(220, _omitEnumNames ? '' : 'HOP_SRC_ADDR_TOO_LONG');
  static const Status HOP_DST_ADDR_TOO_LONG =
      Status._(221, _omitEnumNames ? '' : 'HOP_DST_ADDR_TOO_LONG');
  static const Status HOP_SRC_MULTIADDR_INVALID =
      Status._(222, _omitEnumNames ? '' : 'HOP_SRC_MULTIADDR_INVALID');
  static const Status HOP_DST_MULTIADDR_INVALID =
      Status._(223, _omitEnumNames ? '' : 'HOP_DST_MULTIADDR_INVALID');
  static const Status HOP_NO_CONN_TO_DST =
      Status._(260, _omitEnumNames ? '' : 'HOP_NO_CONN_TO_DST');
  static const Status HOP_CANT_DIAL_DST =
      Status._(261, _omitEnumNames ? '' : 'HOP_CANT_DIAL_DST');
  static const Status HOP_CANT_OPEN_DST_STREAM =
      Status._(262, _omitEnumNames ? '' : 'HOP_CANT_OPEN_DST_STREAM');
  static const Status HOP_CANT_SPEAK_RELAY =
      Status._(270, _omitEnumNames ? '' : 'HOP_CANT_SPEAK_RELAY');
  static const Status HOP_CANT_RELAY_TO_SELF =
      Status._(280, _omitEnumNames ? '' : 'HOP_CANT_RELAY_TO_SELF');
  static const Status STOP_SRC_ADDR_TOO_LONG =
      Status._(320, _omitEnumNames ? '' : 'STOP_SRC_ADDR_TOO_LONG');
  static const Status STOP_DST_ADDR_TOO_LONG =
      Status._(321, _omitEnumNames ? '' : 'STOP_DST_ADDR_TOO_LONG');
  static const Status STOP_SRC_MULTIADDR_INVALID =
      Status._(322, _omitEnumNames ? '' : 'STOP_SRC_MULTIADDR_INVALID');
  static const Status STOP_DST_MULTIADDR_INVALID =
      Status._(323, _omitEnumNames ? '' : 'STOP_DST_MULTIADDR_INVALID');

  static const $core.List<Status> values = <Status>[
    OK,
    FAILED,
    HOP_SRC_ADDR_TOO_LONG,
    HOP_DST_ADDR_TOO_LONG,
    HOP_SRC_MULTIADDR_INVALID,
    HOP_DST_MULTIADDR_INVALID,
    HOP_NO_CONN_TO_DST,
    HOP_CANT_DIAL_DST,
    HOP_CANT_OPEN_DST_STREAM,
    HOP_CANT_SPEAK_RELAY,
    HOP_CANT_RELAY_TO_SELF,
    STOP_SRC_ADDR_TOO_LONG,
    STOP_DST_ADDR_TOO_LONG,
    STOP_SRC_MULTIADDR_INVALID,
    STOP_DST_MULTIADDR_INVALID,
  ];

  static final $core.Map<$core.int, Status> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static Status? valueOf($core.int value) => _byValue[value];

  const Status._(super.value, super.name);
}

class HopMessage_Type extends $pb.ProtobufEnum {
  static const HopMessage_Type RESERVE =
      HopMessage_Type._(0, _omitEnumNames ? '' : 'RESERVE');
  static const HopMessage_Type CONNECT =
      HopMessage_Type._(1, _omitEnumNames ? '' : 'CONNECT');
  static const HopMessage_Type STATUS =
      HopMessage_Type._(2, _omitEnumNames ? '' : 'STATUS');

  static const $core.List<HopMessage_Type> values = <HopMessage_Type>[
    RESERVE,
    CONNECT,
    STATUS,
  ];

  static final $core.List<HopMessage_Type?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static HopMessage_Type? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const HopMessage_Type._(super.value, super.name);
}

class StopMessage_Type extends $pb.ProtobufEnum {
  static const StopMessage_Type CONNECT =
      StopMessage_Type._(0, _omitEnumNames ? '' : 'CONNECT');
  static const StopMessage_Type STATUS =
      StopMessage_Type._(1, _omitEnumNames ? '' : 'STATUS');

  static const $core.List<StopMessage_Type> values = <StopMessage_Type>[
    CONNECT,
    STATUS,
  ];

  static final $core.List<StopMessage_Type?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static StopMessage_Type? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StopMessage_Type._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
