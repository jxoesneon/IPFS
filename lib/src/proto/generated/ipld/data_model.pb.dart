//
//  Generated code. Do not modify.
//  source: ipld/data_model.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'data_model.pbenum.dart';

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
    final $result = create();
    if (kind != null) {
      $result.kind = kind;
    }
    if (boolValue != null) {
      $result.boolValue = boolValue;
    }
    if (intValue != null) {
      $result.intValue = intValue;
    }
    if (floatValue != null) {
      $result.floatValue = floatValue;
    }
    if (stringValue != null) {
      $result.stringValue = stringValue;
    }
    if (bytesValue != null) {
      $result.bytesValue = bytesValue;
    }
    if (listValue != null) {
      $result.listValue = listValue;
    }
    if (mapValue != null) {
      $result.mapValue = mapValue;
    }
    if (linkValue != null) {
      $result.linkValue = linkValue;
    }
    if (bigIntValue != null) {
      $result.bigIntValue = bigIntValue;
    }
    return $result;
  }
  IPLDNode._() : super();
  factory IPLDNode.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory IPLDNode.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, IPLDNode_Value> _IPLDNode_ValueByTag = {
    2 : IPLDNode_Value.boolValue,
    3 : IPLDNode_Value.intValue,
    4 : IPLDNode_Value.floatValue,
    5 : IPLDNode_Value.stringValue,
    6 : IPLDNode_Value.bytesValue,
    7 : IPLDNode_Value.listValue,
    8 : IPLDNode_Value.mapValue,
    9 : IPLDNode_Value.linkValue,
    10 : IPLDNode_Value.bigIntValue,
    0 : IPLDNode_Value.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'IPLDNode', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipld'), createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6, 7, 8, 9, 10])
    ..e<Kind>(1, _omitFieldNames ? '' : 'kind', $pb.PbFieldType.OE, defaultOrMaker: Kind.NULL, valueOf: Kind.valueOf, enumValues: Kind.values)
    ..aOB(2, _omitFieldNames ? '' : 'boolValue')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'intValue', $pb.PbFieldType.OS6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.double>(4, _omitFieldNames ? '' : 'floatValue', $pb.PbFieldType.OD)
    ..aOS(5, _omitFieldNames ? '' : 'stringValue')
    ..a<$core.List<$core.int>>(6, _omitFieldNames ? '' : 'bytesValue', $pb.PbFieldType.OY)
    ..aOM<IPLDList>(7, _omitFieldNames ? '' : 'listValue', subBuilder: IPLDList.create)
    ..aOM<IPLDMap>(8, _omitFieldNames ? '' : 'mapValue', subBuilder: IPLDMap.create)
    ..aOM<IPLDLink>(9, _omitFieldNames ? '' : 'linkValue', subBuilder: IPLDLink.create)
    ..a<$core.List<$core.int>>(10, _omitFieldNames ? '' : 'bigIntValue', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  IPLDNode clone() => IPLDNode()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  IPLDNode copyWith(void Function(IPLDNode) updates) => super.copyWith((message) => updates(message as IPLDNode)) as IPLDNode;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IPLDNode create() => IPLDNode._();
  IPLDNode createEmptyInstance() => create();
  static $pb.PbList<IPLDNode> createRepeated() => $pb.PbList<IPLDNode>();
  @$core.pragma('dart2js:noInline')
  static IPLDNode getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IPLDNode>(create);
  static IPLDNode? _defaultInstance;

  IPLDNode_Value whichValue() => _IPLDNode_ValueByTag[$_whichOneof(0)]!;
  void clearValue() => clearField($_whichOneof(0));

  /// The kind of value stored
  @$pb.TagNumber(1)
  Kind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(Kind v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => clearField(1);

  /// Basic types
  @$pb.TagNumber(2)
  $core.bool get boolValue => $_getBF(1);
  @$pb.TagNumber(2)
  set boolValue($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasBoolValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearBoolValue() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get intValue => $_getI64(2);
  @$pb.TagNumber(3)
  set intValue($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasIntValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearIntValue() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get floatValue => $_getN(3);
  @$pb.TagNumber(4)
  set floatValue($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasFloatValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearFloatValue() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get stringValue => $_getSZ(4);
  @$pb.TagNumber(5)
  set stringValue($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasStringValue() => $_has(4);
  @$pb.TagNumber(5)
  void clearStringValue() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get bytesValue => $_getN(5);
  @$pb.TagNumber(6)
  set bytesValue($core.List<$core.int> v) { $_setBytes(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasBytesValue() => $_has(5);
  @$pb.TagNumber(6)
  void clearBytesValue() => clearField(6);

  /// Complex types
  @$pb.TagNumber(7)
  IPLDList get listValue => $_getN(6);
  @$pb.TagNumber(7)
  set listValue(IPLDList v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasListValue() => $_has(6);
  @$pb.TagNumber(7)
  void clearListValue() => clearField(7);
  @$pb.TagNumber(7)
  IPLDList ensureListValue() => $_ensure(6);

  @$pb.TagNumber(8)
  IPLDMap get mapValue => $_getN(7);
  @$pb.TagNumber(8)
  set mapValue(IPLDMap v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasMapValue() => $_has(7);
  @$pb.TagNumber(8)
  void clearMapValue() => clearField(8);
  @$pb.TagNumber(8)
  IPLDMap ensureMapValue() => $_ensure(7);

  @$pb.TagNumber(9)
  IPLDLink get linkValue => $_getN(8);
  @$pb.TagNumber(9)
  set linkValue(IPLDLink v) { setField(9, v); }
  @$pb.TagNumber(9)
  $core.bool hasLinkValue() => $_has(8);
  @$pb.TagNumber(9)
  void clearLinkValue() => clearField(9);
  @$pb.TagNumber(9)
  IPLDLink ensureLinkValue() => $_ensure(8);

  /// Special case: big integers that don't fit in sint64
  @$pb.TagNumber(10)
  $core.List<$core.int> get bigIntValue => $_getN(9);
  @$pb.TagNumber(10)
  set bigIntValue($core.List<$core.int> v) { $_setBytes(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasBigIntValue() => $_has(9);
  @$pb.TagNumber(10)
  void clearBigIntValue() => clearField(10);
}

/// Represents an ordered sequence of IPLD values
class IPLDList extends $pb.GeneratedMessage {
  factory IPLDList({
    $core.Iterable<IPLDNode>? values,
  }) {
    final $result = create();
    if (values != null) {
      $result.values.addAll(values);
    }
    return $result;
  }
  IPLDList._() : super();
  factory IPLDList.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory IPLDList.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'IPLDList', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipld'), createEmptyInstance: create)
    ..pc<IPLDNode>(1, _omitFieldNames ? '' : 'values', $pb.PbFieldType.PM, subBuilder: IPLDNode.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  IPLDList clone() => IPLDList()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  IPLDList copyWith(void Function(IPLDList) updates) => super.copyWith((message) => updates(message as IPLDList)) as IPLDList;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IPLDList create() => IPLDList._();
  IPLDList createEmptyInstance() => create();
  static $pb.PbList<IPLDList> createRepeated() => $pb.PbList<IPLDList>();
  @$core.pragma('dart2js:noInline')
  static IPLDList getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IPLDList>(create);
  static IPLDList? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<IPLDNode> get values => $_getList(0);
}

/// Represents key-value associations
class IPLDMap extends $pb.GeneratedMessage {
  factory IPLDMap({
    $core.Iterable<MapEntry>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  IPLDMap._() : super();
  factory IPLDMap.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory IPLDMap.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'IPLDMap', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipld'), createEmptyInstance: create)
    ..pc<MapEntry>(1, _omitFieldNames ? '' : 'entries', $pb.PbFieldType.PM, subBuilder: MapEntry.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  IPLDMap clone() => IPLDMap()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  IPLDMap copyWith(void Function(IPLDMap) updates) => super.copyWith((message) => updates(message as IPLDMap)) as IPLDMap;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IPLDMap create() => IPLDMap._();
  IPLDMap createEmptyInstance() => create();
  static $pb.PbList<IPLDMap> createRepeated() => $pb.PbList<IPLDMap>();
  @$core.pragma('dart2js:noInline')
  static IPLDMap getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IPLDMap>(create);
  static IPLDMap? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<MapEntry> get entries => $_getList(0);
}

/// Individual map entry
class MapEntry extends $pb.GeneratedMessage {
  factory MapEntry({
    $core.String? key,
    IPLDNode? value,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (value != null) {
      $result.value = value;
    }
    return $result;
  }
  MapEntry._() : super();
  factory MapEntry.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MapEntry.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MapEntry', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipld'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOM<IPLDNode>(2, _omitFieldNames ? '' : 'value', subBuilder: IPLDNode.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MapEntry clone() => MapEntry()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MapEntry copyWith(void Function(MapEntry) updates) => super.copyWith((message) => updates(message as MapEntry)) as MapEntry;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MapEntry create() => MapEntry._();
  MapEntry createEmptyInstance() => create();
  static $pb.PbList<MapEntry> createRepeated() => $pb.PbList<MapEntry>();
  @$core.pragma('dart2js:noInline')
  static MapEntry getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MapEntry>(create);
  static MapEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);

  @$pb.TagNumber(2)
  IPLDNode get value => $_getN(1);
  @$pb.TagNumber(2)
  set value(IPLDNode v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);
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
    final $result = create();
    if (version != null) {
      $result.version = version;
    }
    if (codec != null) {
      $result.codec = codec;
    }
    if (multihash != null) {
      $result.multihash = multihash;
    }
    return $result;
  }
  IPLDLink._() : super();
  factory IPLDLink.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory IPLDLink.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'IPLDLink', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipld'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'version', $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'codec')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'multihash', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  IPLDLink clone() => IPLDLink()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  IPLDLink copyWith(void Function(IPLDLink) updates) => super.copyWith((message) => updates(message as IPLDLink)) as IPLDLink;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IPLDLink create() => IPLDLink._();
  IPLDLink createEmptyInstance() => create();
  static $pb.PbList<IPLDLink> createRepeated() => $pb.PbList<IPLDLink>();
  @$core.pragma('dart2js:noInline')
  static IPLDLink getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IPLDLink>(create);
  static IPLDLink? _defaultInstance;

  /// CID version (0 or 1)
  @$pb.TagNumber(1)
  $core.int get version => $_getIZ(0);
  @$pb.TagNumber(1)
  set version($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => clearField(1);

  /// Codec of the target content
  @$pb.TagNumber(2)
  $core.String get codec => $_getSZ(1);
  @$pb.TagNumber(2)
  set codec($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCodec() => $_has(1);
  @$pb.TagNumber(2)
  void clearCodec() => clearField(2);

  /// Multihash of the target content
  @$pb.TagNumber(3)
  $core.List<$core.int> get multihash => $_getN(2);
  @$pb.TagNumber(3)
  set multihash($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasMultihash() => $_has(2);
  @$pb.TagNumber(3)
  void clearMultihash() => clearField(3);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
