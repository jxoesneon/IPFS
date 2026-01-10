//
//  Generated code. Do not modify.
//  source: connection.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

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

  static final $core.Map<$core.int, ConnectionState_Status> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static ConnectionState_Status? valueOf($core.int value) => _byValue[value];

  const ConnectionState_Status._($core.int v, $core.String n) : super(v, n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
