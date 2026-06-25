# Browser Transport Hardening Specification for dart_ipfs

**Document:** `BROWSER_TRANSPORTS_SPEC.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\features\BROWSER_TRANSPORTS_SPEC.md`  
**Version:** v2.1  
**Date:** 2026-06-25  
**Authority:** Ciel Council of Five verdicts (2026-06-25)  
**Status:** P1 Modified — implementation pending  
**Scope:** WebTransport listener/dialer completion, certhash validation, configurable WebRTC STUN/TURN, and elimination of `UnimplementedError` from `Conn` metadata.

---

## 1. Goal and Scope

### 1.1 Goal

Implement WebTransport IO listener/dialer, validate certhash in the web dialer, replace the hardcoded Google STUN server with configurable STUN/TURN servers, and implement all missing `Conn` metadata without throwing `UnimplementedError`. This makes dart_ipfs viable in browser and browser-adjacent deployments while removing production-inappropriate defaults.

### 1.2 Scope

- WebTransport dialer with certhash validation.
- WebTransport IO listener for non-web platforms.
- WebTransport `Conn` metadata implementation.
- WebRTC configurable STUN/TURN servers.
- WebRTC `Conn` metadata implementation.
- `NetworkConfig` fields for browser transport settings.

### 1.3 Non-Goals

- Full WebRTC maturity is replaced by this hardening effort; advanced WebRTC features are deferred.
- WebSocket transport is assumed to already exist; only WebTransport and WebRTC are addressed here.
- Browser-specific UI integration is out of scope.

---

## 2. Official References

| Spec | URL | Relevance |
|------|-----|-----------|
| libp2p WebTransport transport | https://github.com/libp2p/specs/blob/master/webtransport/README.md | Multiaddr, certhash, security |
| WebTransport API | https://www.w3.org/TR/webtransport/ | Browser API for client/server transport |
| RFC 9000 QUIC | https://datatracker.ietf.org/doc/html/rfc9000 | Underlying WebTransport protocol |
| multiformats / multibase | https://github.com/multiformats/multibase | Certhash multibase decoding |
| WebRTC 1.0 | https://www.w3.org/TR/webrtc/ | Peer connection API |
| ICE (RFC 5245) | https://datatracker.ietf.org/doc/html/rfc5245 | STUN/TURN candidate negotiation |

---

## 3. Current State in dart_ipfs

### 3.1 Files

- WebTransport dialer/listener files (existing but incomplete).
- WebRTC transport implementation (existing but hardcoded STUN).
- `lib/src/core/config/network_config.dart` — no STUN/TURN fields.

### 3.2 Gaps

- WebTransport IO listener and certhash validation are incomplete.
- WebTransport `Conn` metadata throws `UnimplementedError`.
- WebRTC hardcodes Google STUN (`stun:stun.l.google.com:19302`) with no TURN fallback.
- WebRTC connection metadata is incomplete.

---

## 4. Target State / Requirements

### 4.1 WebTransport Protocol IDs

- `/webtransport`
- `/quic-v1/webtransport`

### 4.2 Certhash Validation

When dialing a multiaddr containing `/certhash/<multibase>`:

```dart
bool validateCerthash(WebTransportConnection conn, List<String> expectedCerthashes) {
  final serverCertificateHashes = conn.serverCertificateHashes;
  for (final hash in expectedCerthashes) {
    final decoded = Multibase.decode(hash);
    if (serverCertificateHashes.any((h) => _listEquals(h, decoded))) return true;
  }
  return false;
}
```

If certhash validation fails, close the connection and log a security error.

### 4.3 WebTransport IO Listener

Implement `WebTransportListener` for non-web platforms:

```dart
class WebTransportListener {
  Future<void> listen(String multiaddr);
  Future<void> close();
  Stream<WebTransportConnection> get onConnection;
}
```

The IO listener should bind to a local UDP socket and accept QUIC WebTransport sessions. If platform APIs are unavailable, stub cleanly and return a `NotSupportedException` rather than `UnimplementedError`.

### 4.4 WebTransport Conn Metadata

```dart
class WebTransportConn implements Conn {
  @override
  String get remoteAddr => _connection.remoteAddress;
  @override
  String get localAddr => _connection.localAddress;
  @override
  Future<void> close();
  @override
  Stream<Uint8List> get readable;
  @override
  Future<void> write(Uint8List data);
  @override
  Map<String, dynamic> get metadata => {
    'transport': 'webtransport',
    'security': 'quic',
    'remotePeer': remotePeerId,
  };
}
```

### 4.5 WebRTC Configurable STUN/TURN

Replace `stun:stun.l.google.com:19302` with `NetworkConfig` fields:

```dart
class NetworkConfig {
  ...
  final List<String> stunServers;   // default empty
  final List<TurnServer> turnServers; // default empty
}

class TurnServer {
  final String url;
  final String username;
  final String credential;
}
```

Default STUN should be empty or configurable; do not hardcode Google STUN in production code.

### 4.6 WebRTC Connection Metadata

Implement all `RTCPeerConnection` metadata fields:

```dart
class WebRTCConn implements Conn {
  String get remoteAddr;
  String get localAddr;
  String get transport => 'webrtc';
  Map<String, dynamic> get metadata => {
    'iceState': _pc.iceConnectionState,
    'signalingState': _pc.signalingState,
    'localDescription': _pc.localDescription?.toMap(),
    'remoteDescription': _pc.remoteDescription?.toMap(),
  };
}
```

### 4.7 Configuration

Add to `NetworkConfig`:

```yaml
network:
  stunServers: []
  turnServers:
    - url: "turn:turn.example.com:3478"
      username: "user"
      credential: "pass"
```

---

## 5. Detailed Acceptance Criteria

- WebTransport dialer validates certhash and fails closed on mismatch.
- WebTransport IO listener can accept a connection on a non-web platform (or cleanly report `NotSupportedException`).
- No `UnimplementedError` is thrown from `Conn` metadata.
- WebRTC uses configurable STUN/TURN; no hardcoded Google STUN remains in production code.
- WebRTC metadata includes ICE and signaling state.
- WebTransport listener can be started with `/ip4/0.0.0.0/udp/4002/quic-v1/webtransport`.

---

## 6. Security Considerations

- WebTransport must validate server certhash to prevent MITM attacks. Fail closed on mismatch.
- Do not silently accept WebTransport sessions without certhash when one is specified in the multiaddr.
- WebRTC TURN credentials must be loaded from secure configuration and never logged.
- Avoid hardcoded public STUN servers in production; default to empty STUN so the operator must opt in.
- WebRTC should use DTLS-SRTP for media/data channels as per WebRTC spec; no cleartext data channels.
- Do not expose local interface addresses in browser metadata unless the user has consented.

---

## 7. Testing Strategy

### 7.1 Unit Tests (target coverage ≥80%)

- Certhash multibase decoding and validation success/failure.
- WebTransport multiaddr parsing and listener address synthesis.
- WebTransport `Conn` metadata completeness.
- WebRTC STUN/TURN configuration parsing and ICE server list construction.
- WebRTC `Conn` metadata completeness.
- `NotSupportedException` behavior when platform APIs are unavailable.

### 7.2 Local Network Tests

- Start a local WebTransport-capable peer (Kubo or Helia) and verify dart_ipfs can dial it with a matching certhash.
- Verify certhash mismatch causes immediate connection close.
- Start a WebTransport IO listener on a non-web platform and accept one connection.

### 7.3 Interop Tests with Kubo / Helia

| Scenario | Kubo / Helia Setup | Expected Result |
|----------|-------------------|-----------------|
| WebTransport dial | Kubo with WebTransport listener and known certhash | dart_ipfs dials and completes handshake |
| Certhash mismatch | Use wrong certhash | dart_ipfs closes connection with security error |
| WebRTC with TURN | Helia with TURN server config | dart_ipfs connects via TURN relay |

### 7.4 CI Integration

- Run browser transport tests in CI using headless browser or IO-only tests.
- Add a check that no hardcoded Google STUN string exists in the codebase.

---

## 8. Dependencies and Ordering

### 8.1 Blockers

- QUIC transport must be implemented because WebTransport builds on QUIC.
- Dart WebTransport API or FFI bindings must be available.

### 8.2 Order Relative to Other Features

- **Before**: Browser IPFS deployments, WebRTC-based NAT traversal.
- **Parallel with**: QUIC transport.
- **After**: TCP baseline.

### 8.3 External Dependencies

- WebTransport Dart bindings (`package:webtransport` or browser API wrappers).
- WebRTC Dart bindings (`package:flutter_webrtc` or `package:dart_webrtc` depending on platform).
- `package:multibase` for certhash decoding.

---

## 9. Backward Compatibility Notes

- `NetworkConfig` gains new optional `stunServers` and `turnServers` fields; existing configs continue to work.
- Removal of the hardcoded Google STUN is a behavior change. Nodes that previously relied on it must explicitly configure `stunServers: ['stun:stun.l.google.com:19302']` to retain the old behavior.
- `UnimplementedError` must be replaced by `NotSupportedException` or implemented behavior; this is an API change for callers that catch `UnimplementedError`.
- WebTransport IO listener is additive; existing WebSocket transport is unaffected.
