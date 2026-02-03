// This is a generated file - do not edit.
//
// Generated from ipld/data_model.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Enumeration of all possible IPLD kinds
class Kind extends $pb.ProtobufEnum {
  static const Kind NULL = Kind._(0, _omitEnumNames ? '' : 'NULL');
  static const Kind BOOL = Kind._(1, _omitEnumNames ? '' : 'BOOL');
  static const Kind INTEGER = Kind._(2, _omitEnumNames ? '' : 'INTEGER');
  static const Kind FLOAT = Kind._(3, _omitEnumNames ? '' : 'FLOAT');
  static const Kind STRING = Kind._(4, _omitEnumNames ? '' : 'STRING');
  static const Kind BYTES = Kind._(5, _omitEnumNames ? '' : 'BYTES');
  static const Kind LIST = Kind._(6, _omitEnumNames ? '' : 'LIST');
  static const Kind MAP = Kind._(7, _omitEnumNames ? '' : 'MAP');
  static const Kind LINK = Kind._(8, _omitEnumNames ? '' : 'LINK');
  static const Kind BIG_INT = Kind._(9, _omitEnumNames ? '' : 'BIG_INT');

  static const $core.List<Kind> values = <Kind>[
    NULL,
    BOOL,
    INTEGER,
    FLOAT,
    STRING,
    BYTES,
    LIST,
    MAP,
    LINK,
    BIG_INT,
  ];

  static final $core.List<Kind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 9);
  static Kind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Kind._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');

