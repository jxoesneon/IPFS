// This is a generated file - do not edit.
//
// Generated from bitswap/bitswap.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Message_Wantlist_WantType extends $pb.ProtobufEnum {
  static const Message_Wantlist_WantType Block =
      Message_Wantlist_WantType._(0, _omitEnumNames ? '' : 'Block');
  static const Message_Wantlist_WantType Have =
      Message_Wantlist_WantType._(1, _omitEnumNames ? '' : 'Have');

  static const $core.List<Message_Wantlist_WantType> values =
      <Message_Wantlist_WantType>[
    Block,
    Have,
  ];

  static final $core.List<Message_Wantlist_WantType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static Message_Wantlist_WantType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Message_Wantlist_WantType._(super.value, super.name);
}

class Message_BlockPresence_Type extends $pb.ProtobufEnum {
  static const Message_BlockPresence_Type Have =
      Message_BlockPresence_Type._(0, _omitEnumNames ? '' : 'Have');
  static const Message_BlockPresence_Type DontHave =
      Message_BlockPresence_Type._(1, _omitEnumNames ? '' : 'DontHave');

  static const $core.List<Message_BlockPresence_Type> values =
      <Message_BlockPresence_Type>[
    Have,
    DontHave,
  ];

  static final $core.List<Message_BlockPresence_Type?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static Message_BlockPresence_Type? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Message_BlockPresence_Type._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
