//
//  Generated code. Do not modify.
//  source: config.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ProtocolConfig extends $pb.GeneratedMessage {
  factory ProtocolConfig({
    $core.String? protocolId,
    $core.int? messageTimeoutSeconds,
    $core.int? maxRetries,
    $core.int? maxMessageSize,
    RateLimitConfig? rateLimit,
    CircuitBreakerConfig? circuitBreaker,
  }) {
    final $result = create();
    if (protocolId != null) {
      $result.protocolId = protocolId;
    }
    if (messageTimeoutSeconds != null) {
      $result.messageTimeoutSeconds = messageTimeoutSeconds;
    }
    if (maxRetries != null) {
      $result.maxRetries = maxRetries;
    }
    if (maxMessageSize != null) {
      $result.maxMessageSize = maxMessageSize;
    }
    if (rateLimit != null) {
      $result.rateLimit = rateLimit;
    }
    if (circuitBreaker != null) {
      $result.circuitBreaker = circuitBreaker;
    }
    return $result;
  }
  ProtocolConfig._() : super();
  factory ProtocolConfig.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ProtocolConfig.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProtocolConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.config'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'protocolId')
    ..a<$core.int>(
        2, _omitFieldNames ? '' : 'messageTimeoutSeconds', $pb.PbFieldType.OU3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'maxRetries', $pb.PbFieldType.OU3)
    ..a<$core.int>(
        4, _omitFieldNames ? '' : 'maxMessageSize', $pb.PbFieldType.OU3)
    ..aOM<RateLimitConfig>(5, _omitFieldNames ? '' : 'rateLimit',
        subBuilder: RateLimitConfig.create)
    ..aOM<CircuitBreakerConfig>(6, _omitFieldNames ? '' : 'circuitBreaker',
        subBuilder: CircuitBreakerConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ProtocolConfig clone() => ProtocolConfig()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ProtocolConfig copyWith(void Function(ProtocolConfig) updates) =>
      super.copyWith((message) => updates(message as ProtocolConfig))
          as ProtocolConfig;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtocolConfig create() => ProtocolConfig._();
  ProtocolConfig createEmptyInstance() => create();
  static $pb.PbList<ProtocolConfig> createRepeated() =>
      $pb.PbList<ProtocolConfig>();
  @$core.pragma('dart2js:noInline')
  static ProtocolConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProtocolConfig>(create);
  static ProtocolConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get protocolId => $_getSZ(0);
  @$pb.TagNumber(1)
  set protocolId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasProtocolId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get messageTimeoutSeconds => $_getIZ(1);
  @$pb.TagNumber(2)
  set messageTimeoutSeconds($core.int v) {
    $_setUnsignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasMessageTimeoutSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageTimeoutSeconds() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get maxRetries => $_getIZ(2);
  @$pb.TagNumber(3)
  set maxRetries($core.int v) {
    $_setUnsignedInt32(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasMaxRetries() => $_has(2);
  @$pb.TagNumber(3)
  void clearMaxRetries() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get maxMessageSize => $_getIZ(3);
  @$pb.TagNumber(4)
  set maxMessageSize($core.int v) {
    $_setUnsignedInt32(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasMaxMessageSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaxMessageSize() => clearField(4);

  @$pb.TagNumber(5)
  RateLimitConfig get rateLimit => $_getN(4);
  @$pb.TagNumber(5)
  set rateLimit(RateLimitConfig v) {
    setField(5, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasRateLimit() => $_has(4);
  @$pb.TagNumber(5)
  void clearRateLimit() => clearField(5);
  @$pb.TagNumber(5)
  RateLimitConfig ensureRateLimit() => $_ensure(4);

  @$pb.TagNumber(6)
  CircuitBreakerConfig get circuitBreaker => $_getN(5);
  @$pb.TagNumber(6)
  set circuitBreaker(CircuitBreakerConfig v) {
    setField(6, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasCircuitBreaker() => $_has(5);
  @$pb.TagNumber(6)
  void clearCircuitBreaker() => clearField(6);
  @$pb.TagNumber(6)
  CircuitBreakerConfig ensureCircuitBreaker() => $_ensure(5);
}

class RateLimitConfig extends $pb.GeneratedMessage {
  factory RateLimitConfig({
    $core.int? maxRequestsPerWindow,
    $core.int? windowSeconds,
  }) {
    final $result = create();
    if (maxRequestsPerWindow != null) {
      $result.maxRequestsPerWindow = maxRequestsPerWindow;
    }
    if (windowSeconds != null) {
      $result.windowSeconds = windowSeconds;
    }
    return $result;
  }
  RateLimitConfig._() : super();
  factory RateLimitConfig.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory RateLimitConfig.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RateLimitConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.config'),
      createEmptyInstance: create)
    ..a<$core.int>(
        1, _omitFieldNames ? '' : 'maxRequestsPerWindow', $pb.PbFieldType.OU3)
    ..a<$core.int>(
        2, _omitFieldNames ? '' : 'windowSeconds', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  RateLimitConfig clone() => RateLimitConfig()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  RateLimitConfig copyWith(void Function(RateLimitConfig) updates) =>
      super.copyWith((message) => updates(message as RateLimitConfig))
          as RateLimitConfig;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RateLimitConfig create() => RateLimitConfig._();
  RateLimitConfig createEmptyInstance() => create();
  static $pb.PbList<RateLimitConfig> createRepeated() =>
      $pb.PbList<RateLimitConfig>();
  @$core.pragma('dart2js:noInline')
  static RateLimitConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RateLimitConfig>(create);
  static RateLimitConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get maxRequestsPerWindow => $_getIZ(0);
  @$pb.TagNumber(1)
  set maxRequestsPerWindow($core.int v) {
    $_setUnsignedInt32(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasMaxRequestsPerWindow() => $_has(0);
  @$pb.TagNumber(1)
  void clearMaxRequestsPerWindow() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get windowSeconds => $_getIZ(1);
  @$pb.TagNumber(2)
  set windowSeconds($core.int v) {
    $_setUnsignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasWindowSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearWindowSeconds() => clearField(2);
}

class CircuitBreakerConfig extends $pb.GeneratedMessage {
  factory CircuitBreakerConfig({
    $core.int? resetTimeoutSeconds,
    $core.int? failureThreshold,
    $core.int? halfOpenTimeoutSeconds,
  }) {
    final $result = create();
    if (resetTimeoutSeconds != null) {
      $result.resetTimeoutSeconds = resetTimeoutSeconds;
    }
    if (failureThreshold != null) {
      $result.failureThreshold = failureThreshold;
    }
    if (halfOpenTimeoutSeconds != null) {
      $result.halfOpenTimeoutSeconds = halfOpenTimeoutSeconds;
    }
    return $result;
  }
  CircuitBreakerConfig._() : super();
  factory CircuitBreakerConfig.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CircuitBreakerConfig.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CircuitBreakerConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ipfs.config'),
      createEmptyInstance: create)
    ..a<$core.int>(
        1, _omitFieldNames ? '' : 'resetTimeoutSeconds', $pb.PbFieldType.OU3)
    ..a<$core.int>(
        2, _omitFieldNames ? '' : 'failureThreshold', $pb.PbFieldType.OU3)
    ..a<$core.int>(
        3, _omitFieldNames ? '' : 'halfOpenTimeoutSeconds', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CircuitBreakerConfig clone() =>
      CircuitBreakerConfig()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CircuitBreakerConfig copyWith(void Function(CircuitBreakerConfig) updates) =>
      super.copyWith((message) => updates(message as CircuitBreakerConfig))
          as CircuitBreakerConfig;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CircuitBreakerConfig create() => CircuitBreakerConfig._();
  CircuitBreakerConfig createEmptyInstance() => create();
  static $pb.PbList<CircuitBreakerConfig> createRepeated() =>
      $pb.PbList<CircuitBreakerConfig>();
  @$core.pragma('dart2js:noInline')
  static CircuitBreakerConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CircuitBreakerConfig>(create);
  static CircuitBreakerConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get resetTimeoutSeconds => $_getIZ(0);
  @$pb.TagNumber(1)
  set resetTimeoutSeconds($core.int v) {
    $_setUnsignedInt32(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasResetTimeoutSeconds() => $_has(0);
  @$pb.TagNumber(1)
  void clearResetTimeoutSeconds() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get failureThreshold => $_getIZ(1);
  @$pb.TagNumber(2)
  set failureThreshold($core.int v) {
    $_setUnsignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasFailureThreshold() => $_has(1);
  @$pb.TagNumber(2)
  void clearFailureThreshold() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get halfOpenTimeoutSeconds => $_getIZ(2);
  @$pb.TagNumber(3)
  set halfOpenTimeoutSeconds($core.int v) {
    $_setUnsignedInt32(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasHalfOpenTimeoutSeconds() => $_has(2);
  @$pb.TagNumber(3)
  void clearHalfOpenTimeoutSeconds() => clearField(3);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
