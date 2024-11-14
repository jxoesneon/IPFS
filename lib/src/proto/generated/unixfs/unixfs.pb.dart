//
//  Generated code. Do not modify.
//  source: unixfs/unixfs.proto
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

/// Data represents a UnixFS Data object, which can be a file, directory, symlink, etc.
class Data extends $pb.GeneratedMessage {
  factory Data({
    Data_DataType? type,
    $core.List<$core.int>? data,
    $fixnum.Int64? filesize,
    $core.Iterable<$fixnum.Int64>? blocksizes,
    $fixnum.Int64? hashType,
    $fixnum.Int64? fanout,
    $core.int? mode,
    $fixnum.Int64? mtime,
    $core.int? mtimeNsecs,
  }) {
    final $result = create();
    if (type != null) {
      $result.type = type;
    }
    if (data != null) {
      $result.data = data;
    }
    if (filesize != null) {
      $result.filesize = filesize;
    }
    if (blocksizes != null) {
      $result.blocksizes.addAll(blocksizes);
    }
    if (hashType != null) {
      $result.hashType = hashType;
    }
    if (fanout != null) {
      $result.fanout = fanout;
    }
    if (mode != null) {
      $result.mode = mode;
    }
    if (mtime != null) {
      $result.mtime = mtime;
    }
    if (mtimeNsecs != null) {
      $result.mtimeNsecs = mtimeNsecs;
    }
    return $result;
  }
  Data._() : super();
  factory Data.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Data.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Data', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.unixfs.pb'), createEmptyInstance: create)
    ..e<Data_DataType>(1, _omitFieldNames ? '' : 'Type', $pb.PbFieldType.OE, protoName: 'Type', defaultOrMaker: Data_DataType.Raw, valueOf: Data_DataType.valueOf, enumValues: Data_DataType.values)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'Data', $pb.PbFieldType.OY, protoName: 'Data')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'filesize', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..p<$fixnum.Int64>(4, _omitFieldNames ? '' : 'blocksizes', $pb.PbFieldType.KU6)
    ..a<$fixnum.Int64>(5, _omitFieldNames ? '' : 'hashType', $pb.PbFieldType.OU6, protoName: 'hashType', defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(6, _omitFieldNames ? '' : 'fanout', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.int>(7, _omitFieldNames ? '' : 'mode', $pb.PbFieldType.OU3)
    ..aInt64(8, _omitFieldNames ? '' : 'mtime')
    ..a<$core.int>(9, _omitFieldNames ? '' : 'mtimeNsecs', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Data clone() => Data()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Data copyWith(void Function(Data) updates) => super.copyWith((message) => updates(message as Data)) as Data;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Data create() => Data._();
  Data createEmptyInstance() => create();
  static $pb.PbList<Data> createRepeated() => $pb.PbList<Data>();
  @$core.pragma('dart2js:noInline')
  static Data getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Data>(create);
  static Data? _defaultInstance;

  /// The type of UnixFS node
  @$pb.TagNumber(1)
  Data_DataType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(Data_DataType v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => clearField(1);

  /// The raw data contained within this node (if any)
  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => clearField(2);

  /// The size of each block of data (when splitting a file)
  @$pb.TagNumber(3)
  $fixnum.Int64 get filesize => $_getI64(2);
  @$pb.TagNumber(3)
  set filesize($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasFilesize() => $_has(2);
  @$pb.TagNumber(3)
  void clearFilesize() => clearField(3);

  /// Optional blocksizes for each block of data
  @$pb.TagNumber(4)
  $core.List<$fixnum.Int64> get blocksizes => $_getList(3);

  /// Optional hash type for symlinks
  @$pb.TagNumber(5)
  $fixnum.Int64 get hashType => $_getI64(4);
  @$pb.TagNumber(5)
  set hashType($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasHashType() => $_has(4);
  @$pb.TagNumber(5)
  void clearHashType() => clearField(5);

  /// Optional fanout for HAMT directories
  @$pb.TagNumber(6)
  $fixnum.Int64 get fanout => $_getI64(5);
  @$pb.TagNumber(6)
  set fanout($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasFanout() => $_has(5);
  @$pb.TagNumber(6)
  void clearFanout() => clearField(6);

  /// Optional mode (permissions) for this node
  @$pb.TagNumber(7)
  $core.int get mode => $_getIZ(6);
  @$pb.TagNumber(7)
  set mode($core.int v) { $_setUnsignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasMode() => $_has(6);
  @$pb.TagNumber(7)
  void clearMode() => clearField(7);

  /// Optional modification time (in seconds since epoch)
  @$pb.TagNumber(8)
  $fixnum.Int64 get mtime => $_getI64(7);
  @$pb.TagNumber(8)
  set mtime($fixnum.Int64 v) { $_setInt64(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasMtime() => $_has(7);
  @$pb.TagNumber(8)
  void clearMtime() => clearField(8);

  /// Optional mtime nsecs
  @$pb.TagNumber(9)
  $core.int get mtimeNsecs => $_getIZ(8);
  @$pb.TagNumber(9)
  set mtimeNsecs($core.int v) { $_setUnsignedInt32(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasMtimeNsecs() => $_has(8);
  @$pb.TagNumber(9)
  void clearMtimeNsecs() => clearField(9);
}

/// Metadata represents metadata about a UnixFS node
class Metadata extends $pb.GeneratedMessage {
  factory Metadata({
    $core.String? mimeType,
    $fixnum.Int64? size,
    $core.Map<$core.String, $core.String>? properties,
  }) {
    final $result = create();
    if (mimeType != null) {
      $result.mimeType = mimeType;
    }
    if (size != null) {
      $result.size = size;
    }
    if (properties != null) {
      $result.properties.addAll(properties);
    }
    return $result;
  }
  Metadata._() : super();
  factory Metadata.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Metadata.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Metadata', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.unixfs.pb'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'MimeType', protoName: 'MimeType')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'Size', $pb.PbFieldType.OU6, protoName: 'Size', defaultOrMaker: $fixnum.Int64.ZERO)
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'properties', entryClassName: 'Metadata.PropertiesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('ipfs.unixfs.pb'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Metadata clone() => Metadata()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Metadata copyWith(void Function(Metadata) updates) => super.copyWith((message) => updates(message as Metadata)) as Metadata;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Metadata create() => Metadata._();
  Metadata createEmptyInstance() => create();
  static $pb.PbList<Metadata> createRepeated() => $pb.PbList<Metadata>();
  @$core.pragma('dart2js:noInline')
  static Metadata getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Metadata>(create);
  static Metadata? _defaultInstance;

  /// MimeType is the mime type of the file
  @$pb.TagNumber(1)
  $core.String get mimeType => $_getSZ(0);
  @$pb.TagNumber(1)
  set mimeType($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMimeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMimeType() => clearField(1);

  /// Size is the size of the file in bytes
  @$pb.TagNumber(2)
  $fixnum.Int64 get size => $_getI64(1);
  @$pb.TagNumber(2)
  set size($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearSize() => clearField(2);

  /// Additional key-value metadata pairs
  @$pb.TagNumber(3)
  $core.Map<$core.String, $core.String> get properties => $_getMap(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
