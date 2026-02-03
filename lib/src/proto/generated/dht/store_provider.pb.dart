// This is a generated file - do not edit.
//
// Generated from dht/store_provider.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'common_red_black_tree.pb.dart' as $0;
import 'store_provider.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'store_provider.pbenum.dart';

/// Request message for storing provider information
class StoreProviderRequest extends $pb.GeneratedMessage {
  factory StoreProviderRequest({
    $0.K_PeerId? key,
    $0.V_PeerInfo? providerInfo,
    $fixnum.Int64? ttl,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (providerInfo != null) result.providerInfo = providerInfo;
    if (ttl != null) result.ttl = ttl;
    return result;
  }

  StoreProviderRequest._();

  factory StoreProviderRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StoreProviderRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StoreProviderRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.dht.store_provider'),
      createEmptyInstance: create)
    ..aOM<$0.K_PeerId>(1, _omitFieldNames ? '' : 'key',
        subBuilder: $0.K_PeerId.create)
    ..aOM<$0.V_PeerInfo>(2, _omitFieldNames ? '' : 'providerInfo',
        subBuilder: $0.V_PeerInfo.create)
    ..aInt64(3, _omitFieldNames ? '' : 'ttl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoreProviderRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoreProviderRequest copyWith(void Function(StoreProviderRequest) updates) =>
      super.copyWith((message) => updates(message as StoreProviderRequest))
          as StoreProviderRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StoreProviderRequest create() => StoreProviderRequest._();
  @$core.override
  StoreProviderRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StoreProviderRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StoreProviderRequest>(create);
  static StoreProviderRequest? _defaultInstance;

  /// The key for which provider information is being stored
  @$pb.TagNumber(1)
  $0.K_PeerId get key => $_getN(0);
  @$pb.TagNumber(1)
  set key($0.K_PeerId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.K_PeerId ensureKey() => $_ensure(0);

  /// The provider information to store
  @$pb.TagNumber(2)
  $0.V_PeerInfo get providerInfo => $_getN(1);
  @$pb.TagNumber(2)
  set providerInfo($0.V_PeerInfo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProviderInfo() => $_has(1);
  @$pb.TagNumber(2)
  void clearProviderInfo() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.V_PeerInfo ensureProviderInfo() => $_ensure(1);

  /// Time-to-live in seconds for this provider record
  @$pb.TagNumber(3)
  $fixnum.Int64 get ttl => $_getI64(2);
  @$pb.TagNumber(3)
  set ttl($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTtl() => $_has(2);
  @$pb.TagNumber(3)
  void clearTtl() => $_clearField(3);
}

/// Response message for store provider operation
class StoreProviderResponse extends $pb.GeneratedMessage {
  factory StoreProviderResponse({
    StoreProviderResponse_Status? status,
    $core.String? errorMessage,
    $core.int? replicationCount,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (errorMessage != null) result.errorMessage = errorMessage;
    if (replicationCount != null) result.replicationCount = replicationCount;
    return result;
  }

  StoreProviderResponse._();

  factory StoreProviderResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StoreProviderResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StoreProviderResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.dht.store_provider'),
      createEmptyInstance: create)
    ..aE<StoreProviderResponse_Status>(1, _omitFieldNames ? '' : 'status',
        enumValues: StoreProviderResponse_Status.values)
    ..aOS(2, _omitFieldNames ? '' : 'errorMessage')
    ..aI(3, _omitFieldNames ? '' : 'replicationCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoreProviderResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoreProviderResponse copyWith(
          void Function(StoreProviderResponse) updates) =>
      super.copyWith((message) => updates(message as StoreProviderResponse))
          as StoreProviderResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StoreProviderResponse create() => StoreProviderResponse._();
  @$core.override
  StoreProviderResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StoreProviderResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StoreProviderResponse>(create);
  static StoreProviderResponse? _defaultInstance;

  @$pb.TagNumber(1)
  StoreProviderResponse_Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(StoreProviderResponse_Status value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  /// Error message if status is ERROR
  @$pb.TagNumber(2)
  $core.String get errorMessage => $_getSZ(1);
  @$pb.TagNumber(2)
  set errorMessage($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasErrorMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrorMessage() => $_clearField(2);

  /// Number of successful replications
  @$pb.TagNumber(3)
  $core.int get replicationCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set replicationCount($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReplicationCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearReplicationCount() => $_clearField(3);
}

/// Request to retrieve provider information
class GetProvidersRequest extends $pb.GeneratedMessage {
  factory GetProvidersRequest({
    $0.K_PeerId? key,
    $core.int? maxProviders,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (maxProviders != null) result.maxProviders = maxProviders;
    return result;
  }

  GetProvidersRequest._();

  factory GetProvidersRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetProvidersRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetProvidersRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.dht.store_provider'),
      createEmptyInstance: create)
    ..aOM<$0.K_PeerId>(1, _omitFieldNames ? '' : 'key',
        subBuilder: $0.K_PeerId.create)
    ..aI(2, _omitFieldNames ? '' : 'maxProviders')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProvidersRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProvidersRequest copyWith(void Function(GetProvidersRequest) updates) =>
      super.copyWith((message) => updates(message as GetProvidersRequest))
          as GetProvidersRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProvidersRequest create() => GetProvidersRequest._();
  @$core.override
  GetProvidersRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetProvidersRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetProvidersRequest>(create);
  static GetProvidersRequest? _defaultInstance;

  /// The key to look up providers for
  @$pb.TagNumber(1)
  $0.K_PeerId get key => $_getN(0);
  @$pb.TagNumber(1)
  set key($0.K_PeerId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.K_PeerId ensureKey() => $_ensure(0);

  /// Maximum number of providers to return
  @$pb.TagNumber(2)
  $core.int get maxProviders => $_getIZ(1);
  @$pb.TagNumber(2)
  set maxProviders($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMaxProviders() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaxProviders() => $_clearField(2);
}

/// Response containing provider information
class GetProvidersResponse extends $pb.GeneratedMessage {
  factory GetProvidersResponse({
    $core.Iterable<$0.V_PeerInfo>? providers,
    $core.Iterable<$0.V_PeerInfo>? closestPeers,
  }) {
    final result = create();
    if (providers != null) result.providers.addAll(providers);
    if (closestPeers != null) result.closestPeers.addAll(closestPeers);
    return result;
  }

  GetProvidersResponse._();

  factory GetProvidersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetProvidersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetProvidersResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'ipfs.dht.store_provider'),
      createEmptyInstance: create)
    ..pPM<$0.V_PeerInfo>(1, _omitFieldNames ? '' : 'providers',
        subBuilder: $0.V_PeerInfo.create)
    ..pPM<$0.V_PeerInfo>(2, _omitFieldNames ? '' : 'closestPeers',
        subBuilder: $0.V_PeerInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProvidersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProvidersResponse copyWith(void Function(GetProvidersResponse) updates) =>
      super.copyWith((message) => updates(message as GetProvidersResponse))
          as GetProvidersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProvidersResponse create() => GetProvidersResponse._();
  @$core.override
  GetProvidersResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetProvidersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetProvidersResponse>(create);
  static GetProvidersResponse? _defaultInstance;

  /// List of providers for the requested key
  @$pb.TagNumber(1)
  $pb.PbList<$0.V_PeerInfo> get providers => $_getList(0);

  /// Closest peers that might have the provider information
  @$pb.TagNumber(2)
  $pb.PbList<$0.V_PeerInfo> get closestPeers => $_getList(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

