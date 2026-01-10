// This is a generated file - do not edit.
//
// Generated from config.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class ProtocolConfig extends $pb.GeneratedMessage {
  factory ProtocolConfig({
    $core.String? protocolId,
    $core.int? messageTimeoutSeconds,
    $core.int? maxRetries,
    $core.int? maxMessageSize,
    RateLimitConfig? rateLimit,
    CircuitBreakerConfig? circuitBreaker,
  }) {
    final result = create();
    if (protocolId != null) result.protocolId = protocolId;
    if (messageTimeoutSeconds != null) result.messageTimeoutSeconds = messageTimeoutSeconds;
    if (maxRetries != null) result.maxRetries = maxRetries;
    if (maxMessageSize != null) result.maxMessageSize = maxMessageSize;
    if (rateLimit != null) result.rateLimit = rateLimit;
    if (circuitBreaker != null) result.circuitBreaker = circuitBreaker;
    return result;
  }

  ProtocolConfig._();

  factory ProtocolConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProtocolConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ProtocolConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.config'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'protocolId')
    ..aI(2, _omitFieldNames ? '' : 'messageTimeoutSeconds', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'maxRetries', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'maxMessageSize', fieldType: $pb.PbFieldType.OU3)
    ..aOM<RateLimitConfig>(5, _omitFieldNames ? '' : 'rateLimit',
        subBuilder: RateLimitConfig.create)
    ..aOM<CircuitBreakerConfig>(6, _omitFieldNames ? '' : 'circuitBreaker',
        subBuilder: CircuitBreakerConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolConfig copyWith(void Function(ProtocolConfig) updates) =>
      super.copyWith((message) => updates(message as ProtocolConfig)) as ProtocolConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtocolConfig create() => ProtocolConfig._();
  @$core.override
  ProtocolConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProtocolConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProtocolConfig>(create);
  static ProtocolConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get protocolId => $_getSZ(0);
  @$pb.TagNumber(1)
  set protocolId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProtocolId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get messageTimeoutSeconds => $_getIZ(1);
  @$pb.TagNumber(2)
  set messageTimeoutSeconds($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageTimeoutSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageTimeoutSeconds() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get maxRetries => $_getIZ(2);
  @$pb.TagNumber(3)
  set maxRetries($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMaxRetries() => $_has(2);
  @$pb.TagNumber(3)
  void clearMaxRetries() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get maxMessageSize => $_getIZ(3);
  @$pb.TagNumber(4)
  set maxMessageSize($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMaxMessageSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaxMessageSize() => $_clearField(4);

  @$pb.TagNumber(5)
  RateLimitConfig get rateLimit => $_getN(4);
  @$pb.TagNumber(5)
  set rateLimit(RateLimitConfig value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRateLimit() => $_has(4);
  @$pb.TagNumber(5)
  void clearRateLimit() => $_clearField(5);
  @$pb.TagNumber(5)
  RateLimitConfig ensureRateLimit() => $_ensure(4);

  @$pb.TagNumber(6)
  CircuitBreakerConfig get circuitBreaker => $_getN(5);
  @$pb.TagNumber(6)
  set circuitBreaker(CircuitBreakerConfig value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCircuitBreaker() => $_has(5);
  @$pb.TagNumber(6)
  void clearCircuitBreaker() => $_clearField(6);
  @$pb.TagNumber(6)
  CircuitBreakerConfig ensureCircuitBreaker() => $_ensure(5);
}

class RateLimitConfig extends $pb.GeneratedMessage {
  factory RateLimitConfig({
    $core.int? maxRequestsPerWindow,
    $core.int? windowSeconds,
  }) {
    final result = create();
    if (maxRequestsPerWindow != null) result.maxRequestsPerWindow = maxRequestsPerWindow;
    if (windowSeconds != null) result.windowSeconds = windowSeconds;
    return result;
  }

  RateLimitConfig._();

  factory RateLimitConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RateLimitConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RateLimitConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.config'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'maxRequestsPerWindow', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'windowSeconds', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RateLimitConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RateLimitConfig copyWith(void Function(RateLimitConfig) updates) =>
      super.copyWith((message) => updates(message as RateLimitConfig)) as RateLimitConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RateLimitConfig create() => RateLimitConfig._();
  @$core.override
  RateLimitConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RateLimitConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RateLimitConfig>(create);
  static RateLimitConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get maxRequestsPerWindow => $_getIZ(0);
  @$pb.TagNumber(1)
  set maxRequestsPerWindow($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMaxRequestsPerWindow() => $_has(0);
  @$pb.TagNumber(1)
  void clearMaxRequestsPerWindow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get windowSeconds => $_getIZ(1);
  @$pb.TagNumber(2)
  set windowSeconds($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWindowSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearWindowSeconds() => $_clearField(2);
}

class CircuitBreakerConfig extends $pb.GeneratedMessage {
  factory CircuitBreakerConfig({
    $core.int? resetTimeoutSeconds,
    $core.int? failureThreshold,
    $core.int? halfOpenTimeoutSeconds,
  }) {
    final result = create();
    if (resetTimeoutSeconds != null) result.resetTimeoutSeconds = resetTimeoutSeconds;
    if (failureThreshold != null) result.failureThreshold = failureThreshold;
    if (halfOpenTimeoutSeconds != null) result.halfOpenTimeoutSeconds = halfOpenTimeoutSeconds;
    return result;
  }

  CircuitBreakerConfig._();

  factory CircuitBreakerConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CircuitBreakerConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CircuitBreakerConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.config'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'resetTimeoutSeconds', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'failureThreshold', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'halfOpenTimeoutSeconds', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitBreakerConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CircuitBreakerConfig copyWith(void Function(CircuitBreakerConfig) updates) =>
      super.copyWith((message) => updates(message as CircuitBreakerConfig)) as CircuitBreakerConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitBreakerConfig create() => CircuitBreakerConfig._();
  @$core.override
  CircuitBreakerConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CircuitBreakerConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CircuitBreakerConfig>(create);
  static CircuitBreakerConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get resetTimeoutSeconds => $_getIZ(0);
  @$pb.TagNumber(1)
  set resetTimeoutSeconds($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResetTimeoutSeconds() => $_has(0);
  @$pb.TagNumber(1)
  void clearResetTimeoutSeconds() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get failureThreshold => $_getIZ(1);
  @$pb.TagNumber(2)
  set failureThreshold($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFailureThreshold() => $_has(1);
  @$pb.TagNumber(2)
  void clearFailureThreshold() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get halfOpenTimeoutSeconds => $_getIZ(2);
  @$pb.TagNumber(3)
  set halfOpenTimeoutSeconds($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHalfOpenTimeoutSeconds() => $_has(2);
  @$pb.TagNumber(3)
  void clearHalfOpenTimeoutSeconds() => $_clearField(3);
}

const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
