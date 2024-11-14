//
//  Generated code. Do not modify.
//  source: bitswap/bitswap.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Enum for message types
class MessageType extends $pb.ProtobufEnum {
  static const MessageType MESSAGE_TYPE_UNKNOWN = MessageType._(0, _omitEnumNames ? '' : 'MESSAGE_TYPE_UNKNOWN');
  static const MessageType MESSAGE_TYPE_WANT_BLOCK = MessageType._(1, _omitEnumNames ? '' : 'MESSAGE_TYPE_WANT_BLOCK');
  static const MessageType MESSAGE_TYPE_WANT_HAVE = MessageType._(2, _omitEnumNames ? '' : 'MESSAGE_TYPE_WANT_HAVE');
  static const MessageType MESSAGE_TYPE_BLOCK = MessageType._(3, _omitEnumNames ? '' : 'MESSAGE_TYPE_BLOCK');
  static const MessageType MESSAGE_TYPE_HAVE = MessageType._(4, _omitEnumNames ? '' : 'MESSAGE_TYPE_HAVE');
  static const MessageType MESSAGE_TYPE_DONT_HAVE = MessageType._(5, _omitEnumNames ? '' : 'MESSAGE_TYPE_DONT_HAVE');

  static const $core.List<MessageType> values = <MessageType> [
    MESSAGE_TYPE_UNKNOWN,
    MESSAGE_TYPE_WANT_BLOCK,
    MESSAGE_TYPE_WANT_HAVE,
    MESSAGE_TYPE_BLOCK,
    MESSAGE_TYPE_HAVE,
    MESSAGE_TYPE_DONT_HAVE,
  ];

  static final $core.Map<$core.int, MessageType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static MessageType? valueOf($core.int value) => _byValue[value];

  const MessageType._($core.int v, $core.String n) : super(v, n);
}

class BlockPresence_Type extends $pb.ProtobufEnum {
  static const BlockPresence_Type HAVE = BlockPresence_Type._(0, _omitEnumNames ? '' : 'HAVE');
  static const BlockPresence_Type DONT_HAVE = BlockPresence_Type._(1, _omitEnumNames ? '' : 'DONT_HAVE');

  static const $core.List<BlockPresence_Type> values = <BlockPresence_Type> [
    HAVE,
    DONT_HAVE,
  ];

  static final $core.Map<$core.int, BlockPresence_Type> _byValue = $pb.ProtobufEnum.initByValue(values);
  static BlockPresence_Type? valueOf($core.int value) => _byValue[value];

  const BlockPresence_Type._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
