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

class Message_Wantlist_Entry extends $pb.GeneratedMessage {
  factory Message_Wantlist_Entry({
    $core.List<$core.int>? block,
    $core.int? priority,
    $core.bool? cancel,
    Message_Wantlist_WantType? wantType,
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
  Message_Wantlist_Entry._() : super();
  factory Message_Wantlist_Entry.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Message_Wantlist_Entry.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Message.Wantlist.Entry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.bitswap'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'block', $pb.PbFieldType.OY)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'priority', $pb.PbFieldType.O3)
    ..aOB(3, _omitFieldNames ? '' : 'cancel')
    ..e<Message_Wantlist_WantType>(
        4, _omitFieldNames ? '' : 'wantType', $pb.PbFieldType.OE,
        protoName: 'wantType',
        defaultOrMaker: Message_Wantlist_WantType.Block,
        valueOf: Message_Wantlist_WantType.valueOf,
        enumValues: Message_Wantlist_WantType.values)
    ..aOB(5, _omitFieldNames ? '' : 'sendDontHave', protoName: 'sendDontHave')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Message_Wantlist_Entry clone() =>
      Message_Wantlist_Entry()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Message_Wantlist_Entry copyWith(
          void Function(Message_Wantlist_Entry) updates) =>
      super.copyWith((message) => updates(message as Message_Wantlist_Entry))
          as Message_Wantlist_Entry;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Message_Wantlist_Entry create() => Message_Wantlist_Entry._();
  Message_Wantlist_Entry createEmptyInstance() => create();
  static $pb.PbList<Message_Wantlist_Entry> createRepeated() =>
      $pb.PbList<Message_Wantlist_Entry>();
  @$core.pragma('dart2js:noInline')
  static Message_Wantlist_Entry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Message_Wantlist_Entry>(create);
  static Message_Wantlist_Entry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get block => $_getN(0);
  @$pb.TagNumber(1)
  set block($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasBlock() => $_has(0);
  @$pb.TagNumber(1)
  void clearBlock() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get priority => $_getIZ(1);
  @$pb.TagNumber(2)
  set priority($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasPriority() => $_has(1);
  @$pb.TagNumber(2)
  void clearPriority() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get cancel => $_getBF(2);
  @$pb.TagNumber(3)
  set cancel($core.bool v) {
    $_setBool(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasCancel() => $_has(2);
  @$pb.TagNumber(3)
  void clearCancel() => clearField(3);

  @$pb.TagNumber(4)
  Message_Wantlist_WantType get wantType => $_getN(3);
  @$pb.TagNumber(4)
  set wantType(Message_Wantlist_WantType v) {
    setField(4, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasWantType() => $_has(3);
  @$pb.TagNumber(4)
  void clearWantType() => clearField(4);

  @$pb.TagNumber(5)
  $core.bool get sendDontHave => $_getBF(4);
  @$pb.TagNumber(5)
  set sendDontHave($core.bool v) {
    $_setBool(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasSendDontHave() => $_has(4);
  @$pb.TagNumber(5)
  void clearSendDontHave() => clearField(5);
}

class Message_Wantlist extends $pb.GeneratedMessage {
  factory Message_Wantlist({
    $core.Iterable<Message_Wantlist_Entry>? entries,
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
  Message_Wantlist._() : super();
  factory Message_Wantlist.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Message_Wantlist.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Message.Wantlist',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.bitswap'),
      createEmptyInstance: create)
    ..pc<Message_Wantlist_Entry>(
        1, _omitFieldNames ? '' : 'entries', $pb.PbFieldType.PM,
        subBuilder: Message_Wantlist_Entry.create)
    ..aOB(2, _omitFieldNames ? '' : 'full')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Message_Wantlist clone() => Message_Wantlist()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Message_Wantlist copyWith(void Function(Message_Wantlist) updates) =>
      super.copyWith((message) => updates(message as Message_Wantlist))
          as Message_Wantlist;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Message_Wantlist create() => Message_Wantlist._();
  Message_Wantlist createEmptyInstance() => create();
  static $pb.PbList<Message_Wantlist> createRepeated() =>
      $pb.PbList<Message_Wantlist>();
  @$core.pragma('dart2js:noInline')
  static Message_Wantlist getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Message_Wantlist>(create);
  static Message_Wantlist? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<Message_Wantlist_Entry> get entries => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get full => $_getBF(1);
  @$pb.TagNumber(2)
  set full($core.bool v) {
    $_setBool(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasFull() => $_has(1);
  @$pb.TagNumber(2)
  void clearFull() => clearField(2);
}

class Message_Block extends $pb.GeneratedMessage {
  factory Message_Block({
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
  Message_Block._() : super();
  factory Message_Block.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Message_Block.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Message.Block',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.bitswap'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'prefix', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Message_Block clone() => Message_Block()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Message_Block copyWith(void Function(Message_Block) updates) =>
      super.copyWith((message) => updates(message as Message_Block))
          as Message_Block;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Message_Block create() => Message_Block._();
  Message_Block createEmptyInstance() => create();
  static $pb.PbList<Message_Block> createRepeated() =>
      $pb.PbList<Message_Block>();
  @$core.pragma('dart2js:noInline')
  static Message_Block getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Message_Block>(create);
  static Message_Block? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get prefix => $_getN(0);
  @$pb.TagNumber(1)
  set prefix($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPrefix() => $_has(0);
  @$pb.TagNumber(1)
  void clearPrefix() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => clearField(2);
}

class Message_BlockPresence extends $pb.GeneratedMessage {
  factory Message_BlockPresence({
    $core.List<$core.int>? cid,
    Message_BlockPresence_Type? type,
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
  Message_BlockPresence._() : super();
  factory Message_BlockPresence.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Message_BlockPresence.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Message.BlockPresence',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.bitswap'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'cid', $pb.PbFieldType.OY)
    ..e<Message_BlockPresence_Type>(
        2, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE,
        defaultOrMaker: Message_BlockPresence_Type.Have,
        valueOf: Message_BlockPresence_Type.valueOf,
        enumValues: Message_BlockPresence_Type.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Message_BlockPresence clone() =>
      Message_BlockPresence()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Message_BlockPresence copyWith(
          void Function(Message_BlockPresence) updates) =>
      super.copyWith((message) => updates(message as Message_BlockPresence))
          as Message_BlockPresence;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Message_BlockPresence create() => Message_BlockPresence._();
  Message_BlockPresence createEmptyInstance() => create();
  static $pb.PbList<Message_BlockPresence> createRepeated() =>
      $pb.PbList<Message_BlockPresence>();
  @$core.pragma('dart2js:noInline')
  static Message_BlockPresence getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Message_BlockPresence>(create);
  static Message_BlockPresence? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get cid => $_getN(0);
  @$pb.TagNumber(1)
  set cid($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);

  @$pb.TagNumber(2)
  Message_BlockPresence_Type get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(Message_BlockPresence_Type v) {
    setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => clearField(2);
}

class Message extends $pb.GeneratedMessage {
  factory Message({
    Message_Wantlist? wantlist,
    $core.Iterable<$core.List<$core.int>>? blocks,
    $core.Iterable<Message_Block>? payload,
    $core.Iterable<Message_BlockPresence>? blockPresences,
    $core.int? pendingBytes,
  }) {
    final $result = create();
    if (wantlist != null) {
      $result.wantlist = wantlist;
    }
    if (blocks != null) {
      $result.blocks.addAll(blocks);
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
  factory Message.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Message.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Message',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.bitswap'),
      createEmptyInstance: create)
    ..aOM<Message_Wantlist>(1, _omitFieldNames ? '' : 'wantlist',
        subBuilder: Message_Wantlist.create)
    ..p<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'blocks', $pb.PbFieldType.PY)
    ..pc<Message_Block>(3, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.PM,
        subBuilder: Message_Block.create)
    ..pc<Message_BlockPresence>(
        4, _omitFieldNames ? '' : 'blockPresences', $pb.PbFieldType.PM,
        protoName: 'blockPresences', subBuilder: Message_BlockPresence.create)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'pendingBytes', $pb.PbFieldType.O3,
        protoName: 'pendingBytes')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Message clone() => Message()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Message copyWith(void Function(Message) updates) =>
      super.copyWith((message) => updates(message as Message)) as Message;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Message create() => Message._();
  Message createEmptyInstance() => create();
  static $pb.PbList<Message> createRepeated() => $pb.PbList<Message>();
  @$core.pragma('dart2js:noInline')
  static Message getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Message>(create);
  static Message? _defaultInstance;

  @$pb.TagNumber(1)
  Message_Wantlist get wantlist => $_getN(0);
  @$pb.TagNumber(1)
  set wantlist(Message_Wantlist v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasWantlist() => $_has(0);
  @$pb.TagNumber(1)
  void clearWantlist() => clearField(1);
  @$pb.TagNumber(1)
  Message_Wantlist ensureWantlist() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.List<$core.List<$core.int>> get blocks => $_getList(1);

  @$pb.TagNumber(3)
  $core.List<Message_Block> get payload => $_getList(2);

  @$pb.TagNumber(4)
  $core.List<Message_BlockPresence> get blockPresences => $_getList(3);

  @$pb.TagNumber(5)
  $core.int get pendingBytes => $_getIZ(4);
  @$pb.TagNumber(5)
  set pendingBytes($core.int v) {
    $_setSignedInt32(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasPendingBytes() => $_has(4);
  @$pb.TagNumber(5)
  void clearPendingBytes() => clearField(5);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
