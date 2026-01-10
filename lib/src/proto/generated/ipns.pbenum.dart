//
//  Generated code. Do not modify.
//  source: ipns.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class IpnsEntry_ValidityType extends $pb.ProtobufEnum {
  static const IpnsEntry_ValidityType EOL =
      IpnsEntry_ValidityType._(0, _omitEnumNames ? '' : 'EOL');

  static const $core.List<IpnsEntry_ValidityType> values =
      <IpnsEntry_ValidityType>[
    EOL,
  ];

  static final $core.Map<$core.int, IpnsEntry_ValidityType> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static IpnsEntry_ValidityType? valueOf($core.int value) => _byValue[value];

  const IpnsEntry_ValidityType._($core.int v, $core.String n) : super(v, n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
