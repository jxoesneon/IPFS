//
//  Generated code. Do not modify.
//  source: dht/kademlia.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ConnectionType extends $pb.ProtobufEnum {
  static const ConnectionType NOT_CONNECTED =
      ConnectionType._(0, _omitEnumNames ? '' : 'NOT_CONNECTED');
  static const ConnectionType CONNECTED =
      ConnectionType._(1, _omitEnumNames ? '' : 'CONNECTED');
  static const ConnectionType CAN_CONNECT =
      ConnectionType._(2, _omitEnumNames ? '' : 'CAN_CONNECT');
  static const ConnectionType CANNOT_CONNECT =
      ConnectionType._(3, _omitEnumNames ? '' : 'CANNOT_CONNECT');

  static const $core.List<ConnectionType> values = <ConnectionType>[
    NOT_CONNECTED,
    CONNECTED,
    CAN_CONNECT,
    CANNOT_CONNECT,
  ];

  static final $core.Map<$core.int, ConnectionType> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static ConnectionType? valueOf($core.int value) => _byValue[value];

  const ConnectionType._($core.int v, $core.String n) : super(v, n);
}

class Message_MessageType extends $pb.ProtobufEnum {
  static const Message_MessageType PUT_VALUE =
      Message_MessageType._(0, _omitEnumNames ? '' : 'PUT_VALUE');
  static const Message_MessageType GET_VALUE =
      Message_MessageType._(1, _omitEnumNames ? '' : 'GET_VALUE');
  static const Message_MessageType ADD_PROVIDER =
      Message_MessageType._(2, _omitEnumNames ? '' : 'ADD_PROVIDER');
  static const Message_MessageType GET_PROVIDERS =
      Message_MessageType._(3, _omitEnumNames ? '' : 'GET_PROVIDERS');
  static const Message_MessageType FIND_NODE =
      Message_MessageType._(4, _omitEnumNames ? '' : 'FIND_NODE');
  static const Message_MessageType PING =
      Message_MessageType._(5, _omitEnumNames ? '' : 'PING');

  static const $core.List<Message_MessageType> values = <Message_MessageType>[
    PUT_VALUE,
    GET_VALUE,
    ADD_PROVIDER,
    GET_PROVIDERS,
    FIND_NODE,
    PING,
  ];

  static final $core.Map<$core.int, Message_MessageType> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static Message_MessageType? valueOf($core.int value) => _byValue[value];

  const Message_MessageType._($core.int v, $core.String n) : super(v, n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
