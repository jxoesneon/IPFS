//
//  Generated code. Do not modify.
//  source: ipns.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'ipns.pbenum.dart';

export 'ipns.pbenum.dart';

class IpnsEntry extends $pb.GeneratedMessage {
  factory IpnsEntry({
    $core.List<$core.int>? value,
    $core.List<$core.int>? signature,
    IpnsEntry_ValidityType? validityType,
    $core.List<$core.int>? validity,
    $fixnum.Int64? sequence,
    $fixnum.Int64? ttl,
    $core.List<$core.int>? pubKey,
  }) {
    final $result = create();
    if (value != null) {
      $result.value = value;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (validityType != null) {
      $result.validityType = validityType;
    }
    if (validity != null) {
      $result.validity = validity;
    }
    if (sequence != null) {
      $result.sequence = sequence;
    }
    if (ttl != null) {
      $result.ttl = ttl;
    }
    if (pubKey != null) {
      $result.pubKey = pubKey;
    }
    return $result;
  }
  IpnsEntry._() : super();
  factory IpnsEntry.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory IpnsEntry.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IpnsEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.ipns'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..e<IpnsEntry_ValidityType>(
        3, _omitFieldNames ? '' : 'validityType', $pb.PbFieldType.OE,
        protoName: 'validityType',
        defaultOrMaker: IpnsEntry_ValidityType.EOL,
        valueOf: IpnsEntry_ValidityType.valueOf,
        enumValues: IpnsEntry_ValidityType.values)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'validity', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'sequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(6, _omitFieldNames ? '' : 'ttl', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'pubKey', $pb.PbFieldType.OY,
        protoName: 'pubKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  IpnsEntry clone() => IpnsEntry()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  IpnsEntry copyWith(void Function(IpnsEntry) updates) =>
      super.copyWith((message) => updates(message as IpnsEntry)) as IpnsEntry;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IpnsEntry create() => IpnsEntry._();
  IpnsEntry createEmptyInstance() => create();
  static $pb.PbList<IpnsEntry> createRepeated() => $pb.PbList<IpnsEntry>();
  @$core.pragma('dart2js:noInline')
  static IpnsEntry getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IpnsEntry>(create);
  static IpnsEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get value => $_getN(0);
  @$pb.TagNumber(1)
  set value($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  IpnsEntry_ValidityType get validityType => $_getN(2);
  @$pb.TagNumber(3)
  set validityType(IpnsEntry_ValidityType v) {
    setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasValidityType() => $_has(2);
  @$pb.TagNumber(3)
  void clearValidityType() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get validity => $_getN(3);
  @$pb.TagNumber(4)
  set validity($core.List<$core.int> v) {
    $_setBytes(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasValidity() => $_has(3);
  @$pb.TagNumber(4)
  void clearValidity() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get sequence => $_getI64(4);
  @$pb.TagNumber(5)
  set sequence($fixnum.Int64 v) {
    $_setInt64(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasSequence() => $_has(4);
  @$pb.TagNumber(5)
  void clearSequence() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get ttl => $_getI64(5);
  @$pb.TagNumber(6)
  set ttl($fixnum.Int64 v) {
    $_setInt64(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasTtl() => $_has(5);
  @$pb.TagNumber(6)
  void clearTtl() => clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get pubKey => $_getN(6);
  @$pb.TagNumber(7)
  set pubKey($core.List<$core.int> v) {
    $_setBytes(6, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasPubKey() => $_has(6);
  @$pb.TagNumber(7)
  void clearPubKey() => clearField(7);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
