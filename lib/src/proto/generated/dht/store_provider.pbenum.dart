// This is a generated file - do not edit.
//
// Generated from dht/store_provider.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Status of the store operation
class StoreProviderResponse_Status extends $pb.ProtobufEnum {
  static const StoreProviderResponse_Status SUCCESS =
      StoreProviderResponse_Status._(0, _omitEnumNames ? '' : 'SUCCESS');
  static const StoreProviderResponse_Status ERROR =
      StoreProviderResponse_Status._(1, _omitEnumNames ? '' : 'ERROR');
  static const StoreProviderResponse_Status CAPACITY_EXCEEDED =
      StoreProviderResponse_Status._(2, _omitEnumNames ? '' : 'CAPACITY_EXCEEDED');

  static const $core.List<StoreProviderResponse_Status> values = <StoreProviderResponse_Status>[
    SUCCESS,
    ERROR,
    CAPACITY_EXCEEDED,
  ];

  static final $core.List<StoreProviderResponse_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static StoreProviderResponse_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StoreProviderResponse_Status._(super.value, super.name);
}

const $core.bool _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
