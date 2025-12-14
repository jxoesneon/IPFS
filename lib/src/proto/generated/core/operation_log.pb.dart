// This is a generated file - do not edit.
//
// Generated from core/operation_log.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'cid.pb.dart' as $0;
import 'node_type.pbenum.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Represents a log entry for an operation performed on the IPFS node.
class OperationLogEntryProto extends $pb.GeneratedMessage {
  factory OperationLogEntryProto({
    $fixnum.Int64? timestamp,
    $core.String? operation,
    $core.String? details,
    $0.IPFSCIDProto? cid,
    $1.NodeTypeProto? nodeType,
  }) {
    final result = create();
    if (timestamp != null) result.timestamp = timestamp;
    if (operation != null) result.operation = operation;
    if (details != null) result.details = details;
    if (cid != null) result.cid = cid;
    if (nodeType != null) result.nodeType = nodeType;
    return result;
  }

  OperationLogEntryProto._();

  factory OperationLogEntryProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OperationLogEntryProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OperationLogEntryProto',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'timestamp')
    ..aOS(2, _omitFieldNames ? '' : 'operation')
    ..aOS(3, _omitFieldNames ? '' : 'details')
    ..aOM<$0.IPFSCIDProto>(4, _omitFieldNames ? '' : 'cid',
        subBuilder: $0.IPFSCIDProto.create)
    ..aE<$1.NodeTypeProto>(5, _omitFieldNames ? '' : 'nodeType',
        enumValues: $1.NodeTypeProto.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationLogEntryProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationLogEntryProto copyWith(
          void Function(OperationLogEntryProto) updates) =>
      super.copyWith((message) => updates(message as OperationLogEntryProto))
          as OperationLogEntryProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OperationLogEntryProto create() => OperationLogEntryProto._();
  @$core.override
  OperationLogEntryProto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OperationLogEntryProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OperationLogEntryProto>(create);
  static OperationLogEntryProto? _defaultInstance;

  /// The timestamp of when the operation was performed.
  @$pb.TagNumber(1)
  $fixnum.Int64 get timestamp => $_getI64(0);
  @$pb.TagNumber(1)
  set timestamp($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTimestamp() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimestamp() => $_clearField(1);

  /// A description of the operation performed.
  @$pb.TagNumber(2)
  $core.String get operation => $_getSZ(1);
  @$pb.TagNumber(2)
  set operation($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOperation() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperation() => $_clearField(2);

  /// Additional details about the operation.
  @$pb.TagNumber(3)
  $core.String get details => $_getSZ(2);
  @$pb.TagNumber(3)
  set details($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDetails() => $_has(2);
  @$pb.TagNumber(3)
  void clearDetails() => $_clearField(3);

  /// The CID involved in the operation (optional).
  @$pb.TagNumber(4)
  $0.IPFSCIDProto get cid => $_getN(3);
  @$pb.TagNumber(4)
  set cid($0.IPFSCIDProto value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCid() => $_has(3);
  @$pb.TagNumber(4)
  void clearCid() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.IPFSCIDProto ensureCid() => $_ensure(3);

  /// The type of node involved in the operation (optional).
  @$pb.TagNumber(5)
  $1.NodeTypeProto get nodeType => $_getN(4);
  @$pb.TagNumber(5)
  set nodeType($1.NodeTypeProto value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasNodeType() => $_has(4);
  @$pb.TagNumber(5)
  void clearNodeType() => $_clearField(5);
}

/// Represents a collection of operation log entries.
class OperationLogProto extends $pb.GeneratedMessage {
  factory OperationLogProto({
    $core.Iterable<OperationLogEntryProto>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addAll(entries);
    return result;
  }

  OperationLogProto._();

  factory OperationLogProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OperationLogProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OperationLogProto',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..pPM<OperationLogEntryProto>(1, _omitFieldNames ? '' : 'entries',
        subBuilder: OperationLogEntryProto.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationLogProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationLogProto copyWith(void Function(OperationLogProto) updates) =>
      super.copyWith((message) => updates(message as OperationLogProto))
          as OperationLogProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OperationLogProto create() => OperationLogProto._();
  @$core.override
  OperationLogProto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OperationLogProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OperationLogProto>(create);
  static OperationLogProto? _defaultInstance;

  /// A list of log entries.
  @$pb.TagNumber(1)
  $pb.PbList<OperationLogEntryProto> get entries => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
