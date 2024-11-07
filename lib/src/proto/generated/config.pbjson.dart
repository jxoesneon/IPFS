//
//  Generated code. Do not modify.
//  source: config.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use protocolConfigDescriptor instead')
const ProtocolConfig$json = {
  '1': 'ProtocolConfig',
  '2': [
    {'1': 'protocol_id', '3': 1, '4': 1, '5': 9, '10': 'protocolId'},
    {'1': 'message_timeout_seconds', '3': 2, '4': 1, '5': 13, '10': 'messageTimeoutSeconds'},
    {'1': 'max_retries', '3': 3, '4': 1, '5': 13, '10': 'maxRetries'},
    {'1': 'max_message_size', '3': 4, '4': 1, '5': 13, '10': 'maxMessageSize'},
    {'1': 'rate_limit', '3': 5, '4': 1, '5': 11, '6': '.ipfs.config.RateLimitConfig', '10': 'rateLimit'},
    {'1': 'circuit_breaker', '3': 6, '4': 1, '5': 11, '6': '.ipfs.config.CircuitBreakerConfig', '10': 'circuitBreaker'},
  ],
};

/// Descriptor for `ProtocolConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protocolConfigDescriptor = $convert.base64Decode(
    'Cg5Qcm90b2NvbENvbmZpZxIfCgtwcm90b2NvbF9pZBgBIAEoCVIKcHJvdG9jb2xJZBI2ChdtZX'
    'NzYWdlX3RpbWVvdXRfc2Vjb25kcxgCIAEoDVIVbWVzc2FnZVRpbWVvdXRTZWNvbmRzEh8KC21h'
    'eF9yZXRyaWVzGAMgASgNUgptYXhSZXRyaWVzEigKEG1heF9tZXNzYWdlX3NpemUYBCABKA1SDm'
    '1heE1lc3NhZ2VTaXplEjsKCnJhdGVfbGltaXQYBSABKAsyHC5pcGZzLmNvbmZpZy5SYXRlTGlt'
    'aXRDb25maWdSCXJhdGVMaW1pdBJKCg9jaXJjdWl0X2JyZWFrZXIYBiABKAsyIS5pcGZzLmNvbm'
    'ZpZy5DaXJjdWl0QnJlYWtlckNvbmZpZ1IOY2lyY3VpdEJyZWFrZXI=');

@$core.Deprecated('Use rateLimitConfigDescriptor instead')
const RateLimitConfig$json = {
  '1': 'RateLimitConfig',
  '2': [
    {'1': 'max_requests_per_window', '3': 1, '4': 1, '5': 13, '10': 'maxRequestsPerWindow'},
    {'1': 'window_seconds', '3': 2, '4': 1, '5': 13, '10': 'windowSeconds'},
  ],
};

/// Descriptor for `RateLimitConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rateLimitConfigDescriptor = $convert.base64Decode(
    'Cg9SYXRlTGltaXRDb25maWcSNQoXbWF4X3JlcXVlc3RzX3Blcl93aW5kb3cYASABKA1SFG1heF'
    'JlcXVlc3RzUGVyV2luZG93EiUKDndpbmRvd19zZWNvbmRzGAIgASgNUg13aW5kb3dTZWNvbmRz');

@$core.Deprecated('Use circuitBreakerConfigDescriptor instead')
const CircuitBreakerConfig$json = {
  '1': 'CircuitBreakerConfig',
  '2': [
    {'1': 'reset_timeout_seconds', '3': 1, '4': 1, '5': 13, '10': 'resetTimeoutSeconds'},
    {'1': 'failure_threshold', '3': 2, '4': 1, '5': 13, '10': 'failureThreshold'},
    {'1': 'half_open_timeout_seconds', '3': 3, '4': 1, '5': 13, '10': 'halfOpenTimeoutSeconds'},
  ],
};

/// Descriptor for `CircuitBreakerConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List circuitBreakerConfigDescriptor = $convert.base64Decode(
    'ChRDaXJjdWl0QnJlYWtlckNvbmZpZxIyChVyZXNldF90aW1lb3V0X3NlY29uZHMYASABKA1SE3'
    'Jlc2V0VGltZW91dFNlY29uZHMSKwoRZmFpbHVyZV90aHJlc2hvbGQYAiABKA1SEGZhaWx1cmVU'
    'aHJlc2hvbGQSOQoZaGFsZl9vcGVuX3RpbWVvdXRfc2Vjb25kcxgDIAEoDVIWaGFsZk9wZW5UaW'
    '1lb3V0U2Vjb25kcw==');

