// This is a generated file - do not edit.
//
// Generated from ipns.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class IpnsEntry_ValidityType extends $pb.ProtobufEnum {
  /// EOL specifies that the record is valid until a specific time.
  static const IpnsEntry_ValidityType EOL =
      IpnsEntry_ValidityType._(0, _omitEnumNames ? '' : 'EOL');

  static const $core.List<IpnsEntry_ValidityType> values =
      <IpnsEntry_ValidityType>[
    EOL,
  ];

  static final $core.List<IpnsEntry_ValidityType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 0);
  static IpnsEntry_ValidityType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const IpnsEntry_ValidityType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');

