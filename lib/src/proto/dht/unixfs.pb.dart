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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'unixfs.pbenum.dart';

export 'unixfs.pbenum.dart';

/// Represents a UnixFS node in IPFS.
class UnixFS extends $pb.GeneratedMessage {
  factory UnixFS({
    UnixFSTypeProto? type,
    $core.List<$core.int>? data,
    $fixnum.Int64? blockSize,
    $fixnum.Int64? fileSize,
    $core.Iterable<$core.int>? blocksizes,
  }) {
    final result = create();
    if (type != null) {
      result.type = type;
    }
    if (data != null) {
      result.data = data;
    }
    if (blockSize != null) {
      result.blockSize = blockSize;
    }
    if (fileSize != null) {
      result.fileSize = fileSize;
    }
    if (blocksizes != null) {
      result.blocksizes.addAll(blocksizes);
    }
    return result;
  }
  UnixFS._() : super();
  factory UnixFS.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UnixFS.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UnixFS', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..e<UnixFSTypeProto>(1, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: UnixFSTypeProto.FILE, valueOf: UnixFSTypeProto.valueOf, enumValues: UnixFSTypeProto.values)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'blockSize')
    ..aInt64(4, _omitFieldNames ? '' : 'fileSize')
    ..p<$core.int>(5, _omitFieldNames ? '' : 'blocksizes', $pb.PbFieldType.K3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UnixFS clone() => UnixFS()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UnixFS copyWith(void Function(UnixFS) updates) => super.copyWith((message) => updates(message as UnixFS)) as UnixFS;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnixFS create() => UnixFS._();
  UnixFS createEmptyInstance() => create();
  static $pb.PbList<UnixFS> createRepeated() => $pb.PbList<UnixFS>();
  @$core.pragma('dart2js:noInline')
  static UnixFS getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UnixFS>(create);
  static UnixFS? _defaultInstance;

  /// The type of the node (file or directory).
  @$pb.TagNumber(1)
  UnixFSTypeProto get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(UnixFSTypeProto v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => clearField(1);

  /// The raw data of the node (optional).
  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => clearField(2);

  /// The size of each block in bytes.
  @$pb.TagNumber(3)
  $fixnum.Int64 get blockSize => $_getI64(2);
  @$pb.TagNumber(3)
  set blockSize($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasBlockSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearBlockSize() => clearField(3);

  /// The total size of the file in bytes.
  @$pb.TagNumber(4)
  $fixnum.Int64 get fileSize => $_getI64(3);
  @$pb.TagNumber(4)
  set fileSize($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasFileSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearFileSize() => clearField(4);

  /// Sizes of each block (for files).
  @$pb.TagNumber(5)
  $core.List<$core.int> get blocksizes => $_getList(4);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
