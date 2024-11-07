//
//  Generated code. Do not modify.
//  source: bitswap_messages.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'bitswap_messages.pbenum.dart';

export 'bitswap_messages.pbenum.dart';

class BitSwapMessage extends $pb.GeneratedMessage {
  factory BitSwapMessage({
    $core.String? messageId,
    BitSwapMessage_MessageType? type,
    $core.Iterable<WantList>? wantList,
    $core.Iterable<Block>? blocks,
  }) {
    final $result = create();
    if (messageId != null) {
      $result.messageId = messageId;
    }
    if (type != null) {
      $result.type = type;
    }
    if (wantList != null) {
      $result.wantList.addAll(wantList);
    }
    if (blocks != null) {
      $result.blocks.addAll(blocks);
    }
    return $result;
  }
  BitSwapMessage._() : super();
  factory BitSwapMessage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BitSwapMessage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BitSwapMessage', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.bitswap'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..e<BitSwapMessage_MessageType>(2, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: BitSwapMessage_MessageType.UNKNOWN, valueOf: BitSwapMessage_MessageType.valueOf, enumValues: BitSwapMessage_MessageType.values)
    ..pc<WantList>(3, _omitFieldNames ? '' : 'wantList', $pb.PbFieldType.PM, subBuilder: WantList.create)
    ..pc<Block>(4, _omitFieldNames ? '' : 'blocks', $pb.PbFieldType.PM, subBuilder: Block.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BitSwapMessage clone() => BitSwapMessage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BitSwapMessage copyWith(void Function(BitSwapMessage) updates) => super.copyWith((message) => updates(message as BitSwapMessage)) as BitSwapMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BitSwapMessage create() => BitSwapMessage._();
  BitSwapMessage createEmptyInstance() => create();
  static $pb.PbList<BitSwapMessage> createRepeated() => $pb.PbList<BitSwapMessage>();
  @$core.pragma('dart2js:noInline')
  static BitSwapMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BitSwapMessage>(create);
  static BitSwapMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => clearField(1);

  @$pb.TagNumber(2)
  BitSwapMessage_MessageType get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(BitSwapMessage_MessageType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<WantList> get wantList => $_getList(2);

  @$pb.TagNumber(4)
  $core.List<Block> get blocks => $_getList(3);
}

class WantList extends $pb.GeneratedMessage {
  factory WantList({
    $core.List<$core.int>? cid,
    $core.bool? wantBlock,
    $core.int? priority,
  }) {
    final $result = create();
    if (cid != null) {
      $result.cid = cid;
    }
    if (wantBlock != null) {
      $result.wantBlock = wantBlock;
    }
    if (priority != null) {
      $result.priority = priority;
    }
    return $result;
  }
  WantList._() : super();
  factory WantList.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WantList.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WantList', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.bitswap'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'cid', $pb.PbFieldType.OY)
    ..aOB(2, _omitFieldNames ? '' : 'wantBlock')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'priority', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WantList clone() => WantList()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WantList copyWith(void Function(WantList) updates) => super.copyWith((message) => updates(message as WantList)) as WantList;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WantList create() => WantList._();
  WantList createEmptyInstance() => create();
  static $pb.PbList<WantList> createRepeated() => $pb.PbList<WantList>();
  @$core.pragma('dart2js:noInline')
  static WantList getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WantList>(create);
  static WantList? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get cid => $_getN(0);
  @$pb.TagNumber(1)
  set cid($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get wantBlock => $_getBF(1);
  @$pb.TagNumber(2)
  set wantBlock($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasWantBlock() => $_has(1);
  @$pb.TagNumber(2)
  void clearWantBlock() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get priority => $_getIZ(2);
  @$pb.TagNumber(3)
  set priority($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPriority() => $_has(2);
  @$pb.TagNumber(3)
  void clearPriority() => clearField(3);
}

class Block extends $pb.GeneratedMessage {
  factory Block({
    $core.List<$core.int>? cid,
    $core.List<$core.int>? data,
  }) {
    final $result = create();
    if (cid != null) {
      $result.cid = cid;
    }
    if (data != null) {
      $result.data = data;
    }
    return $result;
  }
  Block._() : super();
  factory Block.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Block.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Block', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.bitswap'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'cid', $pb.PbFieldType.OY)
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
  $core.List<$core.int> get cid => $_getN(0);
  @$pb.TagNumber(1)
  set cid($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCid() => $_has(0);
  @$pb.TagNumber(1)
  void clearCid() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => clearField(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
