//
//  Generated code. Do not modify.
//  source: graphsync/graphsync.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Standard response status codes
class ResponseStatus extends $pb.ProtobufEnum {
  static const ResponseStatus RS_IN_PROGRESS = ResponseStatus._(0, _omitEnumNames ? '' : 'RS_IN_PROGRESS');
  static const ResponseStatus RS_COMPLETED = ResponseStatus._(1, _omitEnumNames ? '' : 'RS_COMPLETED');
  static const ResponseStatus RS_REJECTED = ResponseStatus._(2, _omitEnumNames ? '' : 'RS_REJECTED');
  static const ResponseStatus RS_CANCELLED = ResponseStatus._(3, _omitEnumNames ? '' : 'RS_CANCELLED');
  static const ResponseStatus RS_PAUSED = ResponseStatus._(4, _omitEnumNames ? '' : 'RS_PAUSED');
  static const ResponseStatus RS_ERROR = ResponseStatus._(5, _omitEnumNames ? '' : 'RS_ERROR');
  static const ResponseStatus RS_PAUSED_PENDING_RESOURCES = ResponseStatus._(6, _omitEnumNames ? '' : 'RS_PAUSED_PENDING_RESOURCES');

  static const $core.List<ResponseStatus> values = <ResponseStatus> [
    RS_IN_PROGRESS,
    RS_COMPLETED,
    RS_REJECTED,
    RS_CANCELLED,
    RS_PAUSED,
    RS_ERROR,
    RS_PAUSED_PENDING_RESOURCES,
  ];

  static final $core.Map<$core.int, ResponseStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static ResponseStatus? valueOf($core.int value) => _byValue[value];

  const ResponseStatus._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
