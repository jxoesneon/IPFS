# Helia Interop Infrastructure - Quick Setup Guide

## What Was Implemented

This guide documents the changes made to set up the Helia interop test infrastructure for wire compatibility testing between dart_ipfs and Helia.

## Files Modified

### 1. test/interop/helia/server.js
**Changes**: Complete rewrite from scaffolding to functional Helia node
- Implemented full libp2p node with TCP, Noise, Yamux, Mplex
- Added DHT, identify, and ping services
- Integrated Helia modules: Bitswap, CAR, HTTP, JSON, Strings
- Added Express HTTP API with Kubo-compatible endpoints:
  - `GET /health` - Health check
  - `GET /api/v0/id` - Node identity (returns peer ID, addresses, agent version)
  - `GET /api/v0/version` - Version info
  - `POST /api/v0/swarm/connect` - Connect to peer
  - `POST /api/v0/add` - Add data as block (strings codec)
  - `GET /api/v0/cat` - Retrieve block (strings codec)

### 2. test/interop/helia/package.json
**Changes**: Updated dependencies
- Added `@chainsafe/libp2p-noise` for connection encryption
- Added `@libp2p/mplex`, `@libp2p/tcp`, `@libp2p/yamux` for libp2p transports
- All Helia modules already present (bitswap, car, http, json, strings)

### 3. test/interop/helia.Dockerfile
**Changes**: Added curl for healthcheck
- Installed curl package for healthcheck support

### 4. test/interop/docker-compose.yml
**Changes**: Helia service configuration
- Added environment variables: `PORT=5001`, `LIBP2P_PORT=4001`
- Added healthcheck using curl to `/health` endpoint
- Removed `profiles: [helia]` so Helia starts by default with other services
- Updated test-runner depends_on to include Helia healthcheck

### 5. test/interop/lib/helia_client.dart (NEW FILE)
**Changes**: Created Dart RPC client for Helia
- Implemented methods: `id()`, `version()`, `swarmConnect()`, `add()`, `cat()`
- Compatible with Helia server's Kubo-like API

### 6. test/interop/bin/setup.dart
**Changes**: Added Helia to bootstrap
- Added HeliaClient initialization
- Added Helia reachability check
- Added Helia to mutual swarm connectivity bootstrap
- Now connects: dart_ipfs ↔ Kubo ↔ Helia (all-to-all)

### 7. test/interop/test/helia_test.dart
**Changes**: Implemented basic tests
- Added server reachability test
- Added version endpoint test
- Added add/retrieve data cycle test
- Kept Bitswap and CAR tests skipped (pending implementation)

### 8. test/interop/README.md (NEW FILE)
**Changes**: Created comprehensive documentation
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

### 9. test/interop/smoke_test.sh (NEW FILE)
**Changes**: Created Linux smoke test script
- Verifies docker-compose services are running
- Checks all service health endpoints
- Tests network connectivity
- Tests API accessibility
- Tests Helia add/cat functionality

### 10. test/interop/smoke_test.bat (NEW FILE)
**Changes**: Created Windows smoke test script
- Same functionality as Linux version for Windows environments

### 11. test/interop/IMPLEMENTATION_STATUS.md (NEW FILE)
**Changes**: Created implementation status document
- Detailed summary of completed work
- List of remaining work items
- Known issues
- Recommendations

## How to Use

### Start the Infrastructure

```bash
cd test/interop
docker-compose up -d
```

### Verify Everything Works

```bash
# Linux/Mac
./smoke_test.sh

# Windows
smoke_test.bat
```

### Run the Bootstrap Script

```bash
docker-compose exec test-runner dart run test/interop/bin/setup.dart
```

### Run Helia Tests

```bash
docker-compose exec test-runner dart test test/interop/test/helia_test.dart
```

### Stop the Infrastructure

```bash
docker-compose down -v
```

## What's Working

✅ Helia server starts successfully with all modules
✅ Healthcheck endpoint responds
✅ Kubo-compatible API endpoints work
✅ Dart client can communicate with Helia
✅ Basic add/retrieve data cycle works
✅ Docker network connectivity works
✅ Bootstrap script includes Helia

## What's Not Yet Working

❌ Helia uses public network (swarm key not configured)
❌ Bitswap interop tests not implemented
❌ CAR interop tests not implemented
❌ DHT interop tests (exist but may fail)
❌ IPNS interop tests (exist but may fail)
❌ Gateway interop tests (exist but may fail)

## Next Steps

1. **Configure Private Swarm Key for Helia**
   - Load swarm.key in Helia server
   - Configure libp2p to use private network
   - This will isolate tests from public network

2. **Implement Bitswap Interop Tests**
   - Verify dart_ipfs Bitswap implementation
   - Add test: Helia adds block, dart_ipfs fetches
   - Add test: dart_ipfs adds block, Helia fetches

3. **Implement CAR Interop Tests**
   - Add CAR export/import to Helia server API
   - Add CAR methods to HeliaClient
   - Add test: Helia exports CAR, dart_ipfs imports
   - Add test: dart_ipfs exports CAR, Helia imports

4. **Verify Existing Tests**
   - Run DHT tests to see if they work
   - Run IPNS tests to see if they work
   - Run Gateway tests to see if they work
   - Fix any issues found

## Architecture

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│   dart_ipfs     │         │      Kubo       │         │     Helia       │
│   (Dart)        │◄────────┤   (Go)          │◄────────┤   (JavaScript)  │
│                 │         │                 │         │                 │
│ Port 4001 (p2p) │         │ Port 4001 (p2p) │         │ Port 4001 (p2p) │
│ Port 5001 (API)│         │ Port 5001 (API) │         │ Port 5001 (API) │
│ Port 8080 (GW)  │         │ Port 8080 (GW)  │         │                 │
└─────────────────┘         └─────────────────┘         └─────────────────┘
       │                           │                           │
       └───────────────────────────┼───────────────────────────┘
                                   │
                      ┌────────────┴────────────┐
                      │  ipfs_interop_net      │
                      │  (private Docker net)   │
                      └─────────────────────────┘
                                   │
                      ┌────────────┴────────────┐
                      │   test-runner           │
                      │   (Dart SDK container)   │
                      └─────────────────────────┘
```

## Service Details

### Helia Server
- **Image**: Built from `test/interop/helia.Dockerfile`
- **Base**: node:20-slim
- **Ports**: 4001 (libp2p), 5001 (HTTP API)
- **Healthcheck**: `curl -f http://localhost:5001/health`
- **Modules**: Bitswap, CAR, HTTP, JSON, Strings
- **API**: Kubo-compatible endpoints

### Network
- **Name**: ipfs_interop_net
- **Type**: Internal (isolated from host)
- **Swarm Key**: Used by Kubo (not yet by Helia)

## Troubleshooting

### Helia Won't Start
```bash
docker-compose logs helia
```

### Healthcheck Failing
```bash
docker-compose exec helia curl http://localhost:5001/health
```

### Can't Connect to Helia
```bash
docker-compose exec test-runner ping helia
docker-compose exec test-runner curl http://helia:5001/api/v0/id
```

### Tests Failing
```bash
# Check if services are healthy
docker-compose ps

# Run bootstrap manually
docker-compose exec test-runner dart run test/interop/bin/setup.dart

# Check logs
docker-compose logs helia
docker-compose logs dart_ipfs
docker-compose logs kubo
```

## CI Integration

Add to your CI workflow:

```yaml
- name: Start interop network
  run: |
    cd test/interop
    docker-compose up -d

- name: Run smoke tests
  run: |
    cd test/interop
    ./smoke_test.sh

- name: Run bootstrap
  run: |
    cd test/interop
    docker-compose exec test-runner dart run test/interop/bin/setup.dart

- name: Run Helia tests
  run: |
    cd test/interop
    docker-compose exec test-runner dart test test/interop/test/helia_test.dart

- name: Cleanup
  if: always()
  run: |
    cd test/interop
    docker-compose down -v
```

## References

- [Helia Documentation](https://github.com/ipfs/helia)
- [Libp2p Documentation](https://docs.libp2p.io/)
- [Bitswap Specification](https://github.com/ipfs/specs/blob/main/bitswap/bitswap.md)
- [CAR Specification](https://github.com/ipfs/car)
