//
//  Generated code. Do not modify.
//  source: dht_messages.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class DHTMessage_MessageType extends $pb.ProtobufEnum {
  static const DHTMessage_MessageType UNKNOWN = DHTMessage_MessageType._(0, _omitEnumNames ? '' : 'UNKNOWN');
  static const DHTMessage_MessageType FIND_NODE = DHTMessage_MessageType._(1, _omitEnumNames ? '' : 'FIND_NODE');
  static const DHTMessage_MessageType FIND_VALUE = DHTMessage_MessageType._(2, _omitEnumNames ? '' : 'FIND_VALUE');
  static const DHTMessage_MessageType PUT_VALUE = DHTMessage_MessageType._(3, _omitEnumNames ? '' : 'PUT_VALUE');
  static const DHTMessage_MessageType GET_VALUE = DHTMessage_MessageType._(4, _omitEnumNames ? '' : 'GET_VALUE');
  static const DHTMessage_MessageType ADD_PROVIDER = DHTMessage_MessageType._(5, _omitEnumNames ? '' : 'ADD_PROVIDER');
  static const DHTMessage_MessageType GET_PROVIDERS = DHTMessage_MessageType._(6, _omitEnumNames ? '' : 'GET_PROVIDERS');
  static const DHTMessage_MessageType PING = DHTMessage_MessageType._(7, _omitEnumNames ? '' : 'PING');

  static const $core.List<DHTMessage_MessageType> values = <DHTMessage_MessageType> [
    UNKNOWN,
    FIND_NODE,
    FIND_VALUE,
    PUT_VALUE,
    GET_VALUE,
    ADD_PROVIDER,
    GET_PROVIDERS,
    PING,
  ];

  static final $core.Map<$core.int, DHTMessage_MessageType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static DHTMessage_MessageType? valueOf($core.int value) => _byValue[value];

  const DHTMessage_MessageType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
