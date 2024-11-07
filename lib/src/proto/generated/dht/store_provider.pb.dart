//
//  Generated code. Do not modify.
//  source: dht/store_provider.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'common_red_black_tree.pb.dart' as $5;
import 'store_provider.pbenum.dart';

export 'store_provider.pbenum.dart';

/// Request message for storing provider information
class StoreProviderRequest extends $pb.GeneratedMessage {
  factory StoreProviderRequest({
    $5.K_PeerId? key,
    $5.V_PeerInfo? providerInfo,
    $fixnum.Int64? ttl,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (providerInfo != null) {
      $result.providerInfo = providerInfo;
    }
    if (ttl != null) {
      $result.ttl = ttl;
    }
    return $result;
  }
  StoreProviderRequest._() : super();
  factory StoreProviderRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory StoreProviderRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'StoreProviderRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.store_provider'), createEmptyInstance: create)
    ..aOM<$5.K_PeerId>(1, _omitFieldNames ? '' : 'key', subBuilder: $5.K_PeerId.create)
    ..aOM<$5.V_PeerInfo>(2, _omitFieldNames ? '' : 'providerInfo', subBuilder: $5.V_PeerInfo.create)
    ..aInt64(3, _omitFieldNames ? '' : 'ttl')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  StoreProviderRequest clone() => StoreProviderRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  StoreProviderRequest copyWith(void Function(StoreProviderRequest) updates) => super.copyWith((message) => updates(message as StoreProviderRequest)) as StoreProviderRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StoreProviderRequest create() => StoreProviderRequest._();
  StoreProviderRequest createEmptyInstance() => create();
  static $pb.PbList<StoreProviderRequest> createRepeated() => $pb.PbList<StoreProviderRequest>();
  @$core.pragma('dart2js:noInline')
  static StoreProviderRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StoreProviderRequest>(create);
  static StoreProviderRequest? _defaultInstance;

  /// The key for which provider information is being stored
  @$pb.TagNumber(1)
  $5.K_PeerId get key => $_getN(0);
  @$pb.TagNumber(1)
  set key($5.K_PeerId v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);
  @$pb.TagNumber(1)
  $5.K_PeerId ensureKey() => $_ensure(0);

  /// The provider information to store
  @$pb.TagNumber(2)
  $5.V_PeerInfo get providerInfo => $_getN(1);
  @$pb.TagNumber(2)
  set providerInfo($5.V_PeerInfo v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasProviderInfo() => $_has(1);
  @$pb.TagNumber(2)
  void clearProviderInfo() => clearField(2);
  @$pb.TagNumber(2)
  $5.V_PeerInfo ensureProviderInfo() => $_ensure(1);

  /// Time-to-live in seconds for this provider record
  @$pb.TagNumber(3)
  $fixnum.Int64 get ttl => $_getI64(2);
  @$pb.TagNumber(3)
  set ttl($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTtl() => $_has(2);
  @$pb.TagNumber(3)
  void clearTtl() => clearField(3);
}

/// Response message for store provider operation
class StoreProviderResponse extends $pb.GeneratedMessage {
  factory StoreProviderResponse({
    StoreProviderResponse_Status? status,
    $core.String? errorMessage,
    $core.int? replicationCount,
  }) {
    final $result = create();
    if (status != null) {
      $result.status = status;
    }
    if (errorMessage != null) {
      $result.errorMessage = errorMessage;
    }
    if (replicationCount != null) {
      $result.replicationCount = replicationCount;
    }
    return $result;
  }
  StoreProviderResponse._() : super();
  factory StoreProviderResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory StoreProviderResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'StoreProviderResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.store_provider'), createEmptyInstance: create)
    ..e<StoreProviderResponse_Status>(1, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OE, defaultOrMaker: StoreProviderResponse_Status.SUCCESS, valueOf: StoreProviderResponse_Status.valueOf, enumValues: StoreProviderResponse_Status.values)
    ..aOS(2, _omitFieldNames ? '' : 'errorMessage')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'replicationCount', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  StoreProviderResponse clone() => StoreProviderResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  StoreProviderResponse copyWith(void Function(StoreProviderResponse) updates) => super.copyWith((message) => updates(message as StoreProviderResponse)) as StoreProviderResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StoreProviderResponse create() => StoreProviderResponse._();
  StoreProviderResponse createEmptyInstance() => create();
  static $pb.PbList<StoreProviderResponse> createRepeated() => $pb.PbList<StoreProviderResponse>();
  @$core.pragma('dart2js:noInline')
  static StoreProviderResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StoreProviderResponse>(create);
  static StoreProviderResponse? _defaultInstance;

  @$pb.TagNumber(1)
  StoreProviderResponse_Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(StoreProviderResponse_Status v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => clearField(1);

  /// Error message if status is ERROR
  @$pb.TagNumber(2)
  $core.String get errorMessage => $_getSZ(1);
  @$pb.TagNumber(2)
  set errorMessage($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasErrorMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrorMessage() => clearField(2);

  /// Number of successful replications
  @$pb.TagNumber(3)
  $core.int get replicationCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set replicationCount($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasReplicationCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearReplicationCount() => clearField(3);
}

/// Request to retrieve provider information
class GetProvidersRequest extends $pb.GeneratedMessage {
  factory GetProvidersRequest({
    $5.K_PeerId? key,
    $core.int? maxProviders,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (maxProviders != null) {
      $result.maxProviders = maxProviders;
    }
    return $result;
  }
  GetProvidersRequest._() : super();
  factory GetProvidersRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetProvidersRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetProvidersRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.store_provider'), createEmptyInstance: create)
    ..aOM<$5.K_PeerId>(1, _omitFieldNames ? '' : 'key', subBuilder: $5.K_PeerId.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'maxProviders', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetProvidersRequest clone() => GetProvidersRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetProvidersRequest copyWith(void Function(GetProvidersRequest) updates) => super.copyWith((message) => updates(message as GetProvidersRequest)) as GetProvidersRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProvidersRequest create() => GetProvidersRequest._();
  GetProvidersRequest createEmptyInstance() => create();
  static $pb.PbList<GetProvidersRequest> createRepeated() => $pb.PbList<GetProvidersRequest>();
  @$core.pragma('dart2js:noInline')
  static GetProvidersRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetProvidersRequest>(create);
  static GetProvidersRequest? _defaultInstance;

  /// The key to look up providers for
  @$pb.TagNumber(1)
  $5.K_PeerId get key => $_getN(0);
  @$pb.TagNumber(1)
  set key($5.K_PeerId v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);
  @$pb.TagNumber(1)
  $5.K_PeerId ensureKey() => $_ensure(0);

  /// Maximum number of providers to return
  @$pb.TagNumber(2)
  $core.int get maxProviders => $_getIZ(1);
  @$pb.TagNumber(2)
  set maxProviders($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMaxProviders() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaxProviders() => clearField(2);
}

/// Response containing provider information
class GetProvidersResponse extends $pb.GeneratedMessage {
  factory GetProvidersResponse({
    $core.Iterable<$5.V_PeerInfo>? providers,
    $core.Iterable<$5.V_PeerInfo>? closestPeers,
  }) {
    final $result = create();
    if (providers != null) {
      $result.providers.addAll(providers);
    }
    if (closestPeers != null) {
      $result.closestPeers.addAll(closestPeers);
    }
    return $result;
  }
  GetProvidersResponse._() : super();
  factory GetProvidersResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetProvidersResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetProvidersResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.dht.store_provider'), createEmptyInstance: create)
    ..pc<$5.V_PeerInfo>(1, _omitFieldNames ? '' : 'providers', $pb.PbFieldType.PM, subBuilder: $5.V_PeerInfo.create)
    ..pc<$5.V_PeerInfo>(2, _omitFieldNames ? '' : 'closestPeers', $pb.PbFieldType.PM, subBuilder: $5.V_PeerInfo.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetProvidersResponse clone() => GetProvidersResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetProvidersResponse copyWith(void Function(GetProvidersResponse) updates) => super.copyWith((message) => updates(message as GetProvidersResponse)) as GetProvidersResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProvidersResponse create() => GetProvidersResponse._();
  GetProvidersResponse createEmptyInstance() => create();
  static $pb.PbList<GetProvidersResponse> createRepeated() => $pb.PbList<GetProvidersResponse>();
  @$core.pragma('dart2js:noInline')
  static GetProvidersResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetProvidersResponse>(create);
  static GetProvidersResponse? _defaultInstance;

  /// List of providers for the requested key
  @$pb.TagNumber(1)
  $core.List<$5.V_PeerInfo> get providers => $_getList(0);

  /// Closest peers that might have the provider information
  @$pb.TagNumber(2)
  $core.List<$5.V_PeerInfo> get closestPeers => $_getList(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
