# Trustless Gateway Full Compliance Specification

**Document ID:** `TRUSTLESS_GATEWAY_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.0  
**Priority:** P0 (must ship in v2.0)  
**Derived from:** `SERVICES_APIS_SPEC` §4.3

---

## 1. Goal and Scope

The goal of this specification is to make the dart_ipfs gateway fully compliant with the IPFS Trustless Gateway specification. Programmatic clients (Kubo, Helia, Iroh, custom HTTP tools) must be able to retrieve raw blocks, CAR archives, IPNS records, DAG-JSON, and DAG-CBOR responses by sending the correct `Accept` header or `?format=` query parameter. The gateway must never return an HTML directory listing or a CAR-to-HTML conversion when a trustless format is requested.

Scope includes:

- Detecting and honoring trustless format negotiation for every request.
- Returning raw blocks, CAR v1 archives, IPNS records, DAG-JSON, and DAG-CBOR responses with the correct content types and headers.
- Removing the current CAR-to-HTML conversion path in `ContentTypeHandler._processCarArchive` for trustless requests.
- Preserving existing path-gateway behavior when no trustless format is requested.
- Integration with the content blocking denylist (if enabled) before any trustless response is served.

Out of scope: writable gateway operations, CAR v2, selectors, and IPNS record signing/publishing.

---

## 2. Official References

- [IPFS Trustless Gateway Spec](https://specs.ipfs.tech/http-gateways/trustless-gateway/) — `Accept` and `?format=` negotiation for raw block, CAR, IPNS-record, DAG-JSON, and DAG-CBOR responses.
- [IPFS HTTP Gateway Specs](https://specs.ipfs.tech/http-gateways/) — overall gateway semantics.
- [IPFS Gateway Specification - Path Gateway](https://specs.ipfs.tech/http-gateways/path-gateway/) — default path-gateway behavior when no trustless format is requested.
- [IPLD CAR Specification](https://ipld.io/specs/transport/car/) — CAR v1 archive format, header, and varint-prefixed CID+block frames.
- [IPLD CARv1 Specification](https://ipld.io/specs/transport/car/carv1/) — detailed CAR v1 frame encoding rules.
- [IPLD DAG-JSON Specification](https://ipld.io/specs/codecs/dag-json/spec/) — canonical DAG-JSON encoding.
- [IPLD DAG-CBOR Specification](https://ipld.io/specs/codecs/dag-cbor/spec/) — canonical DAG-CBOR encoding.
- [IPLD DAG-PB Specification](https://ipld.io/specs/codecs/dag-pb/spec/) — UnixFS node structure for DAG-JSON/CBOR representation.
- [IPNS Record Specification](https://specs.ipfs.tech/ipns/ipns-record/) — signed IPNS record format and validation.

---

## 3. Current State in dart_ipfs

The gateway implementation is in `lib/src/services/gateway/gateway_handler.dart` and `lib/src/services/gateway/content_type_handler.dart`.

- `GatewayHandler` always renders directories as HTML and serves files via `_serveFile`/`_serveRaw`. There is no trustless format detection.
- `ContentTypeHandler` detects `application/vnd.ipfs.car` files but `_processCarArchive` converts the CAR bytes into an HTML warning page instead of returning the archive. This breaks programmatic clients that request CAR archives.
- There is no support for `Accept: application/vnd.ipfs.raw-block`, `application/vnd.ipfs.ipns-record`, `application/vnd.ipld.dag-json`, or `application/vnd.ipld.dag-cbor`.
- `GatewayHandler` does not parse `?format=` query parameters.
- CAR responses must be generated with the standard `CarWriter` API defined in `doc/specs/features/CAR_FORMAT_SPEC.md` and approved by `doc/specs/decisions/MAINTAINER_DECISION_CAR_MIGRATION.md`. The old `CAR` class in `lib/src/core/data_structures/car.dart` uses a protobuf-based custom format that is not IPLD CAR v1 compliant and must not be used for gateway CAR responses.

---

## 4. Target State / Requirements

### 4.1 Supported Formats and Content Types

| Format | `?format=` value | `Accept` media type | Response `Content-Type` | Notes |
|--------|------------------|---------------------|-------------------------|-------|
| Raw block | `raw` | `application/vnd.ipfs.raw-block` | `application/vnd.ipfs.raw-block` | Single block bytes; valid for any CID. |
| CAR | `car` | `application/vnd.ipfs.car` | `application/vnd.ipfs.car` | CAR v1 archive rooted at the requested CID. |
| IPNS record | `ipns-record` | `application/vnd.ipfs.ipns-record` | `application/vnd.ipfs.ipns-record` | For `/ipns/<name>` paths; returns signed IPNS record bytes. |
| DAG-JSON | `dag-json` | `application/vnd.ipld.dag-json` | `application/vnd.ipld.dag-json` | DAG node serialized as canonical DAG-JSON. |
| DAG-CBOR | `dag-cbor` | `application/vnd.ipld.dag-cbor` | `application/vnd.ipld.dag-cbor` | DAG node serialized as canonical DAG-CBOR. |

Default (no format negotiation): continue existing path-gateway behavior (HTML directory listings, detected MIME types, etc.).

### 4.2 Negotiation Precedence

1. `?format=<format>` query parameter (highest precedence).
2. `Accept` header media type matching one of the supported media types.
3. Default path-gateway behavior.

If both `?format=` and `Accept` are present, `?format=` wins. If `Accept` contains multiple supported media types, use the first supported match in the header order. If an unsupported media type is requested via `Accept` and no `?format=` is present, fall back to the default path-gateway behavior rather than returning `406 Not Acceptable`.

### 4.3 CAR Response Requirements

- Generate a **CAR v1** archive using the standard `CarWriter` from `CAR_FORMAT_SPEC.md`, with a single root CID equal to the requested CID.
- Include all blocks reachable from the root CID through the requested sub-path (if any) up to the full DAG.
- Use varint-prefixed CID+block frames per the CAR v1 spec.
- Set `Content-Disposition: attachment; filename="<cid>.car"`.
- Do **not** convert CAR data to HTML under any trustless request.
- If the root block is not found locally, attempt Bitswap retrieval before returning `404 Not Found`.
- CAR traversal must be bounded by a configurable maximum DAG depth and/or total block count to avoid unbounded resource consumption for large DAGs; when a bound is exceeded, return `416` Range Not Satisfiable or `413` Payload Too Large per the implementation policy.

### 4.4 Raw Block Response Requirements

- Return the exact block bytes for the requested CID.
- If the CID points to a directory, return the raw encoded DAG-PB bytes (not an HTML listing).
- If the block is not found locally, attempt Bitswap retrieval before returning `404 Not Found`.
- Set `Content-Type: application/vnd.ipfs.raw-block` and `X-IPFS-Path: /ipfs/<cid>`.

### 4.5 IPNS Record Response Requirements

- Only applicable to `/ipns/<name>` paths or `ipns-record` format requests.
- Return the signed IPNS record protobuf bytes (the value stored in the DHT / IPNS store).
- If no record is found, return `404 Not Found` with body `IPNS record not found`.
- Set `Content-Type: application/vnd.ipfs.ipns-record` and `Cache-Control` based on the record TTL.

### 4.6 DAG-JSON / DAG-CBOR Response Requirements

- Decode the requested CID block using the appropriate codec and re-encode as DAG-JSON or DAG-CBOR.
- For UnixFS DAG-PB nodes, return the structured DAG-PB representation (`Data`, `Links`) rather than the raw protobuf bytes.
- For DAG-CBOR nodes, return the re-encoded DAG-CBOR bytes.
- For raw nodes, return the bytes wrapped in the DAG-JSON bytes object or DAG-CBOR bytes major type.
- Set `Content-Type: application/vnd.ipld.dag-json` or `application/vnd.ipld.dag-cbor`.

### 4.7 Internal API Additions

```text
GatewayHandler
  TrustlessFormat? _detectTrustlessFormat(Request request)
  Response _serveRawBlock(CID cid, Request request)
  Future<Response> _serveCar(CID cid, String subPath, Request request)
  Future<Response> _serveIpnsRecord(String name, Request request)
  Future<Response> _serveDagJson(CID cid, Request request)
  Future<Response> _serveDagCbor(CID cid, Request request)

ContentTypeHandler
  must remove _processCarArchive HTML conversion for trustless formats

TrustlessFormat
  raw | car | ipnsRecord | dagJson | dagCbor
```

`_detectTrustlessFormat` must be called early in `handlePath` and `handleSubdomain` before any HTML rendering or MIME detection. If a trustless format is detected, the request bypasses the path-gateway HTML rendering entirely.

---

## 5. Detailed Acceptance Criteria

- [ ] `?format=raw` returns raw block bytes for files and directories.
- [ ] `?format=car` returns a valid CAR v1 archive with the correct root CID and all reachable blocks.
- [ ] `?format=ipns-record` returns the signed IPNS record bytes for `/ipns/` paths.
- [ ] `?format=dag-json` and `?format=dag-cbor` return spec-compliant encoded data.
- [ ] `Accept` header negotiation works for all supported media types.
- [ ] CAR files are never converted to HTML when a trustless format is requested.
- [ ] Directory listings continue to render HTML only when no trustless format is requested.
- [ ] Interop test passes against Kubo: `curl -H "Accept: application/vnd.ipfs.car" http://localhost:8080/ipfs/<cid>` returns a valid CAR.
- [ ] `?format=` takes precedence over `Accept`.
- [ ] Trustless requests for blocked CIDs return `451` when the denylist is enabled.
- [ ] Missing blocks trigger a Bitswap retrieval attempt before returning `404`.

---

## 6. Security Considerations

- Content blocking: when the denylist service is enabled, `GatewayHandler` must check `DenylistService.isBlockedByCidString(cidStr)` before serving any trustless response. Blocked content returns `451 Unavailable For Legal Reasons`.
- Do not execute HTML rendering or MIME detection for trustless requests, because this would expose the gateway to HTML-injection or content-sniffing issues for programmatic clients.
- CAR archives must be served with `Content-Disposition: attachment` to avoid accidental browser execution.
- IPNS record responses must be served as opaque protobuf bytes; do not leak private key material or unvalidated record metadata.
- DAG-JSON/CBOR responses must not expose host paths or internal node state beyond the IPLD data model.
- Range requests on trustless formats are not required; if requested, they may be ignored or honored for raw blocks only.

---

## 7. Testing Strategy

### 7.1 Unit Tests

- `GatewayHandler._detectTrustlessFormat`: query parameter precedence, `Accept` header parsing, multiple media types, unsupported types, default fallback.
- `_serveRawBlock`: correct bytes, directory returns DAG-PB bytes, missing block attempts Bitswap, 404 on failure.
- `_serveCar`: header root CID, included blocks, varint framing, `Content-Disposition`.
- `_serveIpnsRecord`: valid record bytes, 404 when missing.
- `_serveDagJson`/`_serveDagCbor`: DAG-PB structured representation, DAG-CBOR re-encoding, raw bytes wrapping.
- `ContentTypeHandler`: CAR files are no longer converted to HTML when trustless format is detected.
- Denylist interaction on trustless requests.

### 7.2 HTTP Contract Tests

Use `shelf` test handlers or `HttpServerAdapter` mocks to verify:

- `GET /ipfs/<cid>?format=raw` returns `Content-Type: application/vnd.ipfs.raw-block`.
- `GET /ipfs/<cid>?format=car` returns `Content-Type: application/vnd.ipfs.car` and a valid CAR header.
- `GET /ipfs/<cid>` with `Accept: application/vnd.ipld.dag-json` returns canonical DAG-JSON.
- `GET /ipfs/<dir-cid>` with `Accept: application/vnd.ipfs.car` returns a CAR, not HTML.
- `GET /ipfs/<cid>?format=car` with `Accept: text/html` still returns CAR because `?format=` wins.
- `GET /ipfs/<cid>?format=raw` for a blocked CID returns `451` when denylist is enabled.

### 7.3 Interoperability Tests

Spin up a Kubo v0.42.0+ node and a dart_ipfs node in CI and verify:

- Kubo can retrieve a file from dart_ipfs via `/ipfs/<cid>` and via trustless `?format=car`.
- dart_ipfs can retrieve a file from Kubo via the same paths and formats.
- Helia can fetch a CAR archive from the dart_ipfs gateway and verify the root CID.
- A Kubo client can request `application/vnd.ipfs.raw-block` from dart_ipfs and receive the exact block bytes.

---

## 8. Dependencies and Ordering

| Dependency | Reason |
|------------|--------|
| Standard CAR implementation (`CarReader` / `CarWriter` from `CAR_FORMAT_SPEC.md`) | Required for CAR responses; the old `CAR` class in `lib/src/core/data_structures/car.dart` must not be used. |
| Bitswap retrieval | Required for missing-block fallback. |
| IPNS record store / DHT handler | Required for `ipns-record` responses. |
| DAG-JSON and DAG-CBOR codecs | Required for `dag-json`/`dag-cbor` responses. |
| Content blocking / Denylist (P1) | Trustless responses must honor the denylist. |
| Metrics (P0) | Trustless requests must count toward `ipfs_gateway_requests_total`. |

**Implementation order:**

1. Implement `TrustlessFormat` enum and `_detectTrustlessFormat`.
2. Add `_serveRawBlock`, `_serveCar`, `_serveIpnsRecord`, `_serveDagJson`, `_serveDagCbor`.
3. Bypass HTML rendering and `ContentTypeHandler` for trustless requests.
4. Remove CAR-to-HTML conversion for trustless requests.
5. Integrate denylist checks before trustless responses.
6. Add unit, contract, and interop tests.

Trustless gateway is the first Phase 1 P0 foundation item because it unblocks all gateway interop tests and CAR/HTTP client workflows.

---

## 9. Backward Compatibility Notes

- Default path-gateway behavior (HTML directory listings, MIME detection, file serving) remains unchanged when no trustless format is requested.
- The trustless bypass lives in `GatewayHandler`; `ContentTypeHandler` is not currently used by `GatewayHandler._serveContent`. `ContentTypeHandler._processCarArchive` may continue to render CAR files as HTML for non-trustless browser requests, but it must not be invoked when a trustless format is detected.
- Existing public API on `GatewayHandler` is additive only; no method signatures are removed.
- Clients that already request `/ipfs/<cid>` without `Accept` or `?format=` will continue to receive the same HTML or MIME-detected response.
