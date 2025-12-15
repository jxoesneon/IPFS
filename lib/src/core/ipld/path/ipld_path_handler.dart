// src/core/ipld/path/ipld_path_handler.dart
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';

/// Error for invalid IPLD/IPFS paths.
class IPLDPathError extends IPLDError {
  IPLDPathError(String message) : super('IPLD path error: $message');
}

/// Parses and validates IPFS/IPLD paths.
///
/// Handles paths like `/ipfs/<cid>/path/to/file`.
class IPLDPathHandler {
  static const validNamespaces = {'ipfs', 'ipld', 'ipns'};

  /// Parses and validates an IPFS path
  static (String namespace, CID rootCid, String? remainingPath) parsePath(
    String path,
  ) {
    if (!path.startsWith('/')) {
      throw IPLDPathError('Path must start with /');
    }

    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      throw IPLDPathError('Invalid path format');
    }

    // Validate namespace
    final namespace = parts[0];
    if (!validNamespaces.contains(namespace)) {
      throw IPLDPathError('Invalid namespace: $namespace');
    }

    // Parse CID
    try {
      final cid = CID.decode(parts[1]);
      final remainingPath = parts.length > 2
          ? parts.sublist(2).join('/')
          : null;
      return (namespace, cid, remainingPath);
    } catch (e) {
      throw IPLDPathError('Invalid CID in path: ${parts[1]}');
    }
  }

  /// Normalizes a path according to IPFS standards
  static String normalizePath(String path) {
    // Remove duplicate slashes
    path = path.replaceAll(RegExp(r'/{2,}'), '/');

    // Remove trailing slash unless it's just "/"
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    return path;
  }
}
