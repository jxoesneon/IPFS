#!/bin/sh
# Initialization script for the Kubo interop peer.
# Mounted at /container-init.d/001-init.sh in the Kubo container.

set -e

if [ ! -f /data/ipfs/config ]; then
  echo "Initializing Kubo repository..."
  ipfs init --profile=test
fi

# Bind API and gateway to all interfaces so they are reachable on the Docker network.
ipfs config Addresses.API "/ip4/0.0.0.0/tcp/5001"
ipfs config Addresses.Gateway "/ip4/0.0.0.0/tcp/8080"

# Use a private swarm key so the interop network is isolated.
if [ -f /key/swarm.key ]; then
  cp /key/swarm.key /data/ipfs/swarm.key
fi

# Disable connection to public bootstrap nodes for a private network.
ipfs config Bootstrap '[]'

# Allow CORS for the test runner.
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["POST", "GET"]'

# Shorten reprovide interval for faster DHT tests.
ipfs config --json Reprovider.Interval '"1m0s"'

# Enable the experimental bitswap HTTP client (if available) for additional test paths.
ipfs config --json Experimental.BitswapHTTPClient true 2>/dev/null || true

# Do not start the daemon here; the Kubo entrypoint will start it.
