// This is a generated file - do not edit.
//
// Generated from core/pin.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class PinTypeProto extends $pb.ProtobufEnum {
  static const PinTypeProto PIN_TYPE_UNSPECIFIED =
      PinTypeProto._(0, _omitEnumNames ? '' : 'PIN_TYPE_UNSPECIFIED');
  static const PinTypeProto PIN_TYPE_DIRECT =
      PinTypeProto._(1, _omitEnumNames ? '' : 'PIN_TYPE_DIRECT');
  static const PinTypeProto PIN_TYPE_RECURSIVE =
      PinTypeProto._(2, _omitEnumNames ? '' : 'PIN_TYPE_RECURSIVE');

  static const $core.List<PinTypeProto> values = <PinTypeProto>[
    PIN_TYPE_UNSPECIFIED,
    PIN_TYPE_DIRECT,
    PIN_TYPE_RECURSIVE,
  ];

  static final $core.List<PinTypeProto?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static PinTypeProto? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PinTypeProto._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');

