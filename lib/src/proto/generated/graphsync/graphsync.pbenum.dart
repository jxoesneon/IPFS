// This is a generated file - do not edit.
//
// Generated from graphsync/graphsync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Standard response status codes
class ResponseStatus extends $pb.ProtobufEnum {
  /// Request is being processed
  static const ResponseStatus RS_IN_PROGRESS =
      ResponseStatus._(0, _omitEnumNames ? '' : 'RS_IN_PROGRESS');

  /// Request completed successfully
  static const ResponseStatus RS_COMPLETED =
      ResponseStatus._(1, _omitEnumNames ? '' : 'RS_COMPLETED');

  /// Request failed with error
  static const ResponseStatus RS_REJECTED =
      ResponseStatus._(2, _omitEnumNames ? '' : 'RS_REJECTED');

  /// Request was cancelled
  static const ResponseStatus RS_CANCELLED =
      ResponseStatus._(3, _omitEnumNames ? '' : 'RS_CANCELLED');

  /// Request is paused
  static const ResponseStatus RS_PAUSED =
      ResponseStatus._(4, _omitEnumNames ? '' : 'RS_PAUSED');

  /// Request error occurred
  static const ResponseStatus RS_ERROR =
      ResponseStatus._(5, _omitEnumNames ? '' : 'RS_ERROR');

  /// Request is paused pending local resources
  static const ResponseStatus RS_PAUSED_PENDING_RESOURCES =
      ResponseStatus._(6, _omitEnumNames ? '' : 'RS_PAUSED_PENDING_RESOURCES');

  static const $core.List<ResponseStatus> values = <ResponseStatus>[
    RS_IN_PROGRESS,
    RS_COMPLETED,
    RS_REJECTED,
    RS_CANCELLED,
    RS_PAUSED,
    RS_ERROR,
    RS_PAUSED_PENDING_RESOURCES,
  ];

  static final $core.List<ResponseStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static ResponseStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ResponseStatus._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');

