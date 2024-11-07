//
//  Generated code. Do not modify.
//  source: bitswap_messages.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class BitSwapMessage_MessageType extends $pb.ProtobufEnum {
  static const BitSwapMessage_MessageType UNKNOWN = BitSwapMessage_MessageType._(0, _omitEnumNames ? '' : 'UNKNOWN');
  static const BitSwapMessage_MessageType WANT_HAVE = BitSwapMessage_MessageType._(1, _omitEnumNames ? '' : 'WANT_HAVE');
  static const BitSwapMessage_MessageType WANT_BLOCK = BitSwapMessage_MessageType._(2, _omitEnumNames ? '' : 'WANT_BLOCK');
  static const BitSwapMessage_MessageType HAVE = BitSwapMessage_MessageType._(3, _omitEnumNames ? '' : 'HAVE');
  static const BitSwapMessage_MessageType DONT_HAVE = BitSwapMessage_MessageType._(4, _omitEnumNames ? '' : 'DONT_HAVE');
  static const BitSwapMessage_MessageType BLOCK = BitSwapMessage_MessageType._(5, _omitEnumNames ? '' : 'BLOCK');

  static const $core.List<BitSwapMessage_MessageType> values = <BitSwapMessage_MessageType> [
    UNKNOWN,
    WANT_HAVE,
    WANT_BLOCK,
    HAVE,
    DONT_HAVE,
    BLOCK,
  ];

  static final $core.Map<$core.int, BitSwapMessage_MessageType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static BitSwapMessage_MessageType? valueOf($core.int value) => _byValue[value];

  const BitSwapMessage_MessageType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
