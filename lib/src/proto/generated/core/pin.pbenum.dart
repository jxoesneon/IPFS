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

class PinType extends $pb.ProtobufEnum {
  static const PinType PIN_TYPE_UNSPECIFIED = PinType._(0, _omitEnumNames ? '' : 'PIN_TYPE_UNSPECIFIED');
  static const PinType PIN_TYPE_DIRECT = PinType._(1, _omitEnumNames ? '' : 'PIN_TYPE_DIRECT');
  static const PinType PIN_TYPE_RECURSIVE = PinType._(2, _omitEnumNames ? '' : 'PIN_TYPE_RECURSIVE');

  static const $core.List<PinType> values = <PinType> [
    PIN_TYPE_UNSPECIFIED,
    PIN_TYPE_DIRECT,
    PIN_TYPE_RECURSIVE,
  ];

  static final $core.Map<$core.int, PinType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static PinType? valueOf($core.int value) => _byValue[value];

  const PinType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
