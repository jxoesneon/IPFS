// lib/src/core/services/health_check_service.dart
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';

/// Service responsible for monitoring and reporting the health of IPFS node components.
class HealthCheckService {
  /// Creates a [HealthCheckService] for the given [node].
  HealthCheckService(this._node);

  final IPFSNode _node;

  /// Returns a summary health status of the node.
  Future<Map<String, dynamic>> checkHealth() async {
    final detailedStatus = await _node.getHealthStatus();
    
    // Determine overall status
    final isRunning = _node.isRunning;
    final hasErrors = _containsErrors(detailedStatus);
    
    String overallStatus = 'healthy';
    if (!isRunning) {
      overallStatus = 'starting';
    } else if (hasErrors) {
      overallStatus = 'degraded';
    }

    return {
      'status': overallStatus,
      'timestamp': DateTime.now().toIso8601String(),
      'peerId': _node.peerID,
      'version': '1.10.0',
      'uptime_seconds': _node.isRunning ? DateTime.now().difference(_startTime).inSeconds : 0,
      'metrics': {
        'peers': (await _node.connectedPeers).length,

        'blocks': (await _node.blockStore.getStatus())['total_blocks'] ?? 0,
        'pinned': (await _node.blockStore.getStatus())['pinned_blocks'] ?? 0,
      },
      'components': detailedStatus,
    };
  }

  final DateTime _startTime = DateTime.now();

  bool _containsErrors(Map<String, dynamic> status) {
    for (final category in status.values) {
      if (category is Map) {
        for (final component in category.values) {
          if (component is Map && component['status'] == 'error') {
            return true;
          }
        }
      }
    }
    return false;
  }
}
