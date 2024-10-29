//
//  Generated code. Do not modify.
//  source: core/pin.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Enum representing the different types of pins in IPFS.
class PinTypeProto extends $pb.ProtobufEnum {
  static const PinTypeProto DIRECT = PinTypeProto._(0, _omitEnumNames ? '' : 'DIRECT');
  static const PinTypeProto RECURSIVE = PinTypeProto._(1, _omitEnumNames ? '' : 'RECURSIVE');

  static const $core.List<PinTypeProto> values = <PinTypeProto> [
    DIRECT,
    RECURSIVE,
  ];

  static final $core.Map<$core.int, PinTypeProto> _byValue = $pb.ProtobufEnum.initByValue(values);
  static PinTypeProto? valueOf($core.int value) => _byValue[value];

  const PinTypeProto._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
