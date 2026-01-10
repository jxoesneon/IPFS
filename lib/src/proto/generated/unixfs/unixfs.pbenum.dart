//
//  Generated code. Do not modify.
//  source: unixfs/unixfs.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Data_DataType extends $pb.ProtobufEnum {
  static const Data_DataType Raw =
      Data_DataType._(0, _omitEnumNames ? '' : 'Raw');
  static const Data_DataType Directory =
      Data_DataType._(1, _omitEnumNames ? '' : 'Directory');
  static const Data_DataType File =
      Data_DataType._(2, _omitEnumNames ? '' : 'File');
  static const Data_DataType Metadata =
      Data_DataType._(3, _omitEnumNames ? '' : 'Metadata');
  static const Data_DataType Symlink =
      Data_DataType._(4, _omitEnumNames ? '' : 'Symlink');
  static const Data_DataType HAMTShard =
      Data_DataType._(5, _omitEnumNames ? '' : 'HAMTShard');

  static const $core.List<Data_DataType> values = <Data_DataType>[
    Raw,
    Directory,
    File,
    Metadata,
    Symlink,
    HAMTShard,
  ];

  static final $core.Map<$core.int, Data_DataType> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static Data_DataType? valueOf($core.int value) => _byValue[value];

  const Data_DataType._($core.int v, $core.String n) : super(v, n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
