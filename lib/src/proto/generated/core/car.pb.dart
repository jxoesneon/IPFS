// This is a generated file - do not edit.
//
// Generated from core/car.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:dart_ipfs/src/proto/generated/google/protobuf/any.pb.dart'
    as $1;

import 'block.pb.dart' as $0;
import 'cid.pb.dart' as $2;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Represents a Content Addressable Archive (CAR).
class CarProto extends $pb.GeneratedMessage {
  factory CarProto({
    $core.int? version,
    $core.Iterable<$core.String>? characteristics,
    $core.Iterable<$core.MapEntry<$core.String, $1.Any>>? pragma,
    $core.Iterable<$0.BlockProto>? blocks,
    CarIndex? index,
    CarHeader? header,
  }) {
    final result = create();
    if (version != null) result.version = version;
    if (characteristics != null) result.characteristics.addAll(characteristics);
    if (pragma != null) result.pragma.addEntries(pragma);
    if (blocks != null) result.blocks.addAll(blocks);
    if (index != null) result.index = index;
    if (header != null) result.header = header;
    return result;
  }

  CarProto._();

  factory CarProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CarProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CarProto',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'version')
    ..pPS(2, _omitFieldNames ? '' : 'characteristics')
    ..m<$core.String, $1.Any>(3, _omitFieldNames ? '' : 'pragma',
        entryClassName: 'CarProto.PragmaEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: $1.Any.create,
        valueDefaultOrMaker: $1.Any.getDefault,
        packageName: const $pb.PackageName('ipfs.core.data_structures'))
    ..pPM<$0.BlockProto>(4, _omitFieldNames ? '' : 'blocks',
        subBuilder: $0.BlockProto.create)
    ..aOM<CarIndex>(5, _omitFieldNames ? '' : 'index',
        subBuilder: CarIndex.create)
    ..aOM<CarHeader>(6, _omitFieldNames ? '' : 'header',
        subBuilder: CarHeader.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CarProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CarProto copyWith(void Function(CarProto) updates) =>
      super.copyWith((message) => updates(message as CarProto)) as CarProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CarProto create() => CarProto._();
  @$core.override
  CarProto createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CarProto getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CarProto>(create);
  static CarProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get version => $_getIZ(0);
  @$pb.TagNumber(1)
  set version($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get characteristics => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $1.Any> get pragma => $_getMap(2);

  @$pb.TagNumber(4)
  $pb.PbList<$0.BlockProto> get blocks => $_getList(3);

  @$pb.TagNumber(5)
  CarIndex get index => $_getN(4);
  @$pb.TagNumber(5)
  set index(CarIndex value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasIndex() => $_has(4);
  @$pb.TagNumber(5)
  void clearIndex() => $_clearField(5);
  @$pb.TagNumber(5)
  CarIndex ensureIndex() => $_ensure(4);

  @$pb.TagNumber(6)
  CarHeader get header => $_getN(5);
  @$pb.TagNumber(6)
  set header(CarHeader value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasHeader() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeader() => $_clearField(6);
  @$pb.TagNumber(6)
  CarHeader ensureHeader() => $_ensure(5);
}

/// Represents a CAR file header
class CarHeader extends $pb.GeneratedMessage {
  factory CarHeader({
    $core.int? version,
    $core.Iterable<$core.String>? characteristics,
    $core.Iterable<$2.IPFSCIDProto>? roots,
    $core.Iterable<$core.MapEntry<$core.String, $1.Any>>? pragma,
  }) {
    final result = create();
    if (version != null) result.version = version;
    if (characteristics != null) result.characteristics.addAll(characteristics);
    if (roots != null) result.roots.addAll(roots);
    if (pragma != null) result.pragma.addEntries(pragma);
    return result;
  }

  CarHeader._();

  factory CarHeader.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CarHeader.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CarHeader',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'version')
    ..pPS(2, _omitFieldNames ? '' : 'characteristics')
    ..pPM<$2.IPFSCIDProto>(3, _omitFieldNames ? '' : 'roots',
        subBuilder: $2.IPFSCIDProto.create)
    ..m<$core.String, $1.Any>(4, _omitFieldNames ? '' : 'pragma',
        entryClassName: 'CarHeader.PragmaEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: $1.Any.create,
        valueDefaultOrMaker: $1.Any.getDefault,
        packageName: const $pb.PackageName('ipfs.core.data_structures'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CarHeader clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CarHeader copyWith(void Function(CarHeader) updates) =>
      super.copyWith((message) => updates(message as CarHeader)) as CarHeader;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CarHeader create() => CarHeader._();
  @$core.override
  CarHeader createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CarHeader getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CarHeader>(create);
  static CarHeader? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get version => $_getIZ(0);
  @$pb.TagNumber(1)
  set version($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get characteristics => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$2.IPFSCIDProto> get roots => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $1.Any> get pragma => $_getMap(3);
}

/// Represents an index entry for a block in the CAR
class CarIndex extends $pb.GeneratedMessage {
  factory CarIndex({
    $core.Iterable<IndexEntry>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addAll(entries);
    return result;
  }

  CarIndex._();

  factory CarIndex.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CarIndex.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CarIndex',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..pPM<IndexEntry>(1, _omitFieldNames ? '' : 'entries',
        subBuilder: IndexEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CarIndex clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CarIndex copyWith(void Function(CarIndex) updates) =>
      super.copyWith((message) => updates(message as CarIndex)) as CarIndex;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CarIndex create() => CarIndex._();
  @$core.override
  CarIndex createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CarIndex getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CarIndex>(create);
  static CarIndex? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<IndexEntry> get entries => $_getList(0);
}

/// Represents a single index entry
class IndexEntry extends $pb.GeneratedMessage {
  factory IndexEntry({
    $core.String? cid,
    $fixnum.Int64? offset,
    $fixnum.Int64? length,
  }) {
    final result = create();
    if (cid != null) result.cid = cid;
    if (offset != null) result.offset = offset;
    if (length != null) result.length = length;
    return result;
  }

  IndexEntry._();

  factory IndexEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IndexEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IndexEntry',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.core.data_structures'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cid')
    ..aInt64(2, _omitFieldNames ? '' : 'offset')
    ..aInt64(3, _omitFieldNames ? '' : 'length')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IndexEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IndexEntry copyWith(void Function(IndexEntry) updates) =>
      super.copyWith((message) => updates(message as IndexEntry)) as IndexEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IndexEntry create() => IndexEntry._();
  @$core.override
  IndexEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IndexEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IndexEntry>(create);
  static IndexEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cid => $_getSZ(0);
  @$pb.TagNumber(1)
  set cid($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get offset => $_getI64(1);
  @$pb.TagNumber(2)
  set offset($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get length => $_getI64(2);
  @$pb.TagNumber(3)
  set length($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLength() => $_has(2);
  @$pb.TagNumber(3)
  void clearLength() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
