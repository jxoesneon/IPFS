// src/version.dart
/// Package version constants.
///
/// This is the single source of truth for the `dart_ipfs` version string used
/// by the CLI, RPC API, and HTTP gateway. Keep the value in sync with the
/// `version` field in `pubspec.yaml`.
/// The current `dart_ipfs` package version.
const String packageVersion = '1.11.5';

/// The agent version string reported by the node and gateway/rpc endpoints.
const String agentVersion = 'dart_ipfs/$packageVersion';

/// The repository format version reported by the node.
const String repoVersion = '1';
