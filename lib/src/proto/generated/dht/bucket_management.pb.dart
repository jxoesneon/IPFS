//
//  Generated code. Do not modify.
//  source: dht/bucket_management.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class SplitBucketRequest extends $pb.GeneratedMessage {
  factory SplitBucketRequest({
    $core.int? bucketIndex,
  }) {
    final $result = create();
    if (bucketIndex != null) {
      $result.bucketIndex = bucketIndex;
    }
    return $result;
  }
  SplitBucketRequest._() : super();
  factory SplitBucketRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SplitBucketRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SplitBucketRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.bucket_management'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'bucketIndex', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SplitBucketRequest clone() => SplitBucketRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SplitBucketRequest copyWith(void Function(SplitBucketRequest) updates) => super.copyWith((message) => updates(message as SplitBucketRequest)) as SplitBucketRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SplitBucketRequest create() => SplitBucketRequest._();
  SplitBucketRequest createEmptyInstance() => create();
  static $pb.PbList<SplitBucketRequest> createRepeated() => $pb.PbList<SplitBucketRequest>();
  @$core.pragma('dart2js:noInline')
  static SplitBucketRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SplitBucketRequest>(create);
  static SplitBucketRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get bucketIndex => $_getIZ(0);
  @$pb.TagNumber(1)
  set bucketIndex($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBucketIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearBucketIndex() => clearField(1);
}

class SplitBucketResponse extends $pb.GeneratedMessage {
  factory SplitBucketResponse({
    $core.bool? success,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  SplitBucketResponse._() : super();
  factory SplitBucketResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SplitBucketResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SplitBucketResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.bucket_management'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SplitBucketResponse clone() => SplitBucketResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SplitBucketResponse copyWith(void Function(SplitBucketResponse) updates) => super.copyWith((message) => updates(message as SplitBucketResponse)) as SplitBucketResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SplitBucketResponse create() => SplitBucketResponse._();
  SplitBucketResponse createEmptyInstance() => create();
  static $pb.PbList<SplitBucketResponse> createRepeated() => $pb.PbList<SplitBucketResponse>();
  @$core.pragma('dart2js:noInline')
  static SplitBucketResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SplitBucketResponse>(create);
  static SplitBucketResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);
}

class MergeBucketsRequest extends $pb.GeneratedMessage {
  factory MergeBucketsRequest({
    $core.int? bucketIndex1,
    $core.int? bucketIndex2,
  }) {
    final $result = create();
    if (bucketIndex1 != null) {
      $result.bucketIndex1 = bucketIndex1;
    }
    if (bucketIndex2 != null) {
      $result.bucketIndex2 = bucketIndex2;
    }
    return $result;
  }
  MergeBucketsRequest._() : super();
  factory MergeBucketsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MergeBucketsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MergeBucketsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.bucket_management'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'bucketIndex1', $pb.PbFieldType.O3, protoName: 'bucket_index_1')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'bucketIndex2', $pb.PbFieldType.O3, protoName: 'bucket_index_2')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MergeBucketsRequest clone() => MergeBucketsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MergeBucketsRequest copyWith(void Function(MergeBucketsRequest) updates) => super.copyWith((message) => updates(message as MergeBucketsRequest)) as MergeBucketsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MergeBucketsRequest create() => MergeBucketsRequest._();
  MergeBucketsRequest createEmptyInstance() => create();
  static $pb.PbList<MergeBucketsRequest> createRepeated() => $pb.PbList<MergeBucketsRequest>();
  @$core.pragma('dart2js:noInline')
  static MergeBucketsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MergeBucketsRequest>(create);
  static MergeBucketsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get bucketIndex1 => $_getIZ(0);
  @$pb.TagNumber(1)
  set bucketIndex1($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBucketIndex1() => $_has(0);
  @$pb.TagNumber(1)
  void clearBucketIndex1() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get bucketIndex2 => $_getIZ(1);
  @$pb.TagNumber(2)
  set bucketIndex2($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasBucketIndex2() => $_has(1);
  @$pb.TagNumber(2)
  void clearBucketIndex2() => clearField(2);
}

class MergeBucketsResponse extends $pb.GeneratedMessage {
  factory MergeBucketsResponse({
    $core.bool? success,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  MergeBucketsResponse._() : super();
  factory MergeBucketsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MergeBucketsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MergeBucketsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.bucket_management'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MergeBucketsResponse clone() => MergeBucketsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MergeBucketsResponse copyWith(void Function(MergeBucketsResponse) updates) => super.copyWith((message) => updates(message as MergeBucketsResponse)) as MergeBucketsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MergeBucketsResponse create() => MergeBucketsResponse._();
  MergeBucketsResponse createEmptyInstance() => create();
  static $pb.PbList<MergeBucketsResponse> createRepeated() => $pb.PbList<MergeBucketsResponse>();
  @$core.pragma('dart2js:noInline')
  static MergeBucketsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MergeBucketsResponse>(create);
  static MergeBucketsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
