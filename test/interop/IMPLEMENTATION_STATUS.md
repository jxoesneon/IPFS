# Helia Interop Infrastructure - Implementation Status

## Summary

The Helia interop test infrastructure has been set up to enable wire compatibility testing between dart_ipfs and Helia. This document details what was implemented and what remains to be done.

## Completed Implementation

### Recent Updates (September 19, 2026)

#### Kubo P0/P1 Scenario Tests Implemented
- **Status**: ✅ Complete
- **Description**: The previously "not implemented" scenario tests now exist and assert real behavior:
  - `test/car_test.dart` — P0 CAR exchange with Kubo in both directions, plus local CAR format roundtrip tests.
  - `test/bitswap_test.dart` — P0 `block get` and `cat` fetches with Kubo in both directions (byte-exact).
  - `test/gateway_test.dart` — P0 trustless gateway (`?format=raw`, `?format=car`) and default response tests.
  - `test/dht_test.dart` — P1 DHT provide/find with Kubo in both directions.
  - `test/ipns_test.dart` — P1 IPNS publish/resolve with Kubo in both directions.
  - `test/helia_test.dart` — Helia connectivity plus CAR and add/cat exchange tests (nightly, non-blocking).
- **Location**: `test/interop/test/`

#### add/cat Coverage and Loud Failure Semantics
- **Status**: ✅ Complete
- **Description**: `DartIpfsClient` and `KuboClient` now expose `add` (multipart `/api/v0/add`, NDJSON) and `cat` (`/api/v0/cat?arg=`) so the P0 `ipfs cat` requirement of `MAINTAINER_DECISION_INTEROP_SCOPE` §4.2 is covered in both directions. Silent-pass early returns on unreachable required hosts were removed — `car_test.dart` and `gateway_test.dart` now fail loudly when Kubo or dart_ipfs is unreachable. Helia remains optional (nightly profile only).
- **Location**: `test/interop/lib/`, `test/interop/test/`

#### P1 → P0 Promotion Tracker
- **Status**: ✅ Complete
- **Description**: `test/interop/PROMOTION_TRACKER.md` now tracks the §4.5 promotion preconditions for DHT/IPNS, including a release-candidate green-run ledger and the current promotion decision record (both remain P1 pending two consecutive green RC cycles and maintainer approval).

### Recent Updates (July 8, 2026)

#### CAR Endpoints Added to Helia Server
- **Status**: ✅ Complete
- **Description**: Added CAR export and import endpoints to the Helia interop server
- **Implementation Details**:
  - Added `GET /api/v0/dag/export` endpoint that exports a DAG as a CAR file
  - Added `POST /api/v0/dag/import` endpoint that imports a CAR file into the blockstore
  - Used `@ipld/car` for CAR file reading/writing
  - Export uses `CarWriter.create()` to stream CAR data to HTTP response
  - Import uses `CarReader.fromBytes()` to parse CAR data from request body
- **Testing**: Endpoints tested locally with curl/PowerShell, successfully exported and imported CAR files
- **Location**: `test/interop/helia/server.js`

#### Private Network Support for Helia
- **Status**: ✅ Complete
- **Description**: Configured Helia to use the private swarm key for isolated interop testing
- **Implementation Details**:
  - Added `@libp2p/pnet` dependency for PSK encryption
  - Implemented swarm key loading from `test/interop/swarm.key`
  - Configured libp2p with `connectionProtector: preSharedKey({ psk: swarmKey })`
  - Generated new valid 95-byte swarm key using `@libp2p/pnet`'s `generateKey()` function
  - Helia now connects to private interop network instead of public IPFS network
- **Impact**: Tests are now isolated from public network conditions, improving determinism and reliability
- **Note**: Default ports changed to 5003 (HTTP) and 4003 (libp2p) to avoid conflicts during local testing
- **Location**: `test/interop/helia/server.js`, `test/interop/swarm.key`

### 1. Helia Server (test/interop/helia/server.js)
**Status**: ✅ Complete

Implemented a full Helia node with:
- Libp2p node with TCP transport, Noise encryption, Yamux/Mplex stream multiplexing
- DHT, identify, and ping services
- Private network support using swarm key (PSK encryption via @libp2p/pnet)
- Helia modules: Bitswap, CAR, JSON, Strings
- Express HTTP API with Kubo-compatible endpoints:
  - `GET /health` - Health check
  - `GET /api/v0/id` - Node identity
  - `GET /api/v0/version` - Version info
  - `POST /api/v0/swarm/connect` - Connect to peer
  - `POST /api/v0/add` - Add data as block
  - `GET /api/v0/cat` - Retrieve block
  - `GET /api/v0/dag/export` - Export DAG as CAR file
  - `POST /api/v0/dag/import` - Import CAR file to blockstore

### 2. Helia Dependencies (test/interop/helia/package.json)
**Status**: ✅ Complete

Updated dependencies to include all required libp2p and Helia modules:
- `@chainsafe/libp2p-noise` - Connection encryption
- `@helia/bitswap` - Bitswap protocol
- `@helia/car` - CAR file handling
- `@helia/json` - JSON codec
- `@helia/strings` - String codec
- `@ipld/car` - CAR file reading/writing utilities
- `@libp2p/mplex` - Stream multiplexing
- `@libp2p/pnet` - Private network support (PSK encryption)
- `@libp2p/tcp` - TCP transport
- `@libp2p/yamux` - Stream multiplexing
- `express` - HTTP server
- `helia` - Core Helia implementation
- `libp2p` - Libp2p core

### 3. Helia Dockerfile (test/interop/helia.Dockerfile)
**Status**: ✅ Complete

Added curl installation for healthcheck support.

### 4. Docker Compose Configuration (test/interop/docker-compose.yml)
**Status**: ✅ Complete

Updated Helia service:
- Added environment variables for PORT and LIBP2P_PORT
- Added healthcheck using curl
- Removed `profiles: [helia]` to start by default
- Updated test-runner to depend on Helia health

### 5. Helia Client (test/interop/lib/helia_client.dart)
**Status**: ✅ Complete

Created Dart RPC client for Helia with methods:
- `id()` - Get node identity
- `version()` - Get version info
- `swarmConnect(multiaddr)` - Connect to peer
- `add(data)` - Add data as block
- `cat(cid)` - Retrieve block

### 6. Bootstrap Script (test/interop/bin/setup.dart)
**Status**: ✅ Complete

Updated to include Helia:
- Added Helia client initialization
- Added Helia reachability check
- Added Helia to swarm connectivity bootstrap
- All three implementations now attempt mutual connections

### 7. Helia Tests (test/interop/test/helia_test.dart)
**Status**: ✅ Complete

Implemented tests:
- Server reachability test
- Version endpoint test
- Add/retrieve data cycle test
- CAR exchange test (export from Helia → import to dart_ipfs, and reverse)
- add/cat exchange test (Helia → dart_ipfs `cat`, dart_ipfs raw block → Helia `cat`)
- Direct Bitswap block exchange between Helia and dart_ipfs remains future work (nightly, non-blocking)

### 8. Documentation (test/interop/README.md)
**Status**: ✅ Complete

Created comprehensive documentation covering:
- Architecture overview with diagram
- Service descriptions
- Usage instructions
- Client library documentation
- Private network configuration
- Helia server implementation details
- Test file descriptions
- Troubleshooting guide
- Future enhancements
- CI integration examples

### 9. Smoke Tests (test/interop/smoke_test.sh, smoke_test.bat)
**Status**: ✅ Complete

Created smoke test scripts for Linux and Windows that verify:
- Docker-compose services are running
- All services are healthy
- Network connectivity between containers
- API endpoints are accessible
- Helia add/cat functionality works

## Remaining Work

### High Priority

1. **Swarm Key for Helia**
   - **Status**: ✅ Complete
   - **Description**: Configure Helia to use the private swarm key
   - **Impact**: Helia now connects to private interop network instead of public network
   - **Implementation**: Added swarm key loading to Helia server, configured libp2p to use private network with @libp2p/pnet
   - **Security**: Swarm key is now generated on-demand via `npm run generate-swarm-key` and gitignored for security
   - **Location**: `test/interop/helia/server.js`, `test/interop/generate_swarm_key.js`, `test/interop/swarm.key` (gitignored)

2. **Bitswap Interop Tests**
   - **Status**: ✅ Complete (Kubo); ⚠️ Partial (Helia)
   - **Description**: Bitswap fetch is verified with Kubo in both directions — `block get` and `cat` — with byte-exact assertions in `test/interop/test/bitswap_test.dart` (P0, release-blocking). Helia add/cat exchange is covered in `test/helia_test.dart`; a direct Helia↔dart_ipfs `block get` Bitswap test remains future work.
   - **Location**: `test/interop/test/bitswap_test.dart`, `test/interop/test/helia_test.dart`

3. **CAR Interop Tests**
   - **Status**: ✅ Complete
   - **Description**: CAR file import/export is verified between implementations
   - **Implementation**:
     - ✅ CAR export/import endpoints on the Helia server
     - ✅ CAR export/import in `DartIpfsClient`, `KuboClient`, and `HeliaClient`
     - ✅ dart_ipfs → Kubo and Kubo → dart_ipfs CAR exchange (`test/car_test.dart`, P0)
     - ✅ Helia ↔ dart_ipfs CAR exchange (`test/helia_test.dart`, nightly)
   - **Location**: `test/interop/test/car_test.dart`, `test/interop/test/helia_test.dart`, RPC clients

### Medium Priority

4. **DHT Interop Tests**
   - **Status**: ✅ Implemented (P1, non-blocking)
   - **Description**: DHT provide/find is tested with Kubo in both directions in `test/interop/test/dht_test.dart`. Runs as the non-blocking `interop-p1` job per `MAINTAINER_DECISION_INTEROP_SCOPE` §4.3; promotion to P0 is tracked in `PROMOTION_TRACKER.md`.
   - **Location**: `test/interop/test/dht_test.dart`

5. **IPNS Interop Tests**
   - **Status**: ✅ Implemented (P1, non-blocking)
   - **Description**: IPNS publish/resolve is tested with Kubo in both directions in `test/interop/test/ipns_test.dart`. Runs as the non-blocking `interop-p1` job; promotion to P0 is tracked in `PROMOTION_TRACKER.md`.
   - **Location**: `test/interop/test/ipns_test.dart`

6. **Gateway Interop Tests**
   - **Status**: ✅ Complete (P0)
   - **Description**: Trustless gateway (`?format=raw`, `?format=car`) and default response are tested against the dart_ipfs gateway in `test/interop/test/gateway_test.dart` (P0, release-blocking).
   - **Location**: `test/interop/test/gateway_test.dart`

### Low Priority

7. **Metrics Export**
   - **Status**: ❌ Not implemented
   - **Description**: Add Prometheus metrics export to Helia server
   - **Impact**: No observability in production
   - **Implementation**: Add prom-client to Helia server
   - **Location**: `test/interop/helia/server.js`

8. **Static Bootstrap Peers**
   - **Status**: ❌ Not implemented
   - **Description**: Configure static bootstrap peers for faster convergence
   - **Impact**: Slower test startup
   - **Implementation**: Add bootstrap peer configuration to libp2p
   - **Location**: `test/interop/helia/server.js`, `test/interop/docker-compose.yml`

## Testing the Implementation

### Prerequisites
- Docker and Docker Compose installed
- dart_ipfs project built

### Steps

1. **Start the infrastructure**:
   ```bash
   cd test/interop
   docker-compose up -d
   ```

2. **Wait for services to be healthy**:
   ```bash
   docker-compose ps
   ```

3. **Run smoke tests**:
   ```bash
   # Linux/Mac
   ./smoke_test.sh
   
   # Windows
   smoke_test.bat
   ```

4. **Run Dart bootstrap**:
   ```bash
   docker-compose exec test-runner dart run test/interop/bin/setup.dart
   ```

5. **Run Helia tests**:
   ```bash
   docker-compose exec test-runner dart test test/interop/test/helia_test.dart
   ```

6. **Stop the infrastructure**:
   ```bash
   docker-compose down -v
   ```

## Known Issues

1. **Helia Direct Bitswap Exchange Not Tested**: Kubo Bitswap fetch (`block get` + `cat`, both directions) is covered by `bitswap_test.dart`, and Helia add/cat exchange is covered by `helia_test.dart`. A direct Helia↔dart_ipfs Bitswap `block get` scenario is still open; the Helia server's `/api/v0/cat` is a raw-block strings endpoint that does not resolve UnixFS DAGs.

2. **Windows Line Endings**: The smoke_test.sh script may have Windows line endings if edited on Windows. Use `dos2unix` or Git's autocrlf settings to manage this.

## Recommendations

### Immediate Actions

1. **Record RC cycles in PROMOTION_TRACKER.md**: After each release candidate, record the `interop-p1` job outcome so DHT/IPNS can accumulate the two consecutive green cycles required for P0 promotion.

2. **Verify Helia↔dart_ipfs Bitswap `block get`**: Extend `helia_test.dart` (or the Helia server endpoints) so a block added to one implementation is fetched directly from the other over Bitswap, mirroring the Kubo P0 coverage.

### Long-term Actions

1. **CI Integration**: ✅ Done — `.github/workflows/interop.yml` runs the P0 (blocking) and P1 (non-blocking) Kubo jobs on PRs touching `lib/src/core/`, `lib/src/protocols/`, `lib/src/services/`, `bin/`, or `test/interop/`; `.github/workflows/interop_nightly.yml` runs the Helia job.

2. **Test Matrix**: Run interop tests against multiple Kubo and Helia versions to ensure backward compatibility.

3. **Performance Benchmarks**: Add performance benchmarks to compare dart_ipfs performance against Kubo and Helia.

4. **Fuzz Testing**: Add protocol fuzz testing to ensure robustness against malformed messages.

## Conclusion

The interop suite now covers the full `MAINTAINER_DECISION_INTEROP_SCOPE` §4.2 matrix: P0 release-blocking CAR, Bitswap (`block get` + `cat` both directions), and gateway tests against Kubo; P1 non-blocking DHT and IPNS tests; and nightly Helia tests. Unreachable required hosts fail loudly rather than silently passing. Remaining work is the Helia direct Bitswap `block get` scenario and accumulating the two consecutive green release-candidate cycles in `PROMOTION_TRACKER.md` before DHT/IPNS can be promoted to P0.
