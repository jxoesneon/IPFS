# Secure Runtime Sandbox for dart_ipfs
# Based on Audit Remediation 8.2

# Stage 1: Build
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN mkdir -p bin
RUN dart compile exe example/full_node_example.dart -o bin/ipfs_node

# Stage 2: Runtime (Hardened)
FROM scratch

# Copy compiled binary and runtime dependencies
# (Dart AOT is mostly self-contained, but specialized base images 
# like 'scratch' or 'distroless' might miss glibc if not static. 
# Using google/dart-runtime or debian-slim is safer, lets stick to slim for glibc)
FROM debian:bookworm-slim

# Install libsodium (Required for p2plib crypto)
RUN apt-get update && apt-get install -y libsodium23 && rm -rf /var/lib/apt/lists/*

# Create a non-root user (UID 10001 for safety)
RUN useradd -u 10001 -m ipfsuser

# Create necessary directories and set ownership
RUN mkdir -p /data/ipfs && chown -R 10001:10001 /data/ipfs

# Switch to non-root user
USER 10001:10001

# Copy binary from build stage
COPY --from=build --chown=10001:10001 /app/bin/ipfs_node /app/ipfs_node

# Define volumes
VOLUME ["/data/ipfs"]

# Expose ports (internal only, compose handles binding)
EXPOSE 4001 5001 8080

# Entrypoint
WORKDIR /data/ipfs
ENTRYPOINT ["/app/ipfs_node"]
