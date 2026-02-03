import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:http/http.dart' as http;

/// A DHT handler that delegates queries to an HTTP IPFS node (e.g. Kubo RPC).
class DelegateDHTHandler implements IDHTHandler {
  /// Creates a [DelegateDHTHandler] using the specified [delegateUrl].
  DelegateDHTHandler(this.delegateUrl, {http.Client? client})
    : _client = client ?? http.Client() {
    _logger = Logger('DelegateDHTHandler');
  }

  /// The URL of the delegate node.
  final String delegateUrl;
  final http.Client _client;

  /// The logger for this handler.
  late final Logger _logger;

  @override
  Future<void> start() async {
    // Sanitize URL for logging (redact potential API keys/secrets)
    final sanitizedUrl = Uri.parse(
      delegateUrl,
    ).replace(userInfo: 'REDACTED').toString();
    _logger.info('Starting DelegateDHTHandler with endpoint: $sanitizedUrl');
  }

  @override
  Future<void> stop() async {
    _client.close();
  }

  @override
  Future<List<V_PeerInfo>> findProviders(CID cid) async {
    try {
      final uri = Uri.parse(
        '$delegateUrl/api/v0/dht/findprovs',
      ).replace(queryParameters: {'arg': cid.encode()});

      final response = await _client.post(uri);

      if (response.statusCode != 200) {
        _logger.warning(
          'Delegate findProviders failed: ${response.statusCode}',
        );
        return [];
      }

      final peers = <V_PeerInfo>[];
      const LineSplitter().convert(response.body).forEach((line) {
        if (line.isNotEmpty) {
          try {
            final json = jsonDecode(line);
            if (json['Type'] == 4 && json['Responses'] != null) {
              for (final resp in (json['Responses'] as List)) {
                if (resp is Map &&
                    resp['ID'] != null &&
                    resp['Addrs'] != null) {
                  // Convert to V_PeerInfo...
                }
              }
            }
          } catch (_) {}
        }
      });
      return peers;
    } catch (e) {
      _logger.error('Error querying delegate for providers', e);
      return [];
    }
  }

  @override
  Future<List<V_PeerInfo>> findPeer(PeerId id) async {
    try {
      final uri = Uri.parse(
        '$delegateUrl/api/v0/dht/findpeer',
      ).replace(queryParameters: {'arg': id.toString()});
      final response = await _client.post(uri);

      if (response.statusCode == 200) {
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Value> getValue(Key key) async {
    try {
      final uri = Uri.parse(
        '$delegateUrl/api/v0/dht/get',
      ).replace(queryParameters: {'arg': key.toString()});

      final response = await _client.post(uri);

      if (response.statusCode == 200) {
        final lines = const LineSplitter().convert(response.body);
        for (final line in lines) {
          if (line.isNotEmpty) {
            final json = jsonDecode(line);
            if (json['Type'] == 5 && json['Extra'] != null) {
              return Value.fromBytes(
                Uint8List.fromList(utf8.encode(json['Extra'] as String)),
              );
            }
          }
        }
      }
      throw Exception('Not found');
    } catch (e) {
      throw Exception('Delegate getValue failed: $e');
    }
  }

  @override
  Future<void> putValue(Key key, Value value) async {
    try {
      final uri = Uri.parse('$delegateUrl/api/v0/dht/put').replace(
        queryParameters: {
          'arg': [key.toString(), value.toString()],
        },
      );

      await _client.post(uri);
    } catch (e) {
      _logger.warning('Delegate putValue failed: $e');
    }
  }

  @override
  Future<void> provide(CID cid) async {
    try {
      final uri = Uri.parse(
        '$delegateUrl/api/v0/dht/provide',
      ).replace(queryParameters: {'arg': cid.encode()});
      await _client.post(uri);
    } catch (e) {
      _logger.warning('Delegate provide failed: $e');
    }
  }

  @override
  Future<void> handleRoutingTableUpdate(V_PeerInfo peer) async {}

  @override
  Future<void> handleProvideRequest(CID cid, PeerId provider) async {}
}

