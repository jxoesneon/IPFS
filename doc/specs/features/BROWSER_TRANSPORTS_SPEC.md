# WebTransport Browser Dialer + WebRTC STUN/TURN Hardening Specification for dart_ipfs

**Document:** `BROWSER_TRANSPORTS_SPEC.md`  
**Location:** `C:\Users\josee\IPFS\doc\specs\features\BROWSER_TRANSPORTS_SPEC.md`  
**Version:** v2.1  
**Date:** 2026-06-25  
**Authority:** Ciel Council of Five verdicts (2026-06-25)  
**Status:** P1 Modified — implementation pending  
**Scope:** WebTransport browser dialer completion (certhash validation), configurable WebRTC STUN/TURN, and elimination of `UnimplementedError` from `libp2p.Conn` fields (`stat`, `scope`, etc.).

---

## 1. Goal and Scope

### 1.1 Goal

Validate certhash in the browser WebTransport dialer, replace the hardcoded Google STUN server with configurable STUN/TURN servers, and implement all missing `libp2p.Conn` fields (`stat`, `scope`, etc.) without throwing `UnimplementedError`. This makes dart_ipfs viable in browser deployments while removing production-inappropriate defaults. The non-web WebTransport IO listener is deferred to a separate P2 spec because standard Dart/IO does not provide a WebTransport API.

### 1.2 Scope

- WebTransport browser dialer with certhash validation.
- WebTransport `libp2p.Conn` field implementation (`stat`, `scope`, etc.).
- WebRTC configurable STUN/TURN servers.
- WebRTC `libp2p.Conn` field implementation.
- `NetworkConfig` fields for browser transport settings.
- Fixing the dummy certhash value in `lib/src/transport/webtransport/webtransport_dialer_web.dart:31`.

### 1.3 Non-Goals

- Non-web WebTransport IO listener is deferred to a P2 spec; standard Dart/IO does not provide a WebTransport API and no mature dependency exists in the project.
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

- `lib/src/transport/webtransport/webtransport_dialer_web.dart` — browser dialer; currently sets `hash.value = Uint8List(32).toJS` (line 31) instead of the decoded certhash.
- `lib/src/transport/webtransport/webtransport_dialer_io.dart` — IO stub; no production WebTransport API available.
- `lib/src/transport/webtransport/webtransport_listener.dart` — stub listener; non-web WebTransport IO listener is not feasible with current Dart/IO.
- `lib/src/transport/webtransport/webtransport_transport.dart` — transport wrapper.
- `lib/src/transport/webrtc/webrtc_transport.dart` — WebRTC transport; hardcodes Google STUN (`stun:stun.l.google.com:19302`) at lines 71 and 228.
- `lib/src/core/config/network_config.dart` — no STUN/TURN fields.

### 3.2 Gaps

- WebTransport browser dialer does not decode or validate the multiaddr certhash; it passes a dummy 32-byte hash.
- WebTransport `libp2p.Conn` fields (`stat`, `scope`) throw `UnimplementedError`.
- WebRTC hardcodes Google STUN with no TURN fallback.
- WebRTC `libp2p.Conn` fields are incomplete.
- Non-web WebTransport IO listener cannot be implemented with current Dart/IO dependencies and is deferred.

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

### 4.3 WebTransport IO Listener (Deferred)

A non-web `WebTransportListener` is **not** in scope for this specification. Standard Dart/IO does not provide a WebTransport API, and no mature QUIC + WebTransport dependency exists in the project.

- If a browser-only environment is detected, use the browser WebTransport API.
- On non-web platforms, throw `NotSupportedException` from the stub listener and defer a full IO listener to a P2 specification once a dependency is available.

### 4.4 WebTransport Conn Metadata

`WebTransportConnectionWeb` must implement `libp2p.Conn` without throwing `UnimplementedError`. The following fields must be implemented and return sensible values rather than a custom `metadata` map:

```dart
class WebTransportConnectionWeb implements libp2p.Conn {
  @override
  libp2p.PeerId get localPeer;
  @override
  libp2p.PeerId get remotePeer;
  @override
  libp2p.MultiAddr get localMultiaddr;
  @override
  libp2p.MultiAddr get remoteMultiaddr;
  @override
  Future<libp2p.P2PStream<Uint8List>> newStream(libp2p.Context context);
  @override
  Future<void> close();
  @override
  bool get isClosed;
  @override
  libp2p.ConnStats get stat;          // must return real stats, not throw
  @override
  libp2p.ConnScope get scope;         // must return real scope, not throw
  @override
  String get id;
  @override
  Future<libp2p.PublicKey?> get remotePublicKey;
  @override
  libp2p.ConnState get state;
  @override
  Future<List<libp2p.P2PStream<Uint8List>>> get streams;
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

The WebRTC connection wrapper must implement `libp2p.Conn` and return real values for the standard `libp2p.Conn` fields. ICE/signaling state may be exposed as additional read-only properties, but they must not replace the required `libp2p.Conn` API:

```dart
class WebRTCConn implements libp2p.Conn {
  @override
  libp2p.PeerId get localPeer;
  @override
  libp2p.PeerId get remotePeer;
  @override
  libp2p.MultiAddr get localMultiaddr;
  @override
  libp2p.MultiAddr get remoteMultiaddr;
  @override
  Future<libp2p.P2PStream<Uint8List>> newStream(libp2p.Context context);
  @override
  Future<void> close();
  @override
  bool get isClosed;
  @override
  libp2p.ConnStats get stat;          // must return real stats, not throw
  @override
  libp2p.ConnScope get scope;         // must return real scope, not throw
  @override
  String get id;
  @override
  Future<libp2p.PublicKey?> get remotePublicKey;
  @override
  libp2p.ConnState get state;
  @override
  Future<List<libp2p.P2PStream<Uint8List>>> get streams;

  // Additional diagnostics (optional)
  String? get iceConnectionState;
  String? get signalingState;
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

- WebTransport browser dialer decodes the multiaddr certhash, passes the real hash to the browser API, and fails closed on mismatch.
- WebTransport browser dialer rejects the connection when the server certhash does not match the multiaddr.
- No `UnimplementedError` is thrown from `libp2p.Conn` fields (`stat`, `scope`, etc.) on WebTransport or WebRTC connections.
- WebRTC uses configurable STUN/TURN; no hardcoded `stun.l.google.com` string remains in production code.
- WebRTC exposes ICE and signaling state through optional diagnostic properties while still implementing the required `libp2p.Conn` interface.
- The non-web WebTransport IO listener throws `NotSupportedException` and is not a P1 requirement.

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
- WebTransport multiaddr parsing.
- WebTransport `libp2p.Conn` field completeness (`stat`, `scope`, etc.).
- WebRTC STUN/TURN configuration parsing and ICE server list construction.
- WebRTC `libp2p.Conn` field completeness.
- `NotSupportedException` behavior when the non-web WebTransport IO listener is used.

### 7.2 Local Network Tests

- Start a local WebTransport-capable peer (Kubo or Helia) and verify dart_ipfs can dial it with a matching certhash.
- Verify certhash mismatch causes immediate connection close.
- Verify the non-web WebTransport IO listener reports `NotSupportedException` cleanly.

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

- QUIC transport is a prerequisite for WebTransport but is itself blocked on dependency availability (see `QUIC_SPEC.md`).
- A browser Dart WebTransport API wrapper is available via `package:web` / `dart:js_interop`; a non-web IO listener is not available and is deferred.

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
- `UnimplementedError` in `libp2p.Conn` fields must be replaced by implemented values or `NotSupportedException` for genuinely unsupported operations; this is an API change for callers that catch `UnimplementedError`.
- The non-web WebTransport IO listener is deferred; existing WebSocket transport is unaffected.
