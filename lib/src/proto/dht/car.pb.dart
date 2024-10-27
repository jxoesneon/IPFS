//
//  Generated code. Do not modify.
//  source: car.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'block.pb.dart' as $0;

/// Represents a Content Addressable Archive (CAR).
class CarProto extends $pb.GeneratedMessage {
  factory CarProto({
    $core.Iterable<$0.BlockProto>? blocks,
  }) {
    final $result = create();
    if (blocks != null) {
      $result.blocks.addAll(blocks);
    }
    return $result;
  }
  CarProto._() : super();
  factory CarProto.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CarProto.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CarProto', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.core.data_structures'), createEmptyInstance: create)
    ..pc<$0.BlockProto>(1, _omitFieldNames ? '' : 'blocks', $pb.PbFieldType.PM, subBuilder: $0.BlockProto.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CarProto clone() => CarProto()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CarProto copyWith(void Function(CarProto) updates) => super.copyWith((message) => updates(message as CarProto)) as CarProto;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CarProto create() => CarProto._();
  CarProto createEmptyInstance() => create();
  static $pb.PbList<CarProto> createRepeated() => $pb.PbList<CarProto>();
  @$core.pragma('dart2js:noInline')
  static CarProto getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CarProto>(create);
  static CarProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$0.BlockProto> get blocks => $_getList(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
