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

class Data extends $pb.GeneratedMessage {
  factory Data({
    Data_DataType? type,
    $core.List<$core.int>? data,
    $fixnum.Int64? filesize,
    $core.Iterable<$fixnum.Int64>? blocksizes,
    $fixnum.Int64? hashType,
    $fixnum.Int64? fanout,
    $core.int? mode,
    UnixTime? mtime,
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
    return $result;
  }
  Data._() : super();
  factory Data.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Data.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Data', createEmptyInstance: create)
    ..e<Data_DataType>(1, _omitFieldNames ? '' : 'Type', $pb.PbFieldType.QE, protoName: 'Type', defaultOrMaker: Data_DataType.Raw, valueOf: Data_DataType.valueOf, enumValues: Data_DataType.values)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'Data', $pb.PbFieldType.OY, protoName: 'Data')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'filesize', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..p<$fixnum.Int64>(4, _omitFieldNames ? '' : 'blocksizes', $pb.PbFieldType.PU6)
    ..a<$fixnum.Int64>(5, _omitFieldNames ? '' : 'hashType', $pb.PbFieldType.OU6, protoName: 'hashType', defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(6, _omitFieldNames ? '' : 'fanout', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.int>(7, _omitFieldNames ? '' : 'mode', $pb.PbFieldType.OU3)
    ..aOM<UnixTime>(8, _omitFieldNames ? '' : 'mtime', subBuilder: UnixTime.create)
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

  @$pb.TagNumber(1)
  Data_DataType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(Data_DataType v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get filesize => $_getI64(2);
  @$pb.TagNumber(3)
  set filesize($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasFilesize() => $_has(2);
  @$pb.TagNumber(3)
  void clearFilesize() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$fixnum.Int64> get blocksizes => $_getList(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get hashType => $_getI64(4);
  @$pb.TagNumber(5)
  set hashType($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasHashType() => $_has(4);
  @$pb.TagNumber(5)
  void clearHashType() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get fanout => $_getI64(5);
  @$pb.TagNumber(6)
  set fanout($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasFanout() => $_has(5);
  @$pb.TagNumber(6)
  void clearFanout() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get mode => $_getIZ(6);
  @$pb.TagNumber(7)
  set mode($core.int v) { $_setUnsignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasMode() => $_has(6);
  @$pb.TagNumber(7)
  void clearMode() => clearField(7);

  @$pb.TagNumber(8)
  UnixTime get mtime => $_getN(7);
  @$pb.TagNumber(8)
  set mtime(UnixTime v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasMtime() => $_has(7);
  @$pb.TagNumber(8)
  void clearMtime() => clearField(8);
  @$pb.TagNumber(8)
  UnixTime ensureMtime() => $_ensure(7);
}

class Metadata extends $pb.GeneratedMessage {
  factory Metadata({
    $core.String? mimeType,
  }) {
    final $result = create();
    if (mimeType != null) {
      $result.mimeType = mimeType;
    }
    return $result;
  }
  Metadata._() : super();
  factory Metadata.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Metadata.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Metadata', createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'MimeType', protoName: 'MimeType')
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

  @$pb.TagNumber(1)
  $core.String get mimeType => $_getSZ(0);
  @$pb.TagNumber(1)
  set mimeType($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMimeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMimeType() => clearField(1);
}

class UnixTime extends $pb.GeneratedMessage {
  factory UnixTime({
    $fixnum.Int64? seconds,
    $core.int? fractionalNanoseconds,
  }) {
    final $result = create();
    if (seconds != null) {
      $result.seconds = seconds;
    }
    if (fractionalNanoseconds != null) {
      $result.fractionalNanoseconds = fractionalNanoseconds;
    }
    return $result;
  }
  UnixTime._() : super();
  factory UnixTime.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UnixTime.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UnixTime', createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'Seconds', $pb.PbFieldType.Q6, protoName: 'Seconds', defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'FractionalNanoseconds', $pb.PbFieldType.OF3, protoName: 'FractionalNanoseconds')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UnixTime clone() => UnixTime()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UnixTime copyWith(void Function(UnixTime) updates) => super.copyWith((message) => updates(message as UnixTime)) as UnixTime;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnixTime create() => UnixTime._();
  UnixTime createEmptyInstance() => create();
  static $pb.PbList<UnixTime> createRepeated() => $pb.PbList<UnixTime>();
  @$core.pragma('dart2js:noInline')
  static UnixTime getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UnixTime>(create);
  static UnixTime? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seconds => $_getI64(0);
  @$pb.TagNumber(1)
  set seconds($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSeconds() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeconds() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get fractionalNanoseconds => $_getIZ(1);
  @$pb.TagNumber(2)
  set fractionalNanoseconds($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasFractionalNanoseconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearFractionalNanoseconds() => clearField(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
