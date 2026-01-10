// This is a generated file - do not edit.
//
// Generated from unixfs/unixfs.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Data_DataType extends $pb.ProtobufEnum {
  /// Raw file data
  static const Data_DataType Raw = Data_DataType._(0, _omitEnumNames ? '' : 'Raw');

  /// Directory
  static const Data_DataType Directory = Data_DataType._(1, _omitEnumNames ? '' : 'Directory');

  /// Regular file
  static const Data_DataType File = Data_DataType._(2, _omitEnumNames ? '' : 'File');

  /// Metadata
  static const Data_DataType Metadata = Data_DataType._(3, _omitEnumNames ? '' : 'Metadata');

  /// Symlink
  static const Data_DataType Symlink = Data_DataType._(4, _omitEnumNames ? '' : 'Symlink');

  /// Hard link
  static const Data_DataType HAMTShard = Data_DataType._(5, _omitEnumNames ? '' : 'HAMTShard');

  static const $core.List<Data_DataType> values = <Data_DataType>[
    Raw,
    Directory,
    File,
    Metadata,
    Symlink,
    HAMTShard,
  ];

  static final $core.List<Data_DataType?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 5);
  static Data_DataType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Data_DataType._(super.value, super.name);
}

const $core.bool _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
