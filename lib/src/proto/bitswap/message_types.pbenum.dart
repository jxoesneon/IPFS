//
//  Generated code. Do not modify.
//  source: lib/src/proto/bitswap/message_types.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Define enums for WantType and BlockPresenceType
class WantType extends $pb.ProtobufEnum {
  static const WantType WANT_TYPE_BLOCK = WantType._(0, _omitEnumNames ? '' : 'WANT_TYPE_BLOCK');
  static const WantType WANT_TYPE_HAVE = WantType._(1, _omitEnumNames ? '' : 'WANT_TYPE_HAVE');

  static const $core.List<WantType> values = <WantType> [
    WANT_TYPE_BLOCK,
    WANT_TYPE_HAVE,
  ];

  static final $core.Map<$core.int, WantType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static WantType? valueOf($core.int value) => _byValue[value];

  const WantType._($core.int v, $core.String n) : super(v, n);
}

class BlockPresenceType extends $pb.ProtobufEnum {
  static const BlockPresenceType BLOCK_PRESENCE_HAVE = BlockPresenceType._(0, _omitEnumNames ? '' : 'BLOCK_PRESENCE_HAVE');
  static const BlockPresenceType BLOCK_PRESENCE_DONT_HAVE = BlockPresenceType._(1, _omitEnumNames ? '' : 'BLOCK_PRESENCE_DONT_HAVE');

  static const $core.List<BlockPresenceType> values = <BlockPresenceType> [
    BLOCK_PRESENCE_HAVE,
    BLOCK_PRESENCE_DONT_HAVE,
  ];

  static final $core.Map<$core.int, BlockPresenceType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static BlockPresenceType? valueOf($core.int value) => _byValue[value];

  const BlockPresenceType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
