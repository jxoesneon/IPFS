//
//  Generated code. Do not modify.
//  source: core/car.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../google/protobuf/any.pb.dart' as $6;
import 'block.pb.dart' as $0;
import 'cid.pb.dart' as $2;

/// Represents a Content Addressable Archive (CAR).
class CarProto extends $pb.GeneratedMessage {
  factory CarProto({
    $core.int? version,
    $core.Iterable<$core.String>? characteristics,
    $core.Map<$core.String, $6.Any>? pragma,
    $core.Iterable<$0.BlockProto>? blocks,
    CarIndex? index,
    CarHeader? header,
  }) {
    final $result = create();
    if (version != null) {
      $result.version = version;
    }
    if (characteristics != null) {
      $result.characteristics.addAll(characteristics);
    }
    if (pragma != null) {
      $result.pragma.addAll(pragma);
    }
    if (blocks != null) {
      $result.blocks.addAll(blocks);
    }
    if (index != null) {
      $result.index = index;
    }
    if (header != null) {
      $result.header = header;
    }
    return $result;
  }
  CarProto._() : super();
  factory CarProto.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CarProto.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CarProto',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'version', $pb.PbFieldType.O3)
    ..pPS(2, _omitFieldNames ? '' : 'characteristics')
    ..m<$core.String, $6.Any>(3, _omitFieldNames ? '' : 'pragma',
        entryClassName: 'CarProto.PragmaEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: $6.Any.create,
        valueDefaultOrMaker: $6.Any.getDefault,
        packageName: const $pb.PackageName('ipfs.core.data_structures'))
    ..pc<$0.BlockProto>(4, _omitFieldNames ? '' : 'blocks', $pb.PbFieldType.PM,
        subBuilder: $0.BlockProto.create)
    ..aOM<CarIndex>(5, _omitFieldNames ? '' : 'index',
        subBuilder: CarIndex.create)
    ..aOM<CarHeader>(6, _omitFieldNames ? '' : 'header',
        subBuilder: CarHeader.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CarProto clone() => CarProto()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CarProto copyWith(void Function(CarProto) updates) =>
      super.copyWith((message) => updates(message as CarProto)) as CarProto;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CarProto create() => CarProto._();
  CarProto createEmptyInstance() => create();
  static $pb.PbList<CarProto> createRepeated() => $pb.PbList<CarProto>();
  @$core.pragma('dart2js:noInline')
  static CarProto getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CarProto>(create);
  static CarProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get version => $_getIZ(0);
  @$pb.TagNumber(1)
  set version($core.int v) {
    $_setSignedInt32(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.String> get characteristics => $_getList(1);

  @$pb.TagNumber(3)
  $core.Map<$core.String, $6.Any> get pragma => $_getMap(2);

  @$pb.TagNumber(4)
  $core.List<$0.BlockProto> get blocks => $_getList(3);

  @$pb.TagNumber(5)
  CarIndex get index => $_getN(4);
  @$pb.TagNumber(5)
  set index(CarIndex v) {
    setField(5, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasIndex() => $_has(4);
  @$pb.TagNumber(5)
  void clearIndex() => clearField(5);
  @$pb.TagNumber(5)
  CarIndex ensureIndex() => $_ensure(4);

  @$pb.TagNumber(6)
  CarHeader get header => $_getN(5);
  @$pb.TagNumber(6)
  set header(CarHeader v) {
    setField(6, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasHeader() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeader() => clearField(6);
  @$pb.TagNumber(6)
  CarHeader ensureHeader() => $_ensure(5);
}

/// Represents a CAR file header
class CarHeader extends $pb.GeneratedMessage {
  factory CarHeader({
    $core.int? version,
    $core.Iterable<$core.String>? characteristics,
    $core.Iterable<$2.IPFSCIDProto>? roots,
    $core.Map<$core.String, $6.Any>? pragma,
  }) {
    final $result = create();
    if (version != null) {
      $result.version = version;
    }
    if (characteristics != null) {
      $result.characteristics.addAll(characteristics);
    }
    if (roots != null) {
      $result.roots.addAll(roots);
    }
    if (pragma != null) {
      $result.pragma.addAll(pragma);
    }
    return $result;
  }
  CarHeader._() : super();
  factory CarHeader.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CarHeader.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CarHeader',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'version', $pb.PbFieldType.O3)
    ..pPS(2, _omitFieldNames ? '' : 'characteristics')
    ..pc<$2.IPFSCIDProto>(3, _omitFieldNames ? '' : 'roots', $pb.PbFieldType.PM,
        subBuilder: $2.IPFSCIDProto.create)
    ..m<$core.String, $6.Any>(4, _omitFieldNames ? '' : 'pragma',
        entryClassName: 'CarHeader.PragmaEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: $6.Any.create,
        valueDefaultOrMaker: $6.Any.getDefault,
        packageName: const $pb.PackageName('ipfs.core.data_structures'))
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CarHeader clone() => CarHeader()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CarHeader copyWith(void Function(CarHeader) updates) =>
      super.copyWith((message) => updates(message as CarHeader)) as CarHeader;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CarHeader create() => CarHeader._();
  CarHeader createEmptyInstance() => create();
  static $pb.PbList<CarHeader> createRepeated() => $pb.PbList<CarHeader>();
  @$core.pragma('dart2js:noInline')
  static CarHeader getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CarHeader>(create);
  static CarHeader? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get version => $_getIZ(0);
  @$pb.TagNumber(1)
  set version($core.int v) {
    $_setSignedInt32(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.String> get characteristics => $_getList(1);

  @$pb.TagNumber(3)
  $core.List<$2.IPFSCIDProto> get roots => $_getList(2);

  @$pb.TagNumber(4)
  $core.Map<$core.String, $6.Any> get pragma => $_getMap(3);
}

/// Represents an index entry for a block in the CAR
class CarIndex extends $pb.GeneratedMessage {
  factory CarIndex({
    $core.Iterable<IndexEntry>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  CarIndex._() : super();
  factory CarIndex.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CarIndex.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CarIndex',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..pc<IndexEntry>(1, _omitFieldNames ? '' : 'entries', $pb.PbFieldType.PM,
        subBuilder: IndexEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CarIndex clone() => CarIndex()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CarIndex copyWith(void Function(CarIndex) updates) =>
      super.copyWith((message) => updates(message as CarIndex)) as CarIndex;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CarIndex create() => CarIndex._();
  CarIndex createEmptyInstance() => create();
  static $pb.PbList<CarIndex> createRepeated() => $pb.PbList<CarIndex>();
  @$core.pragma('dart2js:noInline')
  static CarIndex getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CarIndex>(create);
  static CarIndex? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<IndexEntry> get entries => $_getList(0);
}

/// Represents a single index entry
class IndexEntry extends $pb.GeneratedMessage {
  factory IndexEntry({
    $core.String? cid,
    $fixnum.Int64? offset,
    $fixnum.Int64? length,
  }) {
    final $result = create();
    if (cid != null) {
      $result.cid = cid;
    }
    if (offset != null) {
      $result.offset = offset;
    }
    if (length != null) {
      $result.length = length;
    }
    return $result;
  }
  IndexEntry._() : super();
  factory IndexEntry.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory IndexEntry.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IndexEntry',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cid')
    ..aInt64(2, _omitFieldNames ? '' : 'offset')
    ..aInt64(3, _omitFieldNames ? '' : 'length')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  IndexEntry clone() => IndexEntry()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  IndexEntry copyWith(void Function(IndexEntry) updates) =>
      super.copyWith((message) => updates(message as IndexEntry)) as IndexEntry;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IndexEntry create() => IndexEntry._();
  IndexEntry createEmptyInstance() => create();
  static $pb.PbList<IndexEntry> createRepeated() => $pb.PbList<IndexEntry>();
  @$core.pragma('dart2js:noInline')
  static IndexEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IndexEntry>(create);
  static IndexEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cid => $_getSZ(0);
  @$pb.TagNumber(1)
  set cid($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get offset => $_getI64(1);
  @$pb.TagNumber(2)
  set offset($fixnum.Int64 v) {
    $_setInt64(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get length => $_getI64(2);
  @$pb.TagNumber(3)
  set length($fixnum.Int64 v) {
    $_setInt64(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasLength() => $_has(2);
  @$pb.TagNumber(3)
  void clearLength() => clearField(3);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
