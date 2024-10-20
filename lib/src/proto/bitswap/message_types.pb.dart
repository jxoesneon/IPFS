//
//  Generated code. Do not modify.
//  source: lib/src/proto/bitswap/message_types.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'message_types.pbenum.dart';

export 'message_types.pbenum.dart';

class Wantlist_Entry extends $pb.GeneratedMessage {
  factory Wantlist_Entry({
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
  Wantlist_Entry._() : super();
  factory Wantlist_Entry.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Wantlist_Entry.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Wantlist.Entry', package: const $pb.PackageName(_omitMessageNames ? '' : 'bitswap'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'block', $pb.PbFieldType.OY)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'priority', $pb.PbFieldType.O3)
    ..aOB(3, _omitFieldNames ? '' : 'cancel')
    ..e<WantType>(4, _omitFieldNames ? '' : 'wantType', $pb.PbFieldType.OE, protoName: 'wantType', defaultOrMaker: WantType.WANT_TYPE_BLOCK, valueOf: WantType.valueOf, enumValues: WantType.values)
    ..aOB(5, _omitFieldNames ? '' : 'sendDontHave', protoName: 'sendDontHave')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Wantlist_Entry clone() => Wantlist_Entry()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Wantlist_Entry copyWith(void Function(Wantlist_Entry) updates) => super.copyWith((message) => updates(message as Wantlist_Entry)) as Wantlist_Entry;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Wantlist_Entry create() => Wantlist_Entry._();
  Wantlist_Entry createEmptyInstance() => create();
  static $pb.PbList<Wantlist_Entry> createRepeated() => $pb.PbList<Wantlist_Entry>();
  @$core.pragma('dart2js:noInline')
  static Wantlist_Entry getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Wantlist_Entry>(create);
  static Wantlist_Entry? _defaultInstance;

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

/// Define Wantlist message
class Wantlist extends $pb.GeneratedMessage {
  factory Wantlist({
    $core.Iterable<Wantlist_Entry>? entries,
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
    ..pc<Wantlist_Entry>(1, _omitFieldNames ? '' : 'entries', $pb.PbFieldType.PM, subBuilder: Wantlist_Entry.create)
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
  $core.List<Wantlist_Entry> get entries => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get full => $_getBF(1);
  @$pb.TagNumber(2)
  set full($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasFull() => $_has(1);
  @$pb.TagNumber(2)
  void clearFull() => clearField(2);
}

/// Define Block message
class BlockMsg extends $pb.GeneratedMessage {
  factory BlockMsg({
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
  BlockMsg._() : super();
  factory BlockMsg.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockMsg.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockMsg', package: const $pb.PackageName(_omitMessageNames ? '' : 'bitswap'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'prefix', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockMsg clone() => BlockMsg()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockMsg copyWith(void Function(BlockMsg) updates) => super.copyWith((message) => updates(message as BlockMsg)) as BlockMsg;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockMsg create() => BlockMsg._();
  BlockMsg createEmptyInstance() => create();
  static $pb.PbList<BlockMsg> createRepeated() => $pb.PbList<BlockMsg>();
  @$core.pragma('dart2js:noInline')
  static BlockMsg getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockMsg>(create);
  static BlockMsg? _defaultInstance;

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

/// Define BlockPresence message
class BlockPresence extends $pb.GeneratedMessage {
  factory BlockPresence({
    $core.List<$core.int>? cid,
    BlockPresenceType? type,
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
    ..e<BlockPresenceType>(2, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: BlockPresenceType.BLOCK_PRESENCE_HAVE, valueOf: BlockPresenceType.valueOf, enumValues: BlockPresenceType.values)
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
  BlockPresenceType get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(BlockPresenceType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => clearField(2);
}

/// Define the main Bitswap Message structure
class Message extends $pb.GeneratedMessage {
  factory Message({
    Wantlist? wantlist,
    $core.Iterable<BlockMsg>? payload,
    $core.Iterable<BlockPresence>? blockPresences,
    $core.int? pendingBytes,
  }) {
    final $result = create();
    if (wantlist != null) {
      $result.wantlist = wantlist;
    }
    if (payload != null) {
      $result.payload.addAll(payload);
    }
    if (blockPresences != null) {
      $result.blockPresences.addAll(blockPresences);
    }
    if (pendingBytes != null) {
      $result.pendingBytes = pendingBytes;
    }
    return $result;
  }
  Message._() : super();
  factory Message.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Message.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Message', package: const $pb.PackageName(_omitMessageNames ? '' : 'bitswap'), createEmptyInstance: create)
    ..aOM<Wantlist>(1, _omitFieldNames ? '' : 'wantlist', subBuilder: Wantlist.create)
    ..pc<BlockMsg>(3, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.PM, subBuilder: BlockMsg.create)
    ..pc<BlockPresence>(4, _omitFieldNames ? '' : 'blockPresences', $pb.PbFieldType.PM, protoName: 'blockPresences', subBuilder: BlockPresence.create)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'pendingBytes', $pb.PbFieldType.O3, protoName: 'pendingBytes')
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

  @$pb.TagNumber(3)
  $core.List<BlockMsg> get payload => $_getList(1);

  @$pb.TagNumber(4)
  $core.List<BlockPresence> get blockPresences => $_getList(2);

  @$pb.TagNumber(5)
  $core.int get pendingBytes => $_getIZ(3);
  @$pb.TagNumber(5)
  set pendingBytes($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(5)
  $core.bool hasPendingBytes() => $_has(3);
  @$pb.TagNumber(5)
  void clearPendingBytes() => clearField(5);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
