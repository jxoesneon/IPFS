// This is a generated file - do not edit.
//
// Generated from connection.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ConnectionState_Status extends $pb.ProtobufEnum {
  static const ConnectionState_Status UNKNOWN =
      ConnectionState_Status._(0, _omitEnumNames ? '' : 'UNKNOWN');
  static const ConnectionState_Status CONNECTING =
      ConnectionState_Status._(1, _omitEnumNames ? '' : 'CONNECTING');
  static const ConnectionState_Status CONNECTED =
      ConnectionState_Status._(2, _omitEnumNames ? '' : 'CONNECTED');
  static const ConnectionState_Status DISCONNECTING =
      ConnectionState_Status._(3, _omitEnumNames ? '' : 'DISCONNECTING');
  static const ConnectionState_Status DISCONNECTED =
      ConnectionState_Status._(4, _omitEnumNames ? '' : 'DISCONNECTED');
  static const ConnectionState_Status ERROR =
      ConnectionState_Status._(5, _omitEnumNames ? '' : 'ERROR');

  static const $core.List<ConnectionState_Status> values =
      <ConnectionState_Status>[
    UNKNOWN,
    CONNECTING,
    CONNECTED,
    DISCONNECTING,
    DISCONNECTED,
    ERROR,
  ];

  static final $core.List<ConnectionState_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ConnectionState_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ConnectionState_Status._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
