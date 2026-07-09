# AutoTLS / TLS for WSS Gateway Specification for dart_ipfs

**Document:** `GATEWAY_TLS_SPEC.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\features\GATEWAY_TLS_SPEC.md`  
**Version:** v2.1  
**Date:** 2026-06-25  
**Authority:** Maintainer review (2026-06-25)  
**Status:** P1 Approved — implementation pending  
**Scope:** Optional TLS termination in `GatewayServer` using `SecurityContext` from config, and off-by-default AutoTLS/ACME mode for public gateways.

---

## 1. Goal and Scope

### 1.1 Goal

Enable `GatewayServer` to terminate TLS for HTTPS and WSS gateway traffic, supporting both operator-provided certificates and automatic certificates via ACME. AutoTLS must be off by default and require explicit terms-of-service acceptance before issuance.

### 1.2 Scope

- TLS with `SecurityContext` from PEM certificate and key files.
- AutoTLS/ACME certificate issuance and renewal.
- HTTPS listener on a configurable TLS port.
- Optional HTTP-to-HTTPS redirect server.
- WSS gateway support when TLS is enabled.
- Configuration and runtime status APIs.

### 1.3 Non-Goals

- Mutual TLS (mTLS) client authentication is deferred.
- Custom certificate authority management is out of scope.
- DNS-01 ACME challenge automation is not required; HTTP-01 is the primary challenge type for v2.1.

---

## 2. Official References

| Spec | URL | Relevance |
|------|-----|-----------|
| IPFS HTTP Gateway | https://specs.ipfs.tech/http-gateways/ | Gateway semantics and response formats |
| TLS 1.3 (RFC 8446) | https://datatracker.ietf.org/doc/html/rfc8446 | TLS handshake and cipher requirements |
| ACME (RFC 8555) | https://datatracker.ietf.org/doc/html/rfc8555 | Automatic certificate issuance |
| Let's Encrypt | https://letsencrypt.org/docs/ | ACME provider specifics |
| WebSocket RFC 6455 | https://datatracker.ietf.org/doc/html/rfc6455 | WSS upgrade behavior |

---

## 3. Current State in dart_ipfs

### 3.1 Files

- `lib/src/services/gateway/gateway_server.dart` — current plain HTTP gateway server.
- `lib/src/core/config/gateway_config.dart` — gateway configuration without TLS fields.
- `lib/src/services/gateway/http_gateway_client.dart` — HTTP client (separate from server TLS).

### 3.2 Gaps

- `GatewayConfig` has no TLS fields.
- `GatewayServer` does not support `SecurityContext` or ACME/AutoTLS.
- WSS gateway upgrades are not supported because the server is plain HTTP.

---

## 4. Target State / Requirements

### 4.1 Configuration

Extend `GatewayConfig`:

```dart
class GatewayConfig {
  ...
  final bool enableTls;
  final String? certificatePath;
  final String? privateKeyPath;
  final String? certificatePassword;
  final bool autoTls;
  final String? autoTlsDomain;
  final String? autoTlsEmail;
  final String? autoTlsProvider; // 'letsencrypt', 'zerossl'
  final bool autoTlsAcceptTos;   // default false
  final List<String> autoTlsSANs;
  final int tlsPort;              // default 443
  final bool redirectHttpToHttps; // default false
}
```

YAML/JSON:

```yaml
gateway:
  enabled: true
  port: 8080
  enableTls: true
  certificatePath: /etc/dart_ipfs/cert.pem
  privateKeyPath: /etc/dart_ipfs/key.pem
  # OR
  autoTls: true
  autoTlsDomain: gateway.example.com
  autoTlsEmail: admin@example.com
  autoTlsAcceptTos: true
```

### 4.2 Implementation Requirements

1. On `GatewayServer.start()`, if `enableTls` is true and certificate paths are provided, load them into a `SecurityContext`.
2. If `autoTls` is true, use an ACME client (e.g., `acme_client` package or LEgo-style wrapper) to obtain/renew a certificate for `autoTlsDomain`.
3. Bind the TLS server to `tlsPort` (default 443).
4. Optionally start an HTTP redirect server on `port` that redirects to `https://<autoTlsDomain>:<tlsPort>`.
5. If neither TLS nor AutoTLS is enabled, bind plain HTTP as today.

### 4.3 ACME State Machine

```
[Idle]
  -> autoTls requested
    -> [Acquiring]
      -> challenge accepted
        -> [Validating]
          -> certificate issued
            -> [Active]
              -> renewal due
                -> [Renewing]
```

### 4.4 APIs

```dart
class GatewayServer {
  Future<void> start();
  Future<void> stop();
  Future<bool> isTlsActive();
  Future<DateTime?> certificateExpiry();
}
```

### 4.5 TLS Requirements

- Use TLS 1.2 or higher; disable weak ciphers and SSLv3/TLS 1.0/1.1.
- Load certificates from secure filesystem paths; do not log private keys.
- Support certificate password-protected PEM files.
- If `redirectHttpToHttps` is enabled, the HTTP redirect server must not expose gateway content over plain HTTP.

---

## 5. Detailed Acceptance Criteria

- `GatewayServer` serves HTTPS when `enableTls` is true with valid cert/key.
- AutoTLS obtains a certificate when `autoTlsAcceptTos` is true and the domain is reachable for HTTP-01 validation.
- AutoTLS is off by default and refuses to run if `autoTlsAcceptTos` is false.
- WSS (WebSocket Secure) gateway upgrades work when TLS is enabled.
- Certificate expiry is queryable via `certificateExpiry()`.
- `isTlsActive()` returns true only when the TLS listener is bound and the certificate is loaded.
- HTTP-to-HTTPS redirect works when `redirectHttpToHttps` is true.

---

## 6. Security Considerations

- Load certificates from secure filesystem paths; do not log private keys or certificate passwords.
- AutoTLS must require explicit ToS acceptance; never enable AutoTLS silently.
- Use TLS 1.2+; disable weak ciphers and old protocols.
- Redirect HTTP to HTTPS only when `redirectHttpToHttps` is enabled.
- Protect the ACME challenge endpoint from spoofing; validate it is served on the expected interface.
- Do not expose the admin or certificate issuance APIs to the public gateway port.
- Keep ACME account keys separate from node identity keys.

---

## 7. Testing Strategy

### 7.1 Unit Tests (target coverage ≥80%)

- `GatewayConfig` parsing for TLS and AutoTLS fields.
- `SecurityContext` loading from PEM files and password-protected PEM files.
- AutoTLS state machine transitions.
- `isTlsActive()` and `certificateExpiry()` logic.
- HTTP-to-HTTPS redirect response status and location header.
- Invalid certificate handling (missing file, malformed PEM).

### 7.2 Local Network Tests

- Generate a self-signed certificate and start `GatewayServer` with `enableTls: true`; verify HTTPS responds.
- Start plain HTTP and redirect servers; verify redirect behavior.
- Test WSS upgrade over the TLS listener.

### 7.3 Interop Tests with Kubo / Helia

| Scenario | Command / Client | Expected Result |
|----------|------------------|-----------------|
| HTTPS gateway | `curl -k https://localhost:443/ipfs/<cid>` | HTTPS response with correct content |
| WSS gateway | Browser or ws client connects to `wss://localhost:443` | WebSocket upgrade succeeds |
| AutoTLS staging | Use Let's Encrypt staging server with `autoTlsAcceptTos: true` | Certificate is obtained (in staging environment) |

### 7.4 CI Integration

- Generate self-signed certs in CI for local TLS tests.
- Use Let's Encrypt staging for AutoTLS interop tests (optional, behind a flag).
- Enforce coverage for `lib/src/services/gateway`.

---

## 8. Dependencies and Ordering

### 8.1 Blockers

- `GatewayServer` must support binding with a `SecurityContext`.
- Dart ACME client package or wrapper must be selected.
- WSS upgrade handling must be compatible with TLS sockets.

### 8.2 Order Relative to Other Features

- **Before**: Browser Transport Hardening (WSS gateway support).
- **Parallel with**: Bitswap HTTP Fallback, GraphSync Server.
- **After**: Plain HTTP gateway baseline.

### 8.3 External Dependencies

- `dart:io` `SecurityContext` for TLS termination.
- ACME client package (`acme_client` or custom LE bindings).
- WebSocket server implementation must support secure sockets.

---

## 9. Backward Compatibility Notes

- `GatewayConfig` gains new optional TLS fields; default values are off. Existing plain HTTP gateways continue to work without modification.
- `GatewayServer.start()` behavior is unchanged when TLS is disabled.
- AutoTLS is opt-in and requires explicit ToS acceptance; operators must deliberately enable it.
- The HTTP redirect server is off by default; enabling it may break clients that expect HTTP content on the gateway port.
- No datastore migration is required; certificates are managed externally or by ACME.
