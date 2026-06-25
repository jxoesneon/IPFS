# Subdomain Gateway Specification

**Document ID:** `SUBDOMAIN_GATEWAY_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.0  
**Priority:** P1 (should ship in v2.0)  
**Derived from:** `SERVICES_APIS_SPEC` §4.2

---

## 1. Goal and Scope

The goal of this specification is to complete the subdomain gateway support in dart_ipfs so that requests to `{cid}.ipfs.{gateway}` and `{name}.ipns.{gateway}` are served according to the IPFS Subdomain Gateway specification. This provides per-CID origin isolation, improves security for browser-based clients, and allows dart_ipfs to be deployed as a public gateway that interoperates with Kubo, Helia, and Iroh clients.

Scope includes:

- Strict host parsing and validation for `ipfs` and `ipns` subdomain requests.
- Optional DNSLink resolution for `.ipns` subdomains.
- Delegation of resolved content to the existing path-gateway/trustless response logic.
- Proper CORS and cache headers for subdomain origins.
- Gateway configuration additions to enable and control the feature.
- Integration with the content blocking denylist (if enabled).

Out of scope: writable subdomain gateway operations, TLS certificate automation, and path-style gateway rewriting for all clients.

---

## 2. Official References

- [IPFS Subdomain Gateway Spec](https://specs.ipfs.tech/http-gateways/subdomain-gateway/) — `{cid}.ipfs.{gateway}` and `{name}.ipns.{gateway}` host parsing, origin isolation, and DNSLink support.
- [IPFS HTTP Gateway Specs](https://specs.ipfs.tech/http-gateways/) — overall gateway semantics including CORS and response headers.
- [IPFS Gateway Specification - Path Gateway](https://specs.ipfs.tech/http-gateways/path-gateway/) — path routing, `index.html` handling, and response headers that remain applicable to subdomain content.
- [IPFS Trustless Gateway Spec](https://specs.ipfs.tech/http-gateways/trustless-gateway/) — trustless `Accept` and `?format=` negotiation that must be preserved when serving subdomain content.
- [DNSLink specification](https://dnslink.dev/) — TXT record format for resolving DNSLink names to IPFS/IPNS paths.
- [Kubo HTTP RPC API reference](https://docs.ipfs.tech/reference/kubo/rpc/) — RPC naming conventions used for IPNS resolution.

---

## 3. Current State in dart_ipfs

The current gateway implementation is in `lib/src/services/gateway/gateway_handler.dart` and `lib/src/services/gateway/gateway_server.dart`.

- `GatewayHandler.handleSubdomain` exists at lines 270–289 but is a partial stub. It only checks for `*.ipfs.*` hosts, parses the first label as a CID string, and delegates to `_serveContent`. It does not validate the CID, support `ipns`, enforce the configured domain, handle DNSLink, or set origin-isolation headers.
- `GatewayConfig` in `lib/src/core/config/gateway_config.dart` has no `gatewayDomain`, `enableSubdomainGateway`, `subdomainDNSLinkResolver`, or `subdomainTLSRedirect` fields.
- `GatewayServer` is assumed to route all requests to `handlePath` by default; the subdomain handler is not wired into the request pipeline before path-gateway fallback.
- `GatewayHandler` has an optional `IpnsResolver` typedef but no DNSLink resolver integration.
- The denylist service does not yet exist, but when it is implemented it must also be checked for subdomain content.

---

## 4. Target State / Requirements

### 4.1 Configuration Additions

Extend `GatewayConfig` in `lib/src/core/config/gateway_config.dart` with:

```text
GatewayConfig
  gatewayDomain: String?          // e.g. "ipfs.example.com"; null means subdomain gateway disabled except localhost
  enableSubdomainGateway: bool    // default false
  subdomainDNSLinkResolver: bool  // default true
  subdomainTLSRedirect: bool      // default true for production domains
```

`GatewayServer` must pass these values to `GatewayHandler` during construction. Default values must keep existing behavior unchanged (subdomain gateway disabled) unless the operator explicitly opts in.

### 4.2 Host Parsing Rules

Given the configured `gatewayDomain` (e.g., `localhost` for local development, or `ipfs.example.com` for production), the handler must parse the request `Host` header:

| Host pattern | Namespace | Identifier | Subpath |
|--------------|-----------|------------|---------|
| `<cid>.ipfs.<gatewayDomain>` | ipfs | valid CID (v0 or v1) | `request.url.path` |
| `<cid>.ipfs.localhost` | ipfs | valid CID | `request.url.path` |
| `<name>.ipns.<gatewayDomain>` | ipns | PeerId, DNSLink domain, or IPNS key | `request.url.path` |

Requirements:

- The host must contain exactly one namespace label (`ipfs` or `ipns`) immediately before the configured domain/TLD.
- For `ipfs`, the leftmost label must be a valid, decodable CID. Invalid CIDs must return `400 Bad Request` with `Content-Type: text/plain; charset=utf-8` and body `Invalid CID in subdomain`.
- For `ipns`, the leftmost label must be either a valid PeerId (base58btc), a DNSLink-compatible DNS name (e.g., `docs.ipfs.io`), or an IPNS key resolved via the configured IPNS resolver. Invalid names return `400 Bad Request`.
- The gateway must reject requests to bare `<gatewayDomain>` that do not match a subdomain namespace; fallback to the path gateway remains handled by the existing `/ipfs/<path|.*>` and `/ipns/<path|.*>` routes.
- Localhost subdomain requests (`*.ipfs.localhost`) must be supported regardless of the configured `gatewayDomain`.

### 4.3 Internal API Additions

```text
GatewayHandler
  Future<Response> handleSubdomain(Request request)
  SubdomainRequest? _parseSubdomainHost(String host)
  CID? _validateSubdomainCid(String cidStr)
  Future<String> _resolveSubdomainIpns(String name)

SubdomainRequest
  String namespace      // "ipfs" | "ipns"
  String identifier
  String subPath
  String gatewayDomain
```

### 4.4 Routing and Response Semantics

- After resolving the identifier to a CID, delegate to the existing `_serveContent(cid, subPath, request)` path, preserving all trustless gateway response logic from the Trustless Gateway specification.
- Set response headers `Access-Control-Allow-Origin: *` (or configured CORS) for subdomain origins.
- Add `X-IPFS-Path: /ipfs/<cid>` or `/ipns/<name>` to responses.
- For IPNS names, add `Cache-Control: public, max-age=<ttl>` where TTL is the resolved IPNS record TTL (default 1 minute if unavailable).
- For DNSLink domains, add `X-IPFS-DNSLink: <domain>` header.
- For production domains where `subdomainTLSRedirect` is true, HTTP requests may be redirected to HTTPS with a `301 Moved Permanently` and `Location: https://<same-host><path>`. This must be configurable and off by default for `localhost`.

### 4.5 DNSLink Resolution

When `subdomainDNSLinkResolver` is true and the leftmost label is a DNS name:

1. Query the `_dnslink.<domain>` TXT record.
2. Parse the record value for `dnslink=/ipfs/<cid>` or `dnslink=/ipns/<name>`.
3. If the value points to `/ipns/<name>`, resolve it via the IPNS resolver.
4. If the value points to `/ipfs/<cid>`, use that CID as the content root.
5. Cache the resolved CID for the TTL returned by the DNS record (minimum 1 minute, maximum 1 hour).
6. On resolution failure, return `400 Bad Request` with body `Invalid IPNS name in subdomain` or a suitable DNS error message.

---

## 5. Detailed Acceptance Criteria

- [ ] `handleSubdomain` is registered in `GatewayServer` for all incoming requests before path-gateway fallback.
- [ ] Valid CID subdomains (`{cid}.ipfs.{gatewayDomain}` and `{cid}.ipfs.localhost`) return the requested content.
- [ ] Invalid CID subdomains return `400 Bad Request` with `Content-Type: text/plain; charset=utf-8` and body `Invalid CID in subdomain`.
- [ ] IPNS subdomains resolve through the configured IPNS resolver and serve content.
- [ ] DNSLink subdomains resolve via `DNSLinkResolver` and serve content.
- [ ] Path-gateway fallback remains unchanged for non-subdomain hosts.
- [ ] All existing gateway tests continue to pass.
- [ ] Trustless `?format=` and `Accept` negotiation works on subdomain requests.
- [ ] Subdomain responses do not set `Access-Control-Allow-Credentials: true`.
- [ ] Blocked content via the denylist returns `451 Unavailable For Legal Reasons` on subdomain requests.
- [ ] The gateway domain is validated against a configurable allow-list to prevent arbitrary `Host` header injection.

---

## 6. Security Considerations

- Origin isolation: subdomain responses must not leak path-gateway cookies or local storage. Each CID or IPNS name receives its own origin.
- `Access-Control-Allow-Credentials` must remain `false` for subdomain origins.
- Host header injection: `gatewayDomain` must be validated against a configurable allow-list. Requests with a `Host` header that does not match the configured domain or `localhost` must fall back to the path gateway or return `400 Bad Request`, never be treated as an arbitrary subdomain.
- CID validation: the leftmost label must be parsed and validated as a CID before any content lookup. Invalid CIDs must not be passed to downstream resolvers.
- DNSLink resolution: DNS responses must be validated and TTL-bound. Avoid cache poisoning by capping TTL and requiring explicit `dnslink=` prefix.
- Denylist: when the content blocking service is enabled, `isBlockedByCidString` must be checked before serving content from any subdomain.
- TLS redirect: only enabled for production domains; `localhost` and unspecified domains must not redirect to HTTPS.

---

## 7. Testing Strategy

### 7.1 Unit Tests

- `GatewayHandler._parseSubdomainHost`: valid and invalid host patterns, `localhost` bypass, missing namespace, multiple namespaces, bare domain.
- `GatewayHandler._validateSubdomainCid`: valid CIDv0, valid CIDv1, invalid strings, empty strings.
- `GatewayHandler._resolveSubdomainIpns`: valid PeerId, DNSLink domain, IPNS key, and failure cases.
- DNSLink resolver mock: TXT parsing, TTL caching, `/ipns` recursion, missing records.
- Trustless format negotiation on subdomain requests.
- Denylist interaction on subdomain requests.

### 7.2 HTTP Contract Tests

Use `shelf` test handlers or `HttpServerAdapter` mocks to verify:

- `GET /` with `Host: <cid>.ipfs.localhost` returns the correct content and `X-IPFS-Path` header.
- `GET /` with `Host: <cid>.ipfs.example.com` returns `400` when `gatewayDomain` is not configured to `ipfs.example.com`.
- `GET /` with `Host: <name>.ipns.example.com` returns content after DNSLink/IPNS resolution.
- `GET /` with `Host: invalid-cid.ipfs.localhost` returns `400`.
- Trustless `Accept: application/vnd.ipfs.car` returns a CAR archive on a subdomain request.
- Blocked CID returns `451` on a subdomain request when denylist is enabled.

### 7.3 Interoperability Tests

Spin up a dart_ipfs gateway and a Kubo/Helia client in CI and verify:

- A Kubo client can fetch `http://<cid>.ipfs.localhost:8080/<path>` from dart_ipfs and receive the same content as from a Kubo gateway.
- A Helia client can fetch a CAR via `Accept: application/vnd.ipfs.car` on a subdomain.
- DNSLink resolution for `docs.ipfs.io` or a test domain matches the result from a Kubo gateway.

---

## 8. Dependencies and Ordering

| Dependency | Reason |
|------------|--------|
| Trustless gateway full compliance (P0) | Subdomain responses must preserve `?format=` and `Accept` negotiation. |
| Gateway configuration additions | `GatewayConfig` must expose subdomain settings. |
| IPNS resolver / DNSLink resolver | Required for `.ipns` subdomain support. |
| Content blocking / Denylist (P1) | Subdomain content must be checked against the denylist. |

**Implementation order:**

1. Add `GatewayConfig` subdomain fields.
2. Implement `GatewayHandler` subdomain parsing and validation.
3. Wire `handleSubdomain` before path-gateway fallback in `GatewayServer`.
4. Add DNSLink and IPNS resolution.
5. Add CORS, cache, and security headers.
6. Add denylist integration.
7. Add unit, contract, and interop tests.

Subdomain gateway is a Phase 2 P1 item that depends on the trustless gateway implementation.

---

## 9. Backward Compatibility Notes

- Subdomain gateway is default-off. Existing path-gateway behavior is unchanged when the feature is disabled.
- `GatewayHandler` constructor remains compatible: the new `gatewayDomain` and resolver parameters are optional.
- `GatewayConfig` new fields have defaults that preserve existing behavior (`enableSubdomainGateway: false`).
- The existing `handlePath` method and its route registrations must remain unchanged.
- If the DNSLink resolver is unavailable, `.ipns` subdomain requests must fail gracefully rather than crashing the gateway.
