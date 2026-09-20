#!/usr/bin/env bash
# Generates a libp2p private-network swarm key at test/interop/swarm.key.
# The file is gitignored — every interop run (local or CI) generates a
# fresh key before the docker build so dart_ipfs, Kubo, and Helia all
# share one pnet. Usage: test/interop/generate_swarm_key.sh
set -euo pipefail

KEY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/swarm.key"

if [ -f "$KEY_PATH" ]; then
  echo "swarm.key already exists at $KEY_PATH"
  exit 0
fi

if command -v openssl >/dev/null 2>&1; then
  HEXKEY="$(openssl rand -hex 32)"
elif command -v python3 >/dev/null 2>&1; then
  HEXKEY="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
else
  echo "error: need openssl or python3 to generate a swarm key" >&2
  exit 1
fi

printf '/key/swarm/psk/1.0.0/\n/base16/\n%s\n' "$HEXKEY" > "$KEY_PATH"
echo "wrote $KEY_PATH"
