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

class PinTypeProto extends $pb.ProtobufEnum {
  static const PinTypeProto PIN_TYPE_UNSPECIFIED = PinTypeProto._(0, _omitEnumNames ? '' : 'PIN_TYPE_UNSPECIFIED');
  static const PinTypeProto PIN_TYPE_DIRECT = PinTypeProto._(1, _omitEnumNames ? '' : 'PIN_TYPE_DIRECT');
  static const PinTypeProto PIN_TYPE_RECURSIVE = PinTypeProto._(2, _omitEnumNames ? '' : 'PIN_TYPE_RECURSIVE');

  static const $core.List<PinTypeProto> values = <PinTypeProto> [
    PIN_TYPE_UNSPECIFIED,
    PIN_TYPE_DIRECT,
    PIN_TYPE_RECURSIVE,
  ];

  static final $core.Map<$core.int, PinTypeProto> _byValue = $pb.ProtobufEnum.initByValue(values);
  static PinTypeProto? valueOf($core.int value) => _byValue[value];

  const PinTypeProto._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
