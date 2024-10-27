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

/// Enum representing the different types of UnixFS nodes.
class UnixFSTypeProto extends $pb.ProtobufEnum {
  static const UnixFSTypeProto FILE = UnixFSTypeProto._(0, _omitEnumNames ? '' : 'FILE');
  static const UnixFSTypeProto DIRECTORY = UnixFSTypeProto._(1, _omitEnumNames ? '' : 'DIRECTORY');

  static const $core.List<UnixFSTypeProto> values = <UnixFSTypeProto> [
    FILE,
    DIRECTORY,
  ];

  static final $core.Map<$core.int, UnixFSTypeProto> _byValue = $pb.ProtobufEnum.initByValue(values);
  static UnixFSTypeProto? valueOf($core.int value) => _byValue[value];

  const UnixFSTypeProto._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
