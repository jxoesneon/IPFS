# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in dart_ipfs, please report it responsibly.

**Email:** [joseeduardox@gmail.com](mailto:joseeduardox@gmail.com)

### Do NOT

- Open a public GitHub issue
- Discuss the vulnerability publicly before it's fixed

### What to Include

- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact assessment
- Suggested fix (optional)

We will acknowledge receipt within 48 hours and provide a timeline for resolution.

## Supported Versions

| Version |          Supported |
| ------- | -----------------: |
| 1.4.x   | :white_check_mark: |
| 1.3.x   | :white_check_mark: |
| < 1.3.0 |                :x: |

## Security Practices

This project implements the following security measures:

### Cryptography

- **Key Storage:** AES-256-GCM encryption with PBKDF2 key derivation (100K iterations)
- **Signatures:** Ed25519 for IPNS records and peer identity
- **Memory Handling:** Sensitive data (keys, seeds) are zeroed after use

### Network Security

- **RPC API:** Optional API key authentication with constant-time comparison
- **Gateway:** Rate limiting (100 req/60s per IP), XSS protection, restricted CORS
- **DHT:** Sybil attack mitigation (max 2 peers per IP), provider rate limiting

### Data Integrity

- **Block Validation:** CID hash verification on all received blocks
- **IPNS Records:** Ed25519 signatures with expiration timestamps
- **PubSub:** HMAC-SHA256 message signing

## Dependency Security

Dependencies are regularly audited. Security-critical overrides are documented in `pubspec.yaml`:

```yaml
dependency_overrides:
  archive: ^3.3.8 # CVE-2023-39139 mitigation
  http: ^1.1.0 # CVE-2020-35669 mitigation
```

## Disclosure Timeline

- **Day 0:** Vulnerability reported
- **Day 1-2:** Acknowledgment sent
- **Day 3-14:** Investigation and fix development
- **Day 15-30:** Coordinated disclosure (if applicable)
- **Day 30+:** Public disclosure with patch release

## Hall of Fame

We appreciate security researchers who help keep dart_ipfs secure:

_No reports yet - be the first!_
