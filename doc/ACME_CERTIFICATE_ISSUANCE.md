# ACME HTTP-01 Certificate Issuance

This document describes the production-ready ACME HTTP-01 certificate issuance implementation for the IPFS Gateway.

## Overview

The gateway supports automatic TLS certificate issuance and renewal via ACME (Automatic Certificate Management Environment) protocol, compatible with Let's Encrypt and ZeroSSL.

## Architecture

### Components

1. **AcmeClient** (`lib/src/services/gateway/acme_client.dart`)
   - Full ACME v2 (RFC 8555) implementation
   - HTTP-01 challenge support
   - Account registration and management
   - Certificate order creation and finalization
   - CSR generation and certificate download

2. **AcmePersistence** (`lib/src/services/gateway/acme_persistence.dart`)
   - File-based storage for account keys and certificates
   - Certificate metadata tracking (expiry, domains)
   - Automatic validity and renewal checking

3. **DomainValidator** (`lib/src/services/gateway/domain_validator.dart`)
   - DNS resolution verification
   - HTTP accessibility checks (port 80)
   - Pre-flight validation before ACME requests

4. **LetsEncryptAutoTlsProvider** (`lib/src/services/gateway/gateway_tls_manager.dart`)
   - Orchestrates the ACME flow
   - Integrates with the gateway for challenge serving
   - Manages certificate lifecycle

## Persistence Mechanism

### Storage Locations

The implementation uses file-based storage with configurable paths:

| Item | Default Path | Configurable Via |
|------|--------------|------------------|
| Account Key | `./data/acme/account_key.pem` | `autoTlsAccountKeyPath` |
| Certificate | `./data/acme/certificate.pem` | `autoTlsCertificatePath` |
| Private Key | `./data/acme/private_key.pem` | `autoTlsPrivateKeyPath` |
| Metadata | `./data/acme/metadata.json` | (fixed) |

### Data Format

- **Account Key**: PEM-encoded RSA private key (PKCS#1 format)
- **Certificate**: PEM-encoded certificate chain (leaf + intermediates)
- **Private Key**: PEM-encoded RSA private key matching the certificate
- **Metadata**: JSON with `notAfter`, `domains`, and `savedAt` fields

### Persistence Operations

```dart
final persistence = AcmePersistence(config);

// Save certificate
await persistence.saveCertificate(
  certificatePem: certPem,
  privateKeyPem: keyPem,
  notAfter: expiryDate,
  domains: ['example.com', 'www.example.com'],
);

// Load certificate
final certPem = await persistence.loadCertificate();
final keyPem = await persistence.loadPrivateKey();

// Check validity
final isValid = await persistence.hasValidCertificate();
final needsRenewal = await persistence.needsRenewal();
```

## Domain Validation

### Pre-flight Checks

Before attempting ACME certificate issuance, the gateway performs optional validation:

1. **DNS Resolution**
   - Verifies the domain resolves to an IP address
   - Optionally checks that it resolves to the expected IP
   - Returns detailed error messages if resolution fails

2. **HTTP Accessibility**
   - Attempts to connect to `http://domain:80`
   - Verifies port 80 is accessible from the internet
   - Provides hints for firewall/port forwarding issues

### Usage

```dart
final validator = DomainValidator(expectedIp: '1.2.3.4');
final result = await validator.validateDomain('example.com');

if (!result.success) {
  print('Validation failed: ${result.message}');
  print('Details: ${result.details}');
}
```

## Certificate Renewal

### Automatic Renewal Logic

The gateway automatically checks certificate validity on startup:

1. **Validity Check**: Verifies certificate exists and is not expired
2. **Renewal Threshold**: Checks if certificate is within renewal window
3. **Automatic Issuance**: If renewal is needed, initiates ACME flow

### Renewal Threshold

Configurable via `autoTlsRenewalThresholdDays` (default: 30 days).

Let's Encrypt certificates are valid for 90 days, so the default threshold renews certificates when they have 30 days or less remaining.

### Renewal Flow

```
1. Check if certificate exists
2. Check if certificate is within renewal threshold
3. If yes:
   a. Load existing account key (or create new one)
   b. Create ACME order
   c. Perform HTTP-01 challenge
   d. Download new certificate
   e. Replace old certificate files
   f. Update metadata
```

## Configuration

### GatewayConfig Options

```dart
final config = GatewayConfig(
  // Enable automatic TLS
  autoTls: true,

  // Domain configuration
  autoTlsDomain: 'example.com',
  autoTlsEmail: 'admin@example.com',
  autoTlsProvider: 'letsencrypt', // or 'zerossl'

  // Terms of service acceptance (required)
  autoTlsAcceptTos: true,

  // Additional domains (SANs)
  autoTlsSANs: ['www.example.com', 'api.example.com'],

  // Persistence paths (optional, defaults shown)
  autoTlsAccountKeyPath: './data/acme/account_key.pem',
  autoTlsCertificatePath: './data/acme/certificate.pem',
  autoTlsPrivateKeyPath: './data/acme/private_key.pem',

  // Renewal threshold (default: 30 days)
  autoTlsRenewalThresholdDays: 30,

  // TLS configuration
  enableTls: true,
  tlsPort: 443,
  redirectHttpToHttps: true,
);
```

### Staging vs Production

The `LetsEncryptAutoTlsProvider` supports staging mode:

```dart
final provider = LetsEncryptAutoTlsProvider(staging: true);
```

- **Staging**: Uses Let's Encrypt staging endpoint (no rate limits, untrusted certificates)
- **Production**: Uses Let's Encrypt production endpoint (rate limits apply, trusted certificates)

## HTTP-01 Challenge Serving

### Challenge Endpoint

The gateway automatically serves HTTP-01 challenges at:

```
http://domain/.well-known/acme-challenge/<token>
```

### Integration

The challenge endpoint is integrated into the gateway router:

```dart
_router.get('/.well-known/acme-challenge/<token|.*>', (Request request, String token) async {
  final provider = tlsManager.activeAutoTlsProvider;
  if (provider == null) {
    return Response.notFound('No ACME provider active');
  }
  final challenges = provider.pendingChallenges;
  final keyAuth = challenges[token];
  if (keyAuth == null) {
    return Response.notFound('Challenge not found');
  }
  return Response.ok(keyAuth, headers: {'Content-Type': 'text/plain'});
});
```

### Challenge Flow

1. ACME client generates challenge token and key authorization
2. Challenge is stored in `pendingChallenges` map
3. Gateway serves challenge at `/.well-known/acme-challenge/<token>`
4. ACME server validates challenge
5. Challenge is removed from map

## Testing

### Unit Tests

Unit tests are located in `test/services/gateway/acme_integration_test.dart`:

```bash
dart test test/services/gateway/acme_integration_test.dart
```

Tests cover:
- Persistence operations
- Domain validation structure
- Configuration validation
- Provider initialization

### Manual Integration Test

A manual integration test is provided for testing with a real domain:

```dart
test('Full ACME flow with staging server - MANUAL', () async {
  // Requires:
  // 1. Real domain with DNS pointing to test machine
  // 2. Port 80 accessible from internet
  // 3. Uncomment test code and run manually
}, skip: true);
```

### Running Manual Test

1. Set up a domain with DNS pointing to your machine
2. Ensure port 80 is accessible from the internet
3. Uncomment the manual test code
4. Run with staging mode first:
   ```bash
   dart test test/services/gateway/acme_integration_test.dart
   ```
5. If successful, test with production mode

## Deployment Requirements

### Network Requirements

1. **Public Domain**: A domain with DNS pointing to the gateway
2. **Port 80**: Must be accessible from the internet for HTTP-01 validation
3. **Port 443**: For HTTPS gateway traffic (if using TLS)
4. **Firewall**: Allow inbound traffic on ports 80 and 443

### File System Requirements

1. **Write Access**: Ability to create/write to `./data/acme/` directory
2. **Persistence**: Storage should persist across restarts
3. **Permissions**: Secure file permissions for private keys (chmod 600)

### Security Considerations

1. **Private Key Security**: Account and certificate private keys must be protected
2. **ToS Acceptance**: Explicit acceptance required (no silent issuance)
3. **Rate Limits**: Let's Encrypt has rate limits (staging recommended for testing)
4. **Certificate Expiry**: Monitor certificate expiry and renewal

## Troubleshooting

### Common Issues

#### 1. Domain Validation Fails

**Symptom**: DNS resolution fails
**Solution**:
- Verify DNS records are configured correctly
- Check DNS propagation (may take up to 48 hours)
- Use `dig` or `nslookup` to verify resolution

#### 2. HTTP Accessibility Fails

**Symptom**: Cannot connect to port 80
**Solution**:
- Check firewall rules allow port 80
- Verify port forwarding if behind NAT
- Test with `curl http://your-domain/`

#### 3. Challenge Validation Fails

**Symptom**: ACME server cannot validate challenge
**Solution**:
- Verify challenge endpoint is accessible
- Check gateway logs for challenge serving errors
- Ensure domain resolves to correct IP

#### 4. Rate Limit Errors

**Symptom**: ACME server returns rate limit error
**Solution**:
- Use staging environment for testing
- Wait for rate limit to reset (Let's Encrypt: 1 week)
- Check existing certificates at https://crt.sh/

#### 5. Certificate Not Loading

**Symptom**: Certificate files exist but not loaded
**Solution**:
- Check file permissions
- Verify PEM format is correct
- Check metadata JSON is valid

## ACME Providers

### Let's Encrypt

- **Staging**: `https://acme-staging-v02.api.letsencrypt.org/directory`
- **Production**: `https://acme-v02.api.letsencrypt.org/directory`
- **Rate Limits**: 50 certificates per domain per week
- **Certificate Validity**: 90 days

### ZeroSSL

- **Staging**: `https://acme.zerossl.com/staging/directory`
- **Production**: `https://acme.zerossl.com/directory`
- **Rate Limits**: Varies by plan
- **Certificate Validity**: 90 days

## Future Enhancements

1. **DNS-01 Challenge**: Support for DNS-based validation (no port 80 required)
2. **ECDSA Keys**: Support for ECDSA certificates (smaller size, faster validation)
3. **Multiple Providers**: Support for additional ACME providers
4. **Key Rotation**: Automatic account key rotation
5. **Metrics**: Prometheus metrics for certificate status
6. **Webhook**: Webhook notifications for certificate events
7. **DER Parsing**: Full DER parsing for key loading (currently uses PEM export/import)

## References

- [ACME v2 RFC 8555](https://datatracker.ietf.org/doc/html/rfc8555)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [ZeroSSL ACME Documentation](https://zerossl.com/documentation/acme/)
- [HTTP-01 Challenge RFC](https://datatracker.ietf.org/doc/html/rfc8555#section-8.3)
