# dart_ipfs CLI / Daemon Binary Specification

**Document ID:** `CLI_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.2  
**Status:** Draft specification for implementation  
**Maintainer Priority:** P0 APPROVED  
**Source:** `OPERATIONS_ECOSYSTEM_SPEC` section 4.1

---

## 1. Goal and Scope

The goal of this specification is to provide a first-class, Kubo-compatible command-line interface and daemon binary for `dart_ipfs`. Today the project is consumed only as a library. The v2.2 CLI turns the existing `IPFSNode`, gateway, RPC, and protocol services into a runnable node that can be started locally, embedded in a container, and orchestrated in Kubernetes.

Scope includes:

- A new `bin/ipfs.dart` entry point implementing a command runner.
- Subcommands covering the most common operational surface: daemon, add, cat, ls, pin, id, swarm, config, and version.
- Native compilation support via `dart compile exe` for distribution as a single binary.
- Consistent exit codes, stdout/stderr discipline, and JSON output where practical.
- Localhost-by-default API binding with explicit opt-in for remote exposure.

Out of scope for v2.2:

- Full Kubo flag parity.
- `ipfs files`, `ipfs name`, `ipfs dht`, `ipfs bitswap`, `ipfs block`, `ipfs object`, and `ipfs dag` subcommands (may be thin wrappers but are not required).
- Interactive REPL or shell.

---

## 2. Official References

- Dart command-line conventions: https://dart.dev/tutorials/server/cmdline
- `package:args` command runner: https://pub.dev/packages/args
- Dart package layout, `bin/`: https://dart.dev/tools/pub/package-layout
- Effective Dart (style and API design): https://dart.dev/effective-dart
- Kubo CLI reference (command names, flags, exit codes): https://docs.ipfs.tech/reference/kubo/cli/
- Kubo RPC API (`/api/v0/*`): https://docs.ipfs.tech/reference/kubo/rpc/
- IPFS gateway specs: https://specs.ipfs.tech/http-gateways/
- IPNS record spec: https://specs.ipfs.tech/ipns/ipns-record/
- Bitswap spec: https://specs.ipfs.tech/bitswap/
- libp2p specs: https://docs.libp2p.io/
- CAR format: https://ipld.io/specs/transport/car/
- Dart `dart compile exe`: https://dart.dev/tools/dart-compile

---

## 3. Current State in dart_ipfs

| Area | Current State | Gap |
|------|---------------|-----|
| Binary | No `bin/ipfs.dart` exists. | There is no standalone executable or daemon entry point. |
| UX | Users must embed `IPFSNode` directly in Dart/Flutter code. | No ad-hoc file addition, retrieval, or peer management UX. |
| Config loading | The `IPFSConfig` model exists in `lib/src/core/config/ipfs_config.dart` and supports both JSON and YAML. | The CLI has no `$IPFS_PATH/config.json` default or first-run initialization. |
| Compilation | No release tooling compiles the project to a native binary. | Docker and CI cannot ship a small AOT executable. |
| RPC reuse | RPC handlers under `lib/src/services/rpc/` exist but are only invoked by tests or the library API. | The CLI cannot act as a local client of the in-process node. |

Key files to leverage:

- `lib/src/core/ipfs_node/ipfs_node.dart` — the node lifecycle and service wiring.
- `lib/src/core/builders/ipfs_node_builder.dart` — registers `RPCServer` and `GatewayServer` with `LifecycleManager` when enabled.
- `lib/src/services/rpc/rpc_handlers.dart` — RPC handlers that should be reused by the CLI.
- `lib/src/services/gateway/gateway_server.dart` — gateway server to start in `daemon` mode.
- `lib/src/core/config/ipfs_config.dart` — existing configuration model; canonical on-disk format is JSON, YAML read-fallback is supported.

---

## 4. Target State / Requirements

### 4.1 Entry Point and Compilation

- Create `bin/ipfs.dart`.
- Add `package:args` to `pubspec.yaml` dependencies and use `CommandRunner` with typed subcommand classes.
- Add a `tool/compile_cli.dart` script that invokes `dart compile exe bin/ipfs.dart -o build/ipfs`.
- The compiled binary must be the default entrypoint for the Docker image (see `DOCKER_SPEC.md`).

### 4.2 Repository and Configuration Defaults

- Default repository path: `$IPFS_PATH` or `$HOME/.dart_ipfs` (POSIX) / `%USERPROFILE%\.dart_ipfs` (Windows).
- Default configuration file: `<repo>/config.json`. YAML files (`.yaml`/`.yml`) are accepted as a read-only legacy format.
- Support `--config=<path>` to override the configuration file.
- Initialize the repo directory and a default JSON config on first run if it does not exist.

### 4.3 Subcommands

| Subcommand | Description | Required Flags / Arguments | Exit Codes |
|------------|-------------|---------------------------|------------|
| `daemon` | Start the IPFS node (libp2p, gateway, RPC, DHT, Bitswap). | `--config=<path>`, `--api-addr`, `--gateway-addr`, `--swarm-addr`, `--enable-metrics`, `--enable-pprof` | 0 = clean shutdown, 1 = config error, 2 = bind failure, 130 = SIGINT |
| `add <path>` | Add a file or directory to the local blockstore and return the root CID. | `--recursive`, `--chunker`, `--cid-version`, `--hash`, `--pin`, `--quieter`, `--wrap-with-directory` | 0 = success, 1 = I/O error, 3 = invalid argument |
| `cat <cid>` | Stream a CID (file or raw block) to stdout. | `--output=<path>`, `--offset`, `--length` | 0 = success, 1 = not found, 2 = timeout |
| `ls <cid>` | List directory entries of a CID. | `--resolve-type`, `--size` | 0 = success, 1 = not found / not a directory |
| `pin <subcommand>` | `add`, `rm`, `ls`, `verify`. Pin root CIDs locally. | `--recursive` | 0 = success, 1 = CID missing / not pinned |
| `id` | Print node identity (PeerID, public key, addresses, agent version). | `--format` | 0 = success |
| `swarm <subcommand>` | `peers`, `connect`, `disconnect`, `addrs`, `filters`. | `--listen` (for `addrs`) | 0 = success, 1 = peer not found / connection refused |
| `config <subcommand>` | `show`, `get`, `set` for v2.2; `edit`, `replace`, and `profile` are deferred until the config model is hardened. | `--json`, `--bool` | 0 = success, 1 = invalid key, 2 = I/O error |
| `version` | Print `dart_ipfs` version and supported protocol versions. | `--commit`, `--repo`, `--number`, `--all` | 0 = success |

### 4.4 Output and Logging Discipline

- Command output (CIDs, JSON identity, directory listings) goes to **stdout**.
- Logs and warnings go to **stderr**.
- Support `--enc=json` for machine-readable output where practical.
- All subcommands must implement `--help` and return exit code 0.

### 4.5 Implementation Notes

- Use `package:args` with a `CommandRunner` and typed subcommand classes.
- Share implementation with the existing `/api/v0/*` RPC handlers; the CLI should act as a local client of the in-process node rather than duplicating logic.
- `daemon` must trap `SIGINT` and `SIGTERM` and shut down cleanly (close sockets, flush blockstore, stop DHT). The lifecycle is owned by `IPFSNodeBuilder`; the CLI only applies `--api-addr` / `--gateway-addr` overrides to the config and calls `IPFSNode.start()` / `IPFSNode.stop()`.
- Parse multiaddr strings for `--api-addr`, `--gateway-addr`, and `--swarm-addr` using the existing multiaddr support.
- The `version` string must be sourced from `lib/src/version.dart` (kept in sync with `pubspec.yaml`) and surfaced in both the CLI and RPC/gateway responses.

---

## 5. Detailed Acceptance Criteria

1. `dart run bin/ipfs.dart --help` prints a top-level usage message and lists all subcommands.
2. `dart run bin/ipfs.dart daemon --api-addr /ip4/127.0.0.1/tcp/5001` starts and binds the configured API port; `curl http://127.0.0.1:5001/api/v0/id` returns valid JSON. The builder-managed `RPCServer` and `GatewayServer` are started by the node lifecycle.
3. `dart run bin/ipfs.dart add <file>` returns a parseable CID string matching the file content.
4. `dart run bin/ipfs.dart cat <cid>` streams the exact original bytes to stdout.
5. `dart run bin/ipfs.dart id` outputs a JSON object containing `ID`, `PublicKey`, `Addresses`, and `AgentVersion`.
6. `dart run bin/ipfs.dart config show` outputs the merged configuration as JSON.
7. `dart run bin/ipfs.dart swarm peers` lists connected peers or an empty array.
8. All subcommands return the documented exit codes and respect `--help`.
9. `dart compile exe bin/ipfs.dart -o build/ipfs` produces a working native binary.
10. The Docker image entrypoint invokes the CLI binary with `daemon` as the default command.
11. On first run, the CLI creates the repo directory and writes a default `config.json` that `IPFSConfig.fromFile` can load.
12. `daemon` validates that `--api-addr`, `--gateway-addr`, and `--swarm-addr` are syntactically valid multiaddrs before binding.
13. The `example/cli_dashboard/bin/main.dart` example is treated as a reference UI only; it is not shipped as a competing daemon entry point.

---

## 6. Security Considerations

- The RPC API (`/api/v0`) must bind to `127.0.0.1:5001` by default. Remote binding requires an explicit `--api-addr /ip4/0.0.0.0/tcp/5001` and must print a warning to stderr.
- The gateway is read-only by default. Writable gateway modes must be explicitly enabled via configuration.
- Admin/config subcommands (`config replace`, `config edit`, private key export) must operate only in the local CLI context and must not be exposed through the HTTP API unless separately authorized in a future release.
- CORS defaults must be restrictive. `Access-Control-Allow-Origin: *` is only enabled when explicitly configured.
- Do not print private keys or bootstrap secrets to stdout.
- The `daemon` must reject privilege escalation (e.g., binding to ports <1024 should not silently succeed without documenting required capabilities).

---

## 7. Testing Strategy

### 7.1 Unit Tests

- Test each subcommand class in isolation using in-memory `IPFSNode` and mocked services where appropriate.
- Maintain >=80% line coverage for new CLI code per project policy.
- Test argument parsing edge cases (missing files, invalid CIDs, malformed multiaddrs).

### 7.2 Integration Tests

- Run the CLI against a real in-memory node for `add`, `cat`, `ls`, `pin`, and `id`.
- Verify exit codes and stdout/stderr separation.
- Test JSON output mode with `--enc=json`.

### 7.3 Docker Smoke Tests

- Build the CLI into the Docker image and verify `docker run --rm <image> version`.
- Run `docker run --rm <image> daemon --api-addr /ip4/0.0.0.0/tcp/5001` and confirm `/api/v0/id` responds.

### 7.4 CI Pipeline

- Add or extend `.github/workflows/lint.yml` to run `dart analyze`, `dart format`, and `dart test` on changes to `bin/` and `lib/src/services/rpc/`.
- Add CLI smoke tests to `.github/workflows/docker.yml`.

---

## 8. Dependencies and Ordering

- **Prerequisites:**
  - Stable `IPFSNode` lifecycle (`lib/src/core/ipfs_node/ipfs_node.dart`).
  - `IPFSNodeBuilder` registers `RPCServer` and `GatewayServer` with `LifecycleManager` when enabled (`enableRPC` and `gateway.enabled`).
  - A single version source (`lib/src/version.dart`) kept in sync with `pubspec.yaml`.
  - RPC handlers for `id`, `add`, `cat`, `ls`, `pin`, `swarm`, `config`, and `version` (reuse from `lib/src/services/rpc/`).
  - Gateway and libp2p services functional enough for `daemon` startup.
- **Order:** CLI is the first P0 deliverable in v2.2 because Docker and interop tests depend on it.
- **Downstream consumers:**
  - `DOCKER_SPEC.md` — the runtime image entrypoint.
  - `INTEROP_TESTS_SPEC.md` — the CLI is used to seed and operate nodes in the test network.
  - `KUBERNETES_SPEC.md` — the container command is `ipfs daemon`.

---

## 9. Backward Compatibility Notes

- The CLI is **additive**. Existing library consumers who embed `IPFSNode` directly are not required to migrate.
- The default configuration file is now JSON (`config.json`). YAML files are still accepted as a read-only legacy format.
- Only the public exports of `package:dart_ipfs/dart_ipfs.dart` are guaranteed stable. Deep imports into `lib/src/` are not part of the compatibility contract and may change during v2.2 (see `MODULARIZATION_SPEC.md`).
- No breaking changes to the published package API are introduced by adding `bin/ipfs.dart`.
