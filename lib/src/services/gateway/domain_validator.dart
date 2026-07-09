// lib/src/services/gateway/domain_validator.dart
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../utils/logger.dart';

/// Validates domain ownership and accessibility for ACME HTTP-01 challenges.
///
/// This class provides utilities to verify that:
/// - DNS resolves the domain to the current server
/// - HTTP port 80 is accessible from the internet
/// - The domain can receive ACME validation requests
class DomainValidator {
  /// Creates a domain validator.
  DomainValidator({this.expectedIp, http.Client? client})
      : _client = client,
        _logger = Logger('DomainValidator');

  /// Optional HTTP client for testing. If not provided, a new [http.Client] is
  /// created per request.
  final http.Client? _client;

  /// The expected IP address that the domain should resolve to.
  /// If null, the validator only checks that the domain resolves to some IP.
  final String? expectedIp;

  final Logger _logger;

  /// Validates that the domain is ready for ACME HTTP-01 challenge.
  ///
  /// Performs the following checks:
  /// 1. DNS resolution - the domain must resolve to an IP address
  /// 2. IP match (if [expectedIp] is set) - the domain must resolve to the expected IP
  /// 3. HTTP accessibility - port 80 must be accessible
  ///
  /// Returns `true` if all checks pass, `false` otherwise.
  Future<DomainValidationResult> validateDomain(String domain) async {
    _logger.info('Validating domain: $domain');

    // Check DNS resolution
    final dnsResult = await _checkDnsResolution(domain);
    if (!dnsResult.success) {
      return dnsResult;
    }

    // Check HTTP accessibility
    final httpResult = await _checkHttpAccessibility(domain);
    if (!httpResult.success) {
      return httpResult;
    }

    return DomainValidationResult(
      success: true,
      message: 'Domain $domain is ready for ACME validation',
      details: {
        'dns': dnsResult.details,
        'http': httpResult.details,
      },
    );
  }

  /// Checks DNS resolution for the domain.
  Future<DomainValidationResult> _checkDnsResolution(String domain) async {
    try {
      _logger.info('Checking DNS resolution for $domain');
      final addresses = await InternetAddress.lookup(domain);

      if (addresses.isEmpty) {
        return DomainValidationResult(
          success: false,
          message: 'Domain $domain does not resolve to any IP address',
          details: {'error': 'no_ip_addresses'},
        );
      }

      final resolvedIps = addresses.map((a) => a.address).toList();
      _logger.info('Domain $domain resolves to: $resolvedIps');

      // If expected IP is set, check for match
      if (expectedIp != null) {
        final matches = resolvedIps.contains(expectedIp);
        if (!matches) {
          return DomainValidationResult(
            success: false,
            message: 'Domain $domain resolves to $resolvedIps, '
                'but expected $expectedIp',
            details: {
              'resolved_ips': resolvedIps,
              'expected_ip': expectedIp,
            },
          );
        }
      }

      return DomainValidationResult(
        success: true,
        message: 'DNS resolution successful for $domain',
        details: {'resolved_ips': resolvedIps},
      );
    } on SocketException catch (e) {
      return DomainValidationResult(
        success: false,
        message: 'DNS lookup failed for $domain: ${e.message}',
        details: {'error': e.message},
      );
    } catch (e, stackTrace) {
      _logger.error('DNS validation error', e, stackTrace);
      return DomainValidationResult(
        success: false,
        message: 'Unexpected DNS validation error: $e',
        details: {'error': e.toString()},
      );
    }
  }

  /// Checks HTTP accessibility on port 80.
  Future<DomainValidationResult> _checkHttpAccessibility(String domain) async {
    try {
      _logger.info('Checking HTTP accessibility for $domain:80');

      // Try to connect to port 80 with a timeout
      final client = _client ?? http.Client();
      try {
        final response = await client
            .get(
              Uri.http(domain, '/'),
            )
            .timeout(
              const Duration(seconds: 10),
            );

        // We don't care about the response code, just that we got a response
        _logger.info('HTTP accessibility check successful: ${response.statusCode}');

        return DomainValidationResult(
          success: true,
          message: 'HTTP port 80 is accessible for $domain',
          details: {'status_code': response.statusCode},
        );
      } on SocketException catch (e) {
        return DomainValidationResult(
          success: false,
          message: 'Cannot connect to $domain:80 - ${e.message}',
          details: {'error': e.message, 'hint': 'Check firewall and port forwarding'},
        );
      } on HttpException {
        // HTTP exception is OK - it means we connected but got an HTTP error
        _logger.info('HTTP connection successful (HTTP error is OK for ACME)');
        return DomainValidationResult(
          success: true,
          message: 'HTTP port 80 is accessible for $domain',
          details: {'note': 'HTTP error is acceptable for ACME validation'},
        );
      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      _logger.error('HTTP accessibility check error', e, stackTrace);
      return DomainValidationResult(
        success: false,
        message: 'HTTP accessibility check failed: $e',
        details: {'error': e.toString()},
      );
    }
  }

  /// Checks if the current machine's public IP matches the domain's DNS.
  ///
  /// This is useful for verifying that the domain is correctly pointed to
  /// the current server before attempting ACME validation.
  Future<String?> getPublicIp() async {
    try {
      final client = _client ?? http.Client();
      try {
        // Use a service that returns the public IP
        final response = await client
            .get(Uri.parse('https://api.ipify.org'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final ip = response.body.trim();
          _logger.info('Detected public IP: $ip');
          return ip;
        }
      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      _logger.warning('Failed to detect public IP', e, stackTrace);
    }
    return null;
  }
}

/// Result of a domain validation check.
class DomainValidationResult {
  /// Creates a domain validation result.
  DomainValidationResult({
    required this.success,
    required this.message,
    this.details = const {},
  });

  /// Whether the validation passed.
  final bool success;

  /// Human-readable message describing the result.
  final String message;

  /// Additional details about the validation.
  final Map<String, dynamic> details;

  @override
  String toString() => 'DomainValidationResult(success: $success, message: $message)';
}
