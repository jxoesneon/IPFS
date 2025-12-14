# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.2.x   | :white_check_mark: |
| 1.1.x   | :white_check_mark: |
| 1.0.x   | :x:                |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability within dart_ipfs, please follow these steps:

### Do NOT

- Open a public GitHub issue
- Discuss the vulnerability publicly before it's fixed

### Do

1. **Email** the security issue to the maintainers privately
2. Include detailed steps to reproduce the vulnerability
3. Allow reasonable time for a fix before public disclosure

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on complexity (typically 30-90 days)

### Security Measures in dart_ipfs

- **Cryptography**: secp256k1 + ChaCha20-Poly1305 AEAD (128-bit security)
- **Content Verification**: All content verified via CID hashes
- **Peer Authentication**: Encrypted P2P connections
- **Dependencies**: Regularly updated via Dependabot

## Hall of Fame

We appreciate security researchers who help keep dart_ipfs secure:

*No reports yet - be the first!*
