//
//  Generated code. Do not modify.
//  source: bitswap/bitswap.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'bitswap.pbenum.dart';

export 'bitswap.pbenum.dart';

/// Represents a single entry in the wantlist.
class WantlistEntry extends $pb.GeneratedMessage {
  factory WantlistEntry({
    $core.List<$core.int>? block,
    $core.int? priority,
    $core.bool? cancel,
    WantType? wantType,
    $core.bool? sendDontHave,
  }) {
    final $result = create();
    if (block != null) {
      $result.block = block;
    }
    if (priority != null) {
      $result.priority = priority;
    }
    if (cancel != null) {
      $result.cancel = cancel;
    }
    if (wantType != null) {
      $result.wantType = wantType;
    }
    if (sendDontHave != null) {
      $result.sendDontHave = sendDontHave;
    }
    return $result;
  }
  WantlistEntry._() : super();
  factory WantlistEntry.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WantlistEntry.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WantlistEntry', package: const $pb.PackageName(_omitMessageNames ? '' : 'bitswap'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'block', $pb.PbFieldType.OY)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'priority', $pb.PbFieldType.O3)
    ..aOB(3, _omitFieldNames ? '' : 'cancel')
    ..e<WantType>(4, _omitFieldNames ? '' : 'wantType', $pb.PbFieldType.OE, protoName: 'wantType', defaultOrMaker: WantType.WANT_TYPE_UNSPECIFIED, valueOf: WantType.valueOf, enumValues: WantType.values)
    ..aOB(5, _omitFieldNames ? '' : 'sendDontHave', protoName: 'sendDontHave')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WantlistEntry clone() => WantlistEntry()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WantlistEntry copyWith(void Function(WantlistEntry) updates) => super.copyWith((message) => updates(message as WantlistEntry)) as WantlistEntry;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WantlistEntry create() => WantlistEntry._();
  WantlistEntry createEmptyInstance() => create();
  static $pb.PbList<WantlistEntry> createRepeated() => $pb.PbList<WantlistEntry>();
  @$core.pragma('dart2js:noInline')
  static WantlistEntry getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WantlistEntry>(create);
  static WantlistEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get block => $_getN(0);
  @$pb.TagNumber(1)
  set block($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBlock() => $_has(0);
  @$pb.TagNumber(1)
  void clearBlock() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get priority => $_getIZ(1);
  @$pb.TagNumber(2)
  set priority($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPriority() => $_has(1);
  @$pb.TagNumber(2)
  void clearPriority() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get cancel => $_getBF(2);
  @$pb.TagNumber(3)
  set cancel($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasCancel() => $_has(2);
  @$pb.TagNumber(3)
  void clearCancel() => clearField(3);

  @$pb.TagNumber(4)
  WantType get wantType => $_getN(3);
  @$pb.TagNumber(4)
  set wantType(WantType v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasWantType() => $_has(3);
  @$pb.TagNumber(4)
  void clearWantType() => clearField(4);

  @$pb.TagNumber(5)
  $core.bool get sendDontHave => $_getBF(4);
  @$pb.TagNumber(5)
  set sendDontHave($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSendDontHave() => $_has(4);
  @$pb.TagNumber(5)
  void clearSendDontHave() => clearField(5);
}

/// Represents a wantlist message.
class Wantlist extends $pb.GeneratedMessage {
  factory Wantlist({
    $core.Iterable<WantlistEntry>? entries,
    $core.bool? full,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    if (full != null) {
      $result.full = full;
    }
    return $result;
  }
  Wantlist._() : super();
  factory Wantlist.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Wantlist.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Wantlist', package: const $pb.PackageName(_omitMessageNames ? '' : 'bitswap'), createEmptyInstance: create)
    ..pc<WantlistEntry>(1, _omitFieldNames ? '' : 'entries', $pb.PbFieldType.PM, subBuilder: WantlistEntry.create)
    ..aOB(2, _omitFieldNames ? '' : 'full')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Wantlist clone() => Wantlist()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Wantlist copyWith(void Function(Wantlist) updates) => super.copyWith((message) => updates(message as Wantlist)) as Wantlist;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Wantlist create() => Wantlist._();
  Wantlist createEmptyInstance() => create();
  static $pb.PbList<Wantlist> createRepeated() => $pb.PbList<Wantlist>();
  @$core.pragma('dart2js:noInline')
  static Wantlist getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Wantlist>(create);
  static Wantlist? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<WantlistEntry> get entries => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get full => $_getBF(1);
  @$pb.TagNumber(2)
  set full($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasFull() => $_has(1);
  @$pb.TagNumber(2)
  void clearFull() => clearField(2);
}

/// Represents a block message.
class Block extends $pb.GeneratedMessage {
  factory Block({
    $core.List<$core.int>? prefix,
    $core.List<$core.int>? data,
  }) {
    final $result = create();
    if (prefix != null) {
      $result.prefix = prefix;
    }
    if (data != null) {
      $result.data = data;
    }
    return $result;
  }
  Block._() : super();
  factory Block.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Block.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Block', package: const $pb.PackageName(_omitMessageNames ? '' : 'bitswap'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'prefix', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Block clone() => Block()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Block copyWith(void Function(Block) updates) => super.copyWith((message) => updates(message as Block)) as Block;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Block create() => Block._();
  Block createEmptyInstance() => create();
  static $pb.PbList<Block> createRepeated() => $pb.PbList<Block>();
  @$core.pragma('dart2js:noInline')
  static Block getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Block>(create);
  static Block? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get prefix => $_getN(0);
  @$pb.TagNumber(1)
  set prefix($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPrefix() => $_has(0);
  @$pb.TagNumber(1)
  void clearPrefix() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => clearField(2);
}

/// Represents a block presence message.
class BlockPresence extends $pb.GeneratedMessage {
  factory BlockPresence({
    $core.List<$core.int>? cid,
    BlockPresence_Type? type,
  }) {
    final $result = create();
    if (cid != null) {
      $result.cid = cid;
    }
    if (type != null) {
      $result.type = type;
    }
    return $result;
  }
  BlockPresence._() : super();
  factory BlockPresence.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockPresence.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockPresence', package: const $pb.PackageName(_omitMessageNames ? '' : 'bitswap'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'cid', $pb.PbFieldType.OY)
    ..e<BlockPresence_Type>(2, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: BlockPresence_Type.HAVE, valueOf: BlockPresence_Type.valueOf, enumValues: BlockPresence_Type.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockPresence clone() => BlockPresence()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockPresence copyWith(void Function(BlockPresence) updates) => super.copyWith((message) => updates(message as BlockPresence)) as BlockPresence;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockPresence create() => BlockPresence._();
  BlockPresence createEmptyInstance() => create();
  static $pb.PbList<BlockPresence> createRepeated() => $pb.PbList<BlockPresence>();
  @$core.pragma('dart2js:noInline')
  static BlockPresence getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockPresence>(create);
  static BlockPresence? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get cid => $_getN(0);
  @$pb.TagNumber(1)
  set cid($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);

  @$pb.TagNumber(2)
  BlockPresence_Type get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(BlockPresence_Type v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => clearField(2);
}

/// The main Bitswap Message structure.
class Message extends $pb.GeneratedMessage {
  factory Message({
    Wantlist? wantlist,
    $core.Iterable<Block>? blocks,
    $core.Iterable<BlockPresence>? blockPresences,
  }) {
    final $result = create();
    if (wantlist != null) {
      $result.wantlist = wantlist;
    }
    if (blocks != null) {
      $result.blocks.addAll(blocks);
    }
    if (blockPresences != null) {
      $result.blockPresences.addAll(blockPresences);
    }
    return $result;
  }
  Message._() : super();
  factory Message.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Message.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Message', package: const $pb.PackageName(_omitMessageNames ? '' : 'bitswap'), createEmptyInstance: create)
    ..aOM<Wantlist>(1, _omitFieldNames ? '' : 'wantlist', subBuilder: Wantlist.create)
    ..pc<Block>(2, _omitFieldNames ? '' : 'blocks', $pb.PbFieldType.PM, subBuilder: Block.create)
    ..pc<BlockPresence>(3, _omitFieldNames ? '' : 'blockPresences', $pb.PbFieldType.PM, protoName: 'blockPresences', subBuilder: BlockPresence.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Message clone() => Message()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Message copyWith(void Function(Message) updates) => super.copyWith((message) => updates(message as Message)) as Message;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Message create() => Message._();
  Message createEmptyInstance() => create();
  static $pb.PbList<Message> createRepeated() => $pb.PbList<Message>();
  @$core.pragma('dart2js:noInline')
  static Message getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Message>(create);
  static Message? _defaultInstance;

  @$pb.TagNumber(1)
  Wantlist get wantlist => $_getN(0);
  @$pb.TagNumber(1)
  set wantlist(Wantlist v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasWantlist() => $_has(0);
  @$pb.TagNumber(1)
  void clearWantlist() => clearField(1);
  @$pb.TagNumber(1)
  Wantlist ensureWantlist() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.List<Block> get blocks => $_getList(1);

  @$pb.TagNumber(3)
  $core.List<BlockPresence> get blockPresences => $_getList(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
