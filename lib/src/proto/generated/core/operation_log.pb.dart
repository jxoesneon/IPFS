//
//  Generated code. Do not modify.
//  source: core/operation_log.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'cid.pb.dart' as $0;
import 'node_type.pbenum.dart' as $5;

/// Represents a log entry for an operation performed on the IPFS node.
class OperationLogEntry extends $pb.GeneratedMessage {
  factory OperationLogEntry({
    $fixnum.Int64? timestamp,
    $core.String? operation,
    $core.String? details,
    $0.CIDProto? cid,
    $5.NodeTypeProto? nodeType,
  }) {
    final $result = create();
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    if (operation != null) {
      $result.operation = operation;
    }
    if (details != null) {
      $result.details = details;
    }
    if (cid != null) {
      $result.cid = cid;
    }
    if (nodeType != null) {
      $result.nodeType = nodeType;
    }
    return $result;
  }
  OperationLogEntry._() : super();
  factory OperationLogEntry.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory OperationLogEntry.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'OperationLogEntry', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'timestamp')
    ..aOS(2, _omitFieldNames ? '' : 'operation')
    ..aOS(3, _omitFieldNames ? '' : 'details')
    ..aOM<$0.CIDProto>(4, _omitFieldNames ? '' : 'cid', subBuilder: $0.CIDProto.create)
    ..e<$5.NodeTypeProto>(5, _omitFieldNames ? '' : 'nodeType', $pb.PbFieldType.OE, defaultOrMaker: $5.NodeTypeProto.REGULAR, valueOf: $5.NodeTypeProto.valueOf, enumValues: $5.NodeTypeProto.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  OperationLogEntry clone() => OperationLogEntry()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  OperationLogEntry copyWith(void Function(OperationLogEntry) updates) => super.copyWith((message) => updates(message as OperationLogEntry)) as OperationLogEntry;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OperationLogEntry create() => OperationLogEntry._();
  OperationLogEntry createEmptyInstance() => create();
  static $pb.PbList<OperationLogEntry> createRepeated() => $pb.PbList<OperationLogEntry>();
  @$core.pragma('dart2js:noInline')
  static OperationLogEntry getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OperationLogEntry>(create);
  static OperationLogEntry? _defaultInstance;

  /// The timestamp of when the operation was performed.
  @$pb.TagNumber(1)
  $fixnum.Int64 get timestamp => $_getI64(0);
  @$pb.TagNumber(1)
  set timestamp($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTimestamp() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimestamp() => clearField(1);

  /// A description of the operation performed.
  @$pb.TagNumber(2)
  $core.String get operation => $_getSZ(1);
  @$pb.TagNumber(2)
  set operation($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasOperation() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperation() => clearField(2);

  /// Additional details about the operation.
  @$pb.TagNumber(3)
  $core.String get details => $_getSZ(2);
  @$pb.TagNumber(3)
  set details($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDetails() => $_has(2);
  @$pb.TagNumber(3)
  void clearDetails() => clearField(3);

  /// The CID involved in the operation (optional).
  @$pb.TagNumber(4)
  $0.CIDProto get cid => $_getN(3);
  @$pb.TagNumber(4)
  set cid($0.CIDProto v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasCid() => $_has(3);
  @$pb.TagNumber(4)
  void clearCid() => clearField(4);
  @$pb.TagNumber(4)
  $0.CIDProto ensureCid() => $_ensure(3);

  /// The type of node involved in the operation (optional).
  @$pb.TagNumber(5)
  $5.NodeTypeProto get nodeType => $_getN(4);
  @$pb.TagNumber(5)
  set nodeType($5.NodeTypeProto v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasNodeType() => $_has(4);
  @$pb.TagNumber(5)
  void clearNodeType() => clearField(5);
}

/// Represents a collection of operation log entries.
class OperationLog extends $pb.GeneratedMessage {
  factory OperationLog({
    $core.Iterable<OperationLogEntry>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  OperationLog._() : super();
  factory OperationLog.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory OperationLog.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'OperationLog', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..pc<OperationLogEntry>(1, _omitFieldNames ? '' : 'entries', $pb.PbFieldType.PM, subBuilder: OperationLogEntry.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  OperationLog clone() => OperationLog()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  OperationLog copyWith(void Function(OperationLog) updates) => super.copyWith((message) => updates(message as OperationLog)) as OperationLog;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OperationLog create() => OperationLog._();
  OperationLog createEmptyInstance() => create();
  static $pb.PbList<OperationLog> createRepeated() => $pb.PbList<OperationLog>();
  @$core.pragma('dart2js:noInline')
  static OperationLog getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OperationLog>(create);
  static OperationLog? _defaultInstance;

  /// A list of log entries.
  @$pb.TagNumber(1)
  $core.List<OperationLogEntry> get entries => $_getList(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
