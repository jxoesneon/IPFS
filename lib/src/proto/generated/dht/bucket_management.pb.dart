// This is a generated file - do not edit.
//
// Generated from dht/bucket_management.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class SplitBucketRequest extends $pb.GeneratedMessage {
  factory SplitBucketRequest({
    $core.int? bucketIndex,
  }) {
    final result = create();
    if (bucketIndex != null) result.bucketIndex = bucketIndex;
    return result;
  }

  SplitBucketRequest._();

  factory SplitBucketRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SplitBucketRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SplitBucketRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.bucket_management'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'bucketIndex')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SplitBucketRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SplitBucketRequest copyWith(void Function(SplitBucketRequest) updates) =>
      super.copyWith((message) => updates(message as SplitBucketRequest)) as SplitBucketRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SplitBucketRequest create() => SplitBucketRequest._();
  @$core.override
  SplitBucketRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SplitBucketRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SplitBucketRequest>(create);
  static SplitBucketRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get bucketIndex => $_getIZ(0);
  @$pb.TagNumber(1)
  set bucketIndex($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBucketIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearBucketIndex() => $_clearField(1);
}

class SplitBucketResponse extends $pb.GeneratedMessage {
  factory SplitBucketResponse({
    $core.bool? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  SplitBucketResponse._();

  factory SplitBucketResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SplitBucketResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SplitBucketResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.bucket_management'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SplitBucketResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SplitBucketResponse copyWith(void Function(SplitBucketResponse) updates) =>
      super.copyWith((message) => updates(message as SplitBucketResponse)) as SplitBucketResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SplitBucketResponse create() => SplitBucketResponse._();
  @$core.override
  SplitBucketResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SplitBucketResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SplitBucketResponse>(create);
  static SplitBucketResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
}

class MergeBucketsRequest extends $pb.GeneratedMessage {
  factory MergeBucketsRequest({
    $core.int? bucketIndex1,
    $core.int? bucketIndex2,
  }) {
    final result = create();
    if (bucketIndex1 != null) result.bucketIndex1 = bucketIndex1;
    if (bucketIndex2 != null) result.bucketIndex2 = bucketIndex2;
    return result;
  }

  MergeBucketsRequest._();

  factory MergeBucketsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MergeBucketsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MergeBucketsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.bucket_management'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'bucketIndex1', protoName: 'bucket_index_1')
    ..aI(2, _omitFieldNames ? '' : 'bucketIndex2', protoName: 'bucket_index_2')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergeBucketsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergeBucketsRequest copyWith(void Function(MergeBucketsRequest) updates) =>
      super.copyWith((message) => updates(message as MergeBucketsRequest)) as MergeBucketsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MergeBucketsRequest create() => MergeBucketsRequest._();
  @$core.override
  MergeBucketsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MergeBucketsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MergeBucketsRequest>(create);
  static MergeBucketsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get bucketIndex1 => $_getIZ(0);
  @$pb.TagNumber(1)
  set bucketIndex1($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBucketIndex1() => $_has(0);
  @$pb.TagNumber(1)
  void clearBucketIndex1() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get bucketIndex2 => $_getIZ(1);
  @$pb.TagNumber(2)
  set bucketIndex2($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBucketIndex2() => $_has(1);
  @$pb.TagNumber(2)
  void clearBucketIndex2() => $_clearField(2);
}

class MergeBucketsResponse extends $pb.GeneratedMessage {
  factory MergeBucketsResponse({
    $core.bool? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  MergeBucketsResponse._();

  factory MergeBucketsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MergeBucketsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MergeBucketsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.bucket_management'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergeBucketsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergeBucketsResponse copyWith(void Function(MergeBucketsResponse) updates) =>
      super.copyWith((message) => updates(message as MergeBucketsResponse)) as MergeBucketsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MergeBucketsResponse create() => MergeBucketsResponse._();
  @$core.override
  MergeBucketsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MergeBucketsResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MergeBucketsResponse>(create);
  static MergeBucketsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
}

const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
