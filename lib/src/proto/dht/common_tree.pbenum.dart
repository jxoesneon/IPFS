//
//  Generated code. Do not modify.
//  source: common_tree.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class NodeColor extends $pb.ProtobufEnum {
  static const NodeColor RED = NodeColor._(0, _omitEnumNames ? '' : 'RED');
  static const NodeColor BLACK = NodeColor._(1, _omitEnumNames ? '' : 'BLACK');

  static const $core.List<NodeColor> values = <NodeColor> [
    RED,
    BLACK,
  ];

  static final $core.Map<$core.int, NodeColor> _byValue = $pb.ProtobufEnum.initByValue(values);
  static NodeColor? valueOf($core.int value) => _byValue[value];

  const NodeColor._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
