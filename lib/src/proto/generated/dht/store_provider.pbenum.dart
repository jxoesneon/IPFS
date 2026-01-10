//
//  Generated code. Do not modify.
//  source: dht/store_provider.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Status of the store operation
class StoreProviderResponse_Status extends $pb.ProtobufEnum {
  static const StoreProviderResponse_Status SUCCESS = StoreProviderResponse_Status._(0, _omitEnumNames ? '' : 'SUCCESS');
  static const StoreProviderResponse_Status ERROR = StoreProviderResponse_Status._(1, _omitEnumNames ? '' : 'ERROR');
  static const StoreProviderResponse_Status CAPACITY_EXCEEDED = StoreProviderResponse_Status._(2, _omitEnumNames ? '' : 'CAPACITY_EXCEEDED');

  static const $core.List<StoreProviderResponse_Status> values = <StoreProviderResponse_Status> [
    SUCCESS,
    ERROR,
    CAPACITY_EXCEEDED,
  ];

  static final $core.Map<$core.int, StoreProviderResponse_Status> _byValue = $pb.ProtobufEnum.initByValue(values);
  static StoreProviderResponse_Status? valueOf($core.int value) => _byValue[value];

  const StoreProviderResponse_Status._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
