# Helia Interop Infrastructure - Implementation Status

## Summary

The Helia interop test infrastructure has been set up to enable wire compatibility testing between dart_ipfs and Helia. This document details what was implemented and what remains to be done.

## Completed Implementation

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

Implemented basic connectivity tests:
- Server reachability test
- Version endpoint test
- Add/retrieve data cycle test
- (Skipped) Bitswap interop - pending implementation
- (Skipped) CAR interop - pending implementation

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
   - **Status**: ❌ Not implemented
   - **Description**: Implement actual Bitswap block exchange between dart_ipfs and Helia
   - **Impact**: Cannot verify wire compatibility for Bitswap protocol
   - **Implementation**: 
     - Ensure dart_ipfs has working Bitswap implementation
     - Add test that adds block to Helia, fetches via dart_ipfs
     - Add test that adds block to dart_ipfs, fetches via Helia
   - **Location**: `test/interop/test/bitswap_test.dart`, `test/interop/test/helia_test.dart`

3. **CAR Interop Tests**
   - **Status**: ⚠️ Partially Complete
   - **Description**: Implement CAR file import/export between implementations
   - **Impact**: CAR endpoints are implemented on Helia server, but interop tests not yet added
   - **Implementation**:
     - ✅ Added CAR export/import endpoints to Helia server
     - ✅ Tested endpoints locally with curl
     - ❌ Add CAR export/import to RPC clients
     - ❌ Add test that exports CAR from Helia, imports to dart_ipfs
     - ❌ Add test that exports CAR from dart_ipfs, imports to Helia
   - **Location**: `test/interop/test/car_test.dart`, RPC clients

### Medium Priority

4. **DHT Interop Tests**
   - **Status**: ❌ Not implemented
   - **Description**: Test DHT provider/lookup operations
   - **Impact**: Cannot verify DHT wire compatibility
   - **Implementation**: Add DHT provide/lookup tests
   - **Location**: `test/interop/test/dht_test.dart`

5. **IPNS Interop Tests**
   - **Status**: ❌ Not implemented
   - **Description**: Test IPNS publish/resolve operations
   - **Impact**: Cannot verify IPNS wire compatibility
   - **Implementation**: Add IPNS publish/resolve tests
   - **Location**: `test/interop/test/ipns_test.dart`

6. **Gateway Interop Tests**
   - **Status**: ❌ Not implemented
   - **Description**: Test HTTP gateway compatibility
   - **Impact**: Cannot verify gateway behavior
   - **Implementation**: Add gateway tests
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

1. **Bitswap Not Tested**: While the Helia server has Bitswap loaded, actual Bitswap exchange tests are not implemented because dart_ipfs Bitswap implementation may not be complete.

2. **CAR Interop Tests Not Complete**: CAR endpoints are implemented on the Helia server and tested locally, but full interop tests between dart_ipfs and Helia are not yet implemented. The RPC clients need to be updated to support CAR import/export.

3. **Windows Line Endings**: The smoke_test.sh script may have Windows line endings if edited on Windows. Use `dos2unix` or Git's autocrlf settings to manage this.

## Recommendations

### Immediate Actions

1. **Add CAR Support to RPC Clients**: Implement CAR export/import in the Dart RPC clients to enable CAR interop testing.

2. **Implement CAR Interop Tests**: Once RPC clients support CAR, add comprehensive interop tests to verify CAR format compatibility between implementations.

3. **Verify dart_ipfs Bitswap**: Before implementing Bitswap interop tests, verify that dart_ipfs has a working Bitswap implementation that can actually exchange blocks.

### Long-term Actions

1. **CI Integration**: Add the interop tests to the CI pipeline with proper cleanup on failure.

2. **Test Matrix**: Run interop tests against multiple Kubo and Helia versions to ensure backward compatibility.

3. **Performance Benchmarks**: Add performance benchmarks to compare dart_ipfs performance against Kubo and Helia.

4. **Fuzz Testing**: Add protocol fuzz testing to ensure robustness against malformed messages.

## Conclusion

The Helia interop infrastructure is now functional for basic connectivity testing. The Helia server is running with all necessary modules, the Docker network is properly configured, and basic tests are passing. The remaining work focuses on implementing the actual protocol-level interop tests (Bitswap, CAR, DHT, IPNS) and improving test isolation with the private swarm key.
