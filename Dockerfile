# syntax=docker/dockerfile:1.6
# Multi-stage Dockerfile for dart_ipfs v2.2
# Default runtime: cgr.dev/chainguard/glibc-dynamic (hardened glibc, no shell)
#
# Native dependency note: package:sodium (pubspec.yaml) wraps libsodium which
# requires glibc. The runtime image therefore copies the libsodium dynamic
# library from the Debian-based builder stage into the Chainguard base.
#
# Base image digests should be pinned in CI / Dependabot. Override via:
#   --build-arg BUILDER_IMAGE=dart:stable@sha256:... \
#   --build-arg RUNTIME_IMAGE=cgr.dev/chainguard/glibc-dynamic@sha256:...

ARG BUILDER_IMAGE=dart:stable
ARG RUNTIME_IMAGE=cgr.dev/chainguard/glibc-dynamic
ARG DEBUG_IMAGE=cgr.dev/chainguard/bash

# ---------------------------------------------------------------------------
# Builder stage: compile the CLI and prepare runtime filesystem skeleton
# ---------------------------------------------------------------------------
FROM ${BUILDER_IMAGE} AS builder

WORKDIR /app

# Install libsodium for package:sodium native dependency
# (libsodium-dev pulls in libsodium23 which provides the runtime .so)
RUN apt-get update && \
    apt-get install -y --no-install-recommends libsodium-dev && \
    rm -rf /var/lib/apt/lists/*

# Cache dependencies first for faster rebuilds
COPY pubspec.* ./
RUN dart pub get

# Copy source tree
COPY . .

# Compile the CLI entry point defined in bin/ipfs.dart
RUN mkdir -p build && \
    dart compile exe bin/ipfs.dart -o build/ipfs

# Prepare a skeleton of runtime directories owned by the non-root user.
# /image is used as a staging area so we can COPY only what we need into the
# minimal runtime base without needing a shell there.
RUN mkdir -p /image/data/ipfs /image/tmp /image/etc && \
    echo "ipfs:x:1000:1000:ipfs:/data/ipfs:/nonexistent" > /image/etc/passwd && \
    chown -R 1000:1000 /image && \
    chmod 755 /image /image/data /image/data/ipfs /image/tmp

# ---------------------------------------------------------------------------
# Runtime stage: hardened glibc base, no shell, no package manager
# ---------------------------------------------------------------------------
FROM ${RUNTIME_IMAGE} AS runtime

# OCI labels
LABEL org.opencontainers.image.source="https://github.com/jxoesneon/IPFS"
LABEL org.opencontainers.image.description="dart_ipfs daemon (hardened glibc runtime)"
LABEL org.opencontainers.image.licenses="MIT"

# Copy minimal /etc/passwd entry so the non-root user is named and resolvable
COPY --from=builder --chown=1000:1000 /image/etc/passwd /etc/passwd

# Copy writable directories with non-root ownership
COPY --from=builder --chown=1000:1000 /image/data/ipfs /data/ipfs
COPY --from=builder --chown=1000:1000 /image/tmp /tmp

# Copy the libsodium dynamic library from the Debian-based builder.
# The wildcard covers both amd64 and arm64 library directories.
COPY --from=builder /usr/lib/*-linux-gnu/libsodium.so* /usr/lib/

# Copy the compiled AOT binary
COPY --from=builder --chown=1000:1000 /app/build/ipfs /app/ipfs

# Drop to non-root user (uid=1000, gid=1000)
USER ipfs:ipfs

WORKDIR /data/ipfs

VOLUME ["/data/ipfs", "/tmp"]

# Documented ports: 4001/tcp+udp (libp2p swarm), 5001 (RPC), 8080 (gateway), 8081 (metrics)
EXPOSE 4001/tcp 4001/udp 5001/tcp 8080/tcp 8081/tcp

ENTRYPOINT ["/app/ipfs"]
CMD ["daemon"]

# ---------------------------------------------------------------------------
# Debug stage: shell-enabled troubleshooting variant
# ---------------------------------------------------------------------------
FROM ${DEBUG_IMAGE} AS debug

LABEL org.opencontainers.image.source="https://github.com/jxoesneon/IPFS"
LABEL org.opencontainers.image.description="dart_ipfs daemon (debug shell variant, not for production)"
LABEL org.opencontainers.image.licenses="MIT"

COPY --from=builder --chown=1000:1000 /image/etc/passwd /etc/passwd
COPY --from=builder --chown=1000:1000 /image/data/ipfs /data/ipfs
COPY --from=builder --chown=1000:1000 /image/tmp /tmp
COPY --from=builder /usr/lib/*-linux-gnu/libsodium.so* /usr/lib/
COPY --from=builder --chown=1000:1000 /app/build/ipfs /app/ipfs

USER ipfs:ipfs
WORKDIR /data/ipfs

VOLUME ["/data/ipfs", "/tmp"]

EXPOSE 4001/tcp 4001/udp 5001/tcp 8080/tcp 8081/tcp

ENTRYPOINT ["/app/ipfs"]
CMD ["daemon"]
