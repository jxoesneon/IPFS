# Interop Test Infrastructure

This directory contains infrastructure for testing dart_ipfs against Helia (JavaScript IPFS implementation).

## Setup

### 1. Install Node.js dependencies

```bash
cd test/interop/helia
npm install
```

### 2. Generate Swarm Key

The swarm key is used for private network isolation during interop testing. **Do not commit the generated swarm.key file** - it is gitignored for security.

```bash
npm run generate-swarm-key
```

This will generate a new random 95-byte swarm key at `test/interop/swarm.key` using `@libp2p/pnet`'s `generateKey()` function.

### 3. Start Helia Server

```bash
npm start
```

The server will:
- Load the swarm key if available (private network mode)
- Fall back to public network if no swarm key is found
- Listen on port 5001 (HTTP API) and 4001 (libp2p)
- Provide endpoints for Bitswap, CAR, and basic IPFS operations

## Security Note

The swarm key is a pre-shared key (PSK) used to encrypt libp2p connections. Each test environment should generate its own unique key to prevent cross-contamination between test runs. The generated key is never committed to the repository.

## Environment Variables

- `PORT`: HTTP API port (default: 5001)
- `LIBP2P_PORT`: libp2p listen port (default: 4001)
- `BOOTSTRAP_PEERS`: Comma-separated list of bootstrap peers (optional)
