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

class Message_Wantlist_WantType extends $pb.ProtobufEnum {
  static const Message_Wantlist_WantType Block = Message_Wantlist_WantType._(0, _omitEnumNames ? '' : 'Block');
  static const Message_Wantlist_WantType Have = Message_Wantlist_WantType._(1, _omitEnumNames ? '' : 'Have');

  static const $core.List<Message_Wantlist_WantType> values = <Message_Wantlist_WantType> [
    Block,
    Have,
  ];

  static final $core.Map<$core.int, Message_Wantlist_WantType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static Message_Wantlist_WantType? valueOf($core.int value) => _byValue[value];

  const Message_Wantlist_WantType._($core.int v, $core.String n) : super(v, n);
}

class Message_BlockPresence_Type extends $pb.ProtobufEnum {
  static const Message_BlockPresence_Type Have = Message_BlockPresence_Type._(0, _omitEnumNames ? '' : 'Have');
  static const Message_BlockPresence_Type DontHave = Message_BlockPresence_Type._(1, _omitEnumNames ? '' : 'DontHave');

  static const $core.List<Message_BlockPresence_Type> values = <Message_BlockPresence_Type> [
    Have,
    DontHave,
  ];

  static final $core.Map<$core.int, Message_BlockPresence_Type> _byValue = $pb.ProtobufEnum.initByValue(values);
  static Message_BlockPresence_Type? valueOf($core.int value) => _byValue[value];

  const Message_BlockPresence_Type._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
