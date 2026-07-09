// lib/src/services/pinning/cluster_client.dart
//
// IPFS Cluster API client.
//
// IPFS Cluster is a distributed pinset orchestration system for IPFS.
// It coordinates pinning across multiple IPFS daemon nodes with configurable
// replication factors.
//
// A full cluster implementation (with consensus, CRDTs, pin trackers, etc.)
// is not feasible as a single work-package addition. Instead, this module
// implements a cluster-compatible API client that can communicate with an
// existing IPFS Cluster deployment via its REST API.
//
// The IPFS Cluster REST API extends the Pinning Service API with:
//   - Cluster-specific pin options (replication factor, allocations)
//   - Peer management endpoints
//   - Health monitoring
//   - Status tracking across cluster nodes
//
// References:
// - https://ipfscluster.io/documentation/reference/rest_api/
// - https://ipfscluster.io/documentation/deployment/architecture/

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/logger.dart';

/// Replication factor for a cluster pin.
///
/// - `-1` means "pin on all available peers"
/// - `0` means "use default replication factor"
/// - `n > 0` means "pin on at least n peers"
class ReplicationFactor {
  /// Creates a replication factor.
  const ReplicationFactor(this.value);

  /// Pin on all available peers.
  static const ReplicationFactor all = ReplicationFactor(-1);

  /// Use the cluster default.
  static const ReplicationFactor defaultFactor = ReplicationFactor(0);

  /// Pin on at least [n] peers.
  static ReplicationFactor min(int n) => ReplicationFactor(n);

  /// The numeric value of the replication factor.
  final int value;

  @override
  String toString() => value.toString();
}

/// Options for a cluster pin operation.
class ClusterPinOptions {
  /// Creates cluster pin options.
  const ClusterPinOptions({
    this.name,
    this.replicationFactor = ReplicationFactor.defaultFactor,
    this.allocations = const [],
    this.userAllocations = const [],
    this.origins = const [],
    this.meta = const {},
    this.mode = ClusterPinMode.pin,
  });

  /// Optional human-readable name.
  final String? name;

  /// Replication factor (min peers to pin on).
  final ReplicationFactor replicationFactor;

  /// Specific peer IDs to allocate the pin to.
  final List<String> allocations;

  /// User-specified allocations (overrides automatic allocation).
  final List<String> userAllocations;

  /// Origin multiaddrs for fetching content.
  final List<String> origins;

  /// Vendor-specific metadata.
  final Map<String, dynamic> meta;

  /// Pin mode (pin or recursive).
  final ClusterPinMode mode;

  /// Converts to a JSON-serializable map for the Cluster API.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'replication_factor_min': replicationFactor.value,
      'replication_factor_max': replicationFactor.value,
    };
    if (name != null) json['name'] = name;
    if (allocations.isNotEmpty) json['allocations'] = allocations;
    if (userAllocations.isNotEmpty) json['user_allocations'] = userAllocations;
    if (origins.isNotEmpty) json['origins'] = origins;
    if (meta.isNotEmpty) json['meta'] = meta;
    return json;
  }
}

/// Pin mode for cluster operations.
enum ClusterPinMode {
  /// Standard pin (recursive).
  pin,

  /// Pin without recursing into the DAG.
  shallow,
}

/// Status of a pin across the cluster.
enum ClusterPinStatus {
  /// Pin is queued.
  queued,

  /// Pin is in progress.
  pinning,

  /// Pin is complete on all allocated peers.
  pinned,

  /// Pin failed on one or more peers.
  failed,

  /// Pin is being unpinned.
  unpinning,

  /// Pin has been unpinned.
  unpinned,

  /// Remote pin (managed externally).
  remote,

  /// Unknown status.
  unknown;

  /// Parses a status string.
  static ClusterPinStatus fromString(String? status) {
    switch (status) {
      case 'queued':
        return ClusterPinStatus.queued;
      case 'pinning':
        return ClusterPinStatus.pinning;
      case 'pinned':
        return ClusterPinStatus.pinned;
      case 'failed':
        return ClusterPinStatus.failed;
      case 'unpinning':
        return ClusterPinStatus.unpinning;
      case 'unpinned':
        return ClusterPinStatus.unpinned;
      case 'remote':
        return ClusterPinStatus.remote;
      default:
        return ClusterPinStatus.unknown;
    }
  }

  /// Converts to API string.
  String toApiString() => name;
}

/// A pin tracked by the IPFS Cluster.
class ClusterPin {
  /// Creates a [ClusterPin].
  ClusterPin({
    required this.cid,
    required this.status,
    this.name,
    this.allocations = const [],
    this.replicationFactorMin = 0,
    this.replicationFactorMax = 0,
    this.peerMap = const {},
    this.meta = const {},
  });

  /// Parses from a JSON map.
  factory ClusterPin.fromJson(Map<String, dynamic> json) {
    final peerMapRaw = json['peer_map'] as Map<String, dynamic>? ?? {};
    final peerMap = <String, ClusterPeerInfo>{};
    for (final entry in peerMapRaw.entries) {
      peerMap[entry.key] = ClusterPeerInfo.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }

    return ClusterPin(
      cid: json['cid'] as String? ?? '',
      status: ClusterPinStatus.fromString(json['status'] as String?),
      name: json['name'] as String?,
      allocations:
          (json['allocations'] as List?)?.map((e) => e as String).toList() ??
          [],
      replicationFactorMin: json['replication_factor_min'] as int? ?? 0,
      replicationFactorMax: json['replication_factor_max'] as int? ?? 0,
      peerMap: peerMap,
      meta: (json['meta'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// The CID of the pinned content.
  final String cid;

  /// Overall cluster pin status.
  final ClusterPinStatus status;

  /// Optional name.
  final String? name;

  /// Allocated peer IDs.
  final List<String> allocations;

  /// Minimum replication factor.
  final int replicationFactorMin;

  /// Maximum replication factor.
  final int replicationFactorMax;

  /// Per-peer pin status.
  final Map<String, ClusterPeerInfo> peerMap;

  /// Additional metadata.
  final Map<String, dynamic> meta;

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'cid': cid,
    'status': status.toApiString(),
    if (name != null) 'name': name,
    'allocations': allocations,
    'replication_factor_min': replicationFactorMin,
    'replication_factor_max': replicationFactorMax,
    'peer_map': peerMap.map((k, v) => MapEntry(k, v.toJson())),
    'meta': meta,
  };
}

/// Pin status for a single peer in the cluster.
class ClusterPeerInfo {
  /// Creates a [ClusterPeerInfo].
  ClusterPeerInfo({
    required this.peerName,
    required this.status,
    this.error = '',
    this.ts = '',
  });

  /// Parses from a JSON map.
  factory ClusterPeerInfo.fromJson(Map<String, dynamic> json) {
    return ClusterPeerInfo(
      peerName: json['peer_name'] as String? ?? '',
      status: ClusterPinStatus.fromString(json['status'] as String?),
      error: json['error'] as String? ?? '',
      ts: json['ts'] as String? ?? '',
    );
  }

  /// The peer name in the cluster.
  final String peerName;

  /// Pin status on this peer.
  final ClusterPinStatus status;

  /// Error message, if any.
  final String error;

  /// Timestamp of last status update.
  final String ts;

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'peer_name': peerName,
    'status': status.toApiString(),
    'error': error,
    'ts': ts,
  };
}

/// Information about a cluster peer.
class ClusterPeer {
  /// Creates a [ClusterPeer].
  ClusterPeer({
    required this.id,
    required this.addresses,
    this.peerName = '',
    this.rpcAddress = '',
    this.version = '',
    this.commit = '',
    this.rpcProtocolVersion = '',
  });

  /// Parses from a JSON map.
  factory ClusterPeer.fromJson(Map<String, dynamic> json) {
    return ClusterPeer(
      id: json['id'] as String? ?? '',
      addresses:
          (json['addresses'] as List?)?.map((e) => e as String).toList() ?? [],
      peerName: json['peer_name'] as String? ?? '',
      rpcAddress: json['rpc'] as String? ?? '',
      version: json['version'] as String? ?? '',
      commit: json['commit'] as String? ?? '',
      rpcProtocolVersion: json['rpc_protocol_version'] as String? ?? '',
    );
  }

  /// The peer ID.
  final String id;

  /// Multiaddresses of the peer.
  final List<String> addresses;

  /// Human-readable peer name.
  final String peerName;

  /// RPC address.
  final String rpcAddress;

  /// Cluster version.
  final String version;

  /// Git commit.
  final String commit;

  /// RPC protocol version.
  final String rpcProtocolVersion;

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'addresses': addresses,
    'peer_name': peerName,
    'rpc': rpcAddress,
    'version': version,
    'commit': commit,
    'rpc_protocol_version': rpcProtocolVersion,
  };
}

/// Cluster health status.
class ClusterHealth {
  /// Creates a [ClusterHealth].
  ClusterHealth({required this.healthy, this.peers = const [], this.error});

  /// Parses from a JSON map.
  factory ClusterHealth.fromJson(Map<String, dynamic> json) {
    return ClusterHealth(
      healthy: json['healthy'] as bool? ?? false,
      peers:
          (json['peers'] as List?)
              ?.map((e) => ClusterPeer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      error: json['error'] as String?,
    );
  }

  /// Whether the cluster is healthy.
  final bool healthy;

  /// List of cluster peers.
  final List<ClusterPeer> peers;

  /// Error message, if unhealthy.
  final String? error;
}

/// Client for the IPFS Cluster REST API.
///
/// Communicates with an existing IPFS Cluster deployment to coordinate
/// distributed pinning across multiple IPFS nodes.
///
/// This is a client-only implementation — it does not implement the cluster
/// consensus or pin tracking logic itself. It requires a running IPFS
/// Cluster deployment to connect to.
class IPFSClusterClient {
  /// Creates an [IPFSClusterClient].
  ///
  /// [endpoint] is the base URL of the IPFS Cluster REST API.
  /// [token] is the optional authentication token (for basic auth or bearer).
  IPFSClusterClient({
    required String endpoint,
    String? token,
    String? username,
    String? password,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 60),
  }) : _endpoint = endpoint,
       _token = token,
       _username = username,
       _password = password,
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout,
       _logger = Logger('IPFSClusterClient');

  final String _endpoint;
  final String? _token;
  final String? _username;
  final String? _password;
  final http.Client _httpClient;
  final Duration _timeout;
  final Logger _logger;

  /// Returns the base endpoint URL.
  String get endpoint => _endpoint;

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    } else if (_username != null && _password != null) {
      final credentials = base64Encode(utf8.encode('$_username:$_password'));
      headers['Authorization'] = 'Basic $credentials';
    }
    return headers;
  }

  /// Pins content in the cluster.
  ///
  /// [cid] is the content identifier to pin.
  /// [options] specifies cluster-specific pin options like replication factor.
  Future<ClusterPin> pin(String cid, {ClusterPinOptions? options}) async {
    final opts = options ?? const ClusterPinOptions();
    final body = <String, dynamic>{'cid': cid, ...opts.toJson()};

    _logger.debug('Pinning $cid in cluster');

    final response = await _httpClient
        .post(
          Uri.parse('$_endpoint/pins/$cid'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    return _handleClusterPinResponse(response);
  }

  /// Unpins content from the cluster.
  Future<void> unpin(String cid) async {
    _logger.debug('Unpinning $cid from cluster');

    final response = await _httpClient
        .delete(Uri.parse('$_endpoint/pins/$cid'), headers: _headers)
        .timeout(_timeout);

    if (response.statusCode != 200 && response.statusCode != 202) {
      throw Exception(
        'Cluster unpin failed: HTTP ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Gets the status of a pin across the cluster.
  Future<ClusterPin> status(String cid) async {
    _logger.debug('Getting cluster pin status for $cid');

    final response = await _httpClient
        .get(Uri.parse('$_endpoint/pins/$cid'), headers: _headers)
        .timeout(_timeout);

    return _handleClusterPinResponse(response);
  }

  /// Lists all pins in the cluster.
  Future<List<ClusterPin>> listPins() async {
    _logger.debug('Listing cluster pins');

    final response = await _httpClient
        .get(Uri.parse('$_endpoint/pins'), headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((e) => ClusterPin.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (decoded is Map<String, dynamic> && decoded.containsKey('pins')) {
        final pins = decoded['pins'] as List? ?? [];
        return pins
            .map((e) => ClusterPin.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    throw Exception('Cluster list pins failed: HTTP ${response.statusCode}');
  }

  /// Recovers a failed pin across the cluster.
  Future<ClusterPin> recover(String cid) async {
    _logger.debug('Recovering cluster pin $cid');

    final response = await _httpClient
        .post(Uri.parse('$_endpoint/pins/$cid/recover'), headers: _headers)
        .timeout(_timeout);

    return _handleClusterPinResponse(response);
  }

  /// Lists all peers in the cluster.
  Future<List<ClusterPeer>> listPeers() async {
    _logger.debug('Listing cluster peers');

    final response = await _httpClient
        .get(Uri.parse('$_endpoint/peers'), headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((e) => ClusterPeer.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    throw Exception('Cluster list peers failed: HTTP ${response.statusCode}');
  }

  /// Gets cluster health status.
  Future<ClusterHealth> health() async {
    _logger.debug('Getting cluster health');

    final response = await _httpClient
        .get(Uri.parse('$_endpoint/health'), headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return ClusterHealth.fromJson(decoded);
      }
    }
    throw Exception('Cluster health check failed: HTTP ${response.statusCode}');
  }

  /// Gets the cluster version.
  Future<String> version() async {
    _logger.debug('Getting cluster version');

    final response = await _httpClient
        .get(Uri.parse('$_endpoint/version'), headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded['version'] as String? ?? 'unknown';
      }
    }
    throw Exception(
      'Cluster version check failed: HTTP ${response.statusCode}',
    );
  }

  /// Syncs the local state with the cluster state for a given CID.
  ///
  /// This triggers the cluster to verify that all allocated peers have the
  /// content pinned and re-pins if necessary.
  Future<ClusterPin> sync(String cid) async {
    _logger.debug('Syncing cluster pin $cid');

    final response = await _httpClient
        .post(Uri.parse('$_endpoint/pins/$cid/sync'), headers: _headers)
        .timeout(_timeout);

    return _handleClusterPinResponse(response);
  }

  /// Status of all pins in the cluster.
  Future<List<ClusterPin>> statusAll() async {
    _logger.debug('Getting status of all cluster pins');

    final response = await _httpClient
        .get(Uri.parse('$_endpoint/pins?filter=all'), headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((e) => ClusterPin.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (decoded is Map<String, dynamic> && decoded.containsKey('pins')) {
        final pins = decoded['pins'] as List? ?? [];
        return pins
            .map((e) => ClusterPin.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    throw Exception('Cluster status all failed: HTTP ${response.statusCode}');
  }

  ClusterPin _handleClusterPinResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 202) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return ClusterPin.fromJson(decoded);
      }
    }
    throw Exception(
      'Cluster API error: HTTP ${response.statusCode} - ${response.body}',
    );
  }

  /// Releases HTTP resources.
  void dispose() {
    _httpClient.close();
  }
}
