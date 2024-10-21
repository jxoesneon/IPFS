//
//  Generated code. Do not modify.
//  source: unixfs.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Data_DataType extends $pb.ProtobufEnum {
  static const Data_DataType RAW = Data_DataType._(0, _omitEnumNames ? '' : 'RAW');
  static const Data_DataType DIRECTORY = Data_DataType._(1, _omitEnumNames ? '' : 'DIRECTORY');
  static const Data_DataType FILE = Data_DataType._(2, _omitEnumNames ? '' : 'FILE');
  static const Data_DataType METADATA = Data_DataType._(3, _omitEnumNames ? '' : 'METADATA');
  static const Data_DataType SYMLINK = Data_DataType._(4, _omitEnumNames ? '' : 'SYMLINK');
  static const Data_DataType HAMT_SHARD = Data_DataType._(5, _omitEnumNames ? '' : 'HAMT_SHARD');

  static const $core.List<Data_DataType> values = <Data_DataType> [
    RAW,
    DIRECTORY,
    FILE,
    METADATA,
    SYMLINK,
    HAMT_SHARD,
  ];

  static final $core.Map<$core.int, Data_DataType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static Data_DataType? valueOf($core.int value) => _byValue[value];

  const Data_DataType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
