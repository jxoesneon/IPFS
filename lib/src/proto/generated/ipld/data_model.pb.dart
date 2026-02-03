// This is a generated file - do not edit.
//
// Generated from ipld/data_model.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'data_model.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'data_model.pbenum.dart';

enum IPLDNode_Value {
  boolValue,
  intValue,
  floatValue,
  stringValue,
  bytesValue,
  listValue,
  mapValue,
  linkValue,
  bigIntValue,
  notSet
}

/// Main message wrapping all IPLD value types
class IPLDNode extends $pb.GeneratedMessage {
  factory IPLDNode({
    Kind? kind,
    $core.bool? boolValue,
    $fixnum.Int64? intValue,
    $core.double? floatValue,
    $core.String? stringValue,
    $core.List<$core.int>? bytesValue,
    IPLDList? listValue,
    IPLDMap? mapValue,
    IPLDLink? linkValue,
    $core.List<$core.int>? bigIntValue,
  }) {
    final result = create();
    if (kind != null) result.kind = kind;
    if (boolValue != null) result.boolValue = boolValue;
    if (intValue != null) result.intValue = intValue;
    if (floatValue != null) result.floatValue = floatValue;
    if (stringValue != null) result.stringValue = stringValue;
    if (bytesValue != null) result.bytesValue = bytesValue;
    if (listValue != null) result.listValue = listValue;
    if (mapValue != null) result.mapValue = mapValue;
    if (linkValue != null) result.linkValue = linkValue;
    if (bigIntValue != null) result.bigIntValue = bigIntValue;
    return result;
  }

  IPLDNode._();

  factory IPLDNode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IPLDNode.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, IPLDNode_Value> _IPLDNode_ValueByTag = {
    2: IPLDNode_Value.boolValue,
    3: IPLDNode_Value.intValue,
    4: IPLDNode_Value.floatValue,
    5: IPLDNode_Value.stringValue,
    6: IPLDNode_Value.bytesValue,
    7: IPLDNode_Value.listValue,
    8: IPLDNode_Value.mapValue,
    9: IPLDNode_Value.linkValue,
    10: IPLDNode_Value.bigIntValue,
    0: IPLDNode_Value.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IPLDNode',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipld'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6, 7, 8, 9, 10])
    ..aE<Kind>(1, _omitFieldNames ? '' : 'kind', enumValues: Kind.values)
    ..aOB(2, _omitFieldNames ? '' : 'boolValue')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'intValue', $pb.PbFieldType.OS6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aD(4, _omitFieldNames ? '' : 'floatValue')
    ..aOS(5, _omitFieldNames ? '' : 'stringValue')
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'bytesValue', $pb.PbFieldType.OY)
    ..aOM<IPLDList>(7, _omitFieldNames ? '' : 'listValue',
        subBuilder: IPLDList.create)
    ..aOM<IPLDMap>(8, _omitFieldNames ? '' : 'mapValue',
        subBuilder: IPLDMap.create)
    ..aOM<IPLDLink>(9, _omitFieldNames ? '' : 'linkValue',
        subBuilder: IPLDLink.create)
    ..a<$core.List<$core.int>>(
        10, _omitFieldNames ? '' : 'bigIntValue', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IPLDNode clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IPLDNode copyWith(void Function(IPLDNode) updates) =>
      super.copyWith((message) => updates(message as IPLDNode)) as IPLDNode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IPLDNode create() => IPLDNode._();
  @$core.override
  IPLDNode createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IPLDNode getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IPLDNode>(create);
  static IPLDNode? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  IPLDNode_Value whichValue() => _IPLDNode_ValueByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  void clearValue() => $_clearField($_whichOneof(0));

  /// The kind of value stored
  @$pb.TagNumber(1)
  Kind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(Kind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  /// Basic types
  @$pb.TagNumber(2)
  $core.bool get boolValue => $_getBF(1);
  @$pb.TagNumber(2)
  set boolValue($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBoolValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearBoolValue() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get intValue => $_getI64(2);
  @$pb.TagNumber(3)
  set intValue($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIntValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearIntValue() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get floatValue => $_getN(3);
  @$pb.TagNumber(4)
  set floatValue($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFloatValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearFloatValue() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get stringValue => $_getSZ(4);
  @$pb.TagNumber(5)
  set stringValue($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStringValue() => $_has(4);
  @$pb.TagNumber(5)
  void clearStringValue() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get bytesValue => $_getN(5);
  @$pb.TagNumber(6)
  set bytesValue($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBytesValue() => $_has(5);
  @$pb.TagNumber(6)
  void clearBytesValue() => $_clearField(6);

  /// Complex types
  @$pb.TagNumber(7)
  IPLDList get listValue => $_getN(6);
  @$pb.TagNumber(7)
  set listValue(IPLDList value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasListValue() => $_has(6);
  @$pb.TagNumber(7)
  void clearListValue() => $_clearField(7);
  @$pb.TagNumber(7)
  IPLDList ensureListValue() => $_ensure(6);

  @$pb.TagNumber(8)
  IPLDMap get mapValue => $_getN(7);
  @$pb.TagNumber(8)
  set mapValue(IPLDMap value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasMapValue() => $_has(7);
  @$pb.TagNumber(8)
  void clearMapValue() => $_clearField(8);
  @$pb.TagNumber(8)
  IPLDMap ensureMapValue() => $_ensure(7);

  @$pb.TagNumber(9)
  IPLDLink get linkValue => $_getN(8);
  @$pb.TagNumber(9)
  set linkValue(IPLDLink value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasLinkValue() => $_has(8);
  @$pb.TagNumber(9)
  void clearLinkValue() => $_clearField(9);
  @$pb.TagNumber(9)
  IPLDLink ensureLinkValue() => $_ensure(8);

  /// Special case: big integers that don't fit in sint64
  @$pb.TagNumber(10)
  $core.List<$core.int> get bigIntValue => $_getN(9);
  @$pb.TagNumber(10)
  set bigIntValue($core.List<$core.int> value) => $_setBytes(9, value);
  @$pb.TagNumber(10)
  $core.bool hasBigIntValue() => $_has(9);
  @$pb.TagNumber(10)
  void clearBigIntValue() => $_clearField(10);
}

/// Represents an ordered sequence of IPLD values
class IPLDList extends $pb.GeneratedMessage {
  factory IPLDList({
    $core.Iterable<IPLDNode>? values,
  }) {
    final result = create();
    if (values != null) result.values.addAll(values);
    return result;
  }

  IPLDList._();

  factory IPLDList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IPLDList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IPLDList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipld'),
      createEmptyInstance: create)
    ..pPM<IPLDNode>(1, _omitFieldNames ? '' : 'values',
        subBuilder: IPLDNode.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IPLDList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IPLDList copyWith(void Function(IPLDList) updates) =>
      super.copyWith((message) => updates(message as IPLDList)) as IPLDList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IPLDList create() => IPLDList._();
  @$core.override
  IPLDList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IPLDList getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IPLDList>(create);
  static IPLDList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<IPLDNode> get values => $_getList(0);
}

/// Represents key-value associations
class IPLDMap extends $pb.GeneratedMessage {
  factory IPLDMap({
    $core.Iterable<MapEntry>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addAll(entries);
    return result;
  }

  IPLDMap._();

  factory IPLDMap.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IPLDMap.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IPLDMap',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipld'),
      createEmptyInstance: create)
    ..pPM<MapEntry>(1, _omitFieldNames ? '' : 'entries',
        subBuilder: MapEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IPLDMap clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IPLDMap copyWith(void Function(IPLDMap) updates) =>
      super.copyWith((message) => updates(message as IPLDMap)) as IPLDMap;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IPLDMap create() => IPLDMap._();
  @$core.override
  IPLDMap createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IPLDMap getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IPLDMap>(create);
  static IPLDMap? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MapEntry> get entries => $_getList(0);
}

/// Individual map entry
class MapEntry extends $pb.GeneratedMessage {
  factory MapEntry({
    $core.String? key,
    IPLDNode? value,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    return result;
  }

  MapEntry._();

  factory MapEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MapEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MapEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipld'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOM<IPLDNode>(2, _omitFieldNames ? '' : 'value',
        subBuilder: IPLDNode.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MapEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MapEntry copyWith(void Function(MapEntry) updates) =>
      super.copyWith((message) => updates(message as MapEntry)) as MapEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MapEntry create() => MapEntry._();
  @$core.override
  MapEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MapEntry getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MapEntry>(create);
  static MapEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  IPLDNode get value => $_getN(1);
  @$pb.TagNumber(2)
  set value(IPLDNode value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
  @$pb.TagNumber(2)
  IPLDNode ensureValue() => $_ensure(1);
}

/// Represents a CID link
class IPLDLink extends $pb.GeneratedMessage {
  factory IPLDLink({
    $core.int? version,
    $core.String? codec,
    $core.List<$core.int>? multihash,
  }) {
    final result = create();
    if (version != null) result.version = version;
    if (codec != null) result.codec = codec;
    if (multihash != null) result.multihash = multihash;
    return result;
  }

  IPLDLink._();

  factory IPLDLink.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IPLDLink.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IPLDLink',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipld'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'version', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'codec')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'multihash', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IPLDLink clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IPLDLink copyWith(void Function(IPLDLink) updates) =>
      super.copyWith((message) => updates(message as IPLDLink)) as IPLDLink;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IPLDLink create() => IPLDLink._();
  @$core.override
  IPLDLink createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IPLDLink getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IPLDLink>(create);
  static IPLDLink? _defaultInstance;

  /// CID version (0 or 1)
  @$pb.TagNumber(1)
  $core.int get version => $_getIZ(0);
  @$pb.TagNumber(1)
  set version($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  /// Codec of the target content
  @$pb.TagNumber(2)
  $core.String get codec => $_getSZ(1);
  @$pb.TagNumber(2)
  set codec($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCodec() => $_has(1);
  @$pb.TagNumber(2)
  void clearCodec() => $_clearField(2);

  /// Multihash of the target content
  @$pb.TagNumber(3)
  $core.List<$core.int> get multihash => $_getN(2);
  @$pb.TagNumber(3)
  set multihash($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMultihash() => $_has(2);
  @$pb.TagNumber(3)
  void clearMultihash() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
