//
//  Generated code. Do not modify.
//  source: base_messages.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class IPFSMessage_MessageType extends $pb.ProtobufEnum {
  static const IPFSMessage_MessageType UNKNOWN =
      IPFSMessage_MessageType._(0, _omitEnumNames ? '' : 'UNKNOWN');
  static const IPFSMessage_MessageType DHT =
      IPFSMessage_MessageType._(1, _omitEnumNames ? '' : 'DHT');
  static const IPFSMessage_MessageType BITSWAP =
      IPFSMessage_MessageType._(2, _omitEnumNames ? '' : 'BITSWAP');
  static const IPFSMessage_MessageType PUBSUB =
      IPFSMessage_MessageType._(3, _omitEnumNames ? '' : 'PUBSUB');
  static const IPFSMessage_MessageType IDENTIFY =
      IPFSMessage_MessageType._(4, _omitEnumNames ? '' : 'IDENTIFY');
  static const IPFSMessage_MessageType PING =
      IPFSMessage_MessageType._(5, _omitEnumNames ? '' : 'PING');

  static const $core.List<IPFSMessage_MessageType> values =
      <IPFSMessage_MessageType>[
    UNKNOWN,
    DHT,
    BITSWAP,
    PUBSUB,
    IDENTIFY,
    PING,
  ];

  static final $core.Map<$core.int, IPFSMessage_MessageType> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static IPFSMessage_MessageType? valueOf($core.int value) => _byValue[value];

  const IPFSMessage_MessageType._($core.int v, $core.String n) : super(v, n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
