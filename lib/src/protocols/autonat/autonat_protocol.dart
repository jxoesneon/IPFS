// lib/src/protocols/autonat/autonat_protocol.dart
//
// Spec-compliant AutoNAT protocol implementation for libp2p.
//
// The AutoNAT protocol allows a node to determine its NAT status by asking
// peers to dial back to it. This follows the libp2p AutoNAT specification:
// https://github.com/libp2p/specs/blob/master/autonat/autonat.md
//
// Protocol flow:
// 1. Client sends a DialRequest to a peer with its observed addresses
// 2. Peer attempts to dial back to the client's addresses
// 3. Peer responds with DialResponse indicating success/failure
// 4. Client updates its NAT status based on responses

import 'dart:async';
import 'dart:typed_data';

import '../../core/config/ipfs_config.dart';
import '../../transport/router_interface.dart';
import '../../utils/logger.dart';

/// AutoNAT protocol ID for dial requests.
const String autonatProtocolId = '/ipfs/autonat/1.0.0';

/// NAT status as defined in the AutoNAT spec.
enum NATStatus {
  /// NAT status unknown (not enough data).
  unknown,

  /// Node is publicly reachable (no NAT).
  public,

  /// Node is behind NAT (private).
  private,
}

/// AutoNAT dial request message.
///
/// ```protobuf
/// message DialRequest {
///   repeated bytes addrs = 1;  // Multiaddrs to dial
/// }
/// ```
class DialRequest {
  /// Creates a DialRequest with the given addresses.
  DialRequest({required this.addrs});

  /// List of multiaddr bytes to dial.
  final List<Uint8List> addrs;

  /// Encodes this request to protobuf bytes.
  Uint8List encode() {
    final result = <int>[];
    for (final addr in addrs) {
      // Field 1, length-delimited
      result.addAll(_encodeVarint(10)); // tag: field 1, wire type 2
      result.addAll(_encodeVarint(addr.length));
      result.addAll(addr);
    }
    return Uint8List.fromList(result);
  }

  /// Decodes a DialRequest from protobuf bytes.
  static DialRequest decode(Uint8List bytes) {
    final addrs = <Uint8List>[];
    var offset = 0;

    while (offset < bytes.length) {
      final (tag, tagLen) = _decodeVarint(bytes, offset);
      offset += tagLen;
      final wireType = tag & 0x07;
      final fieldNumber = tag >> 3;

      if (fieldNumber == 1 && wireType == 2) {
        final (length, lenLen) = _decodeVarint(bytes, offset);
        offset += lenLen;
        addrs.add(bytes.sublist(offset, offset + length));
        offset += length;
      } else {
        // Skip unknown fields
        if (wireType == 0) {
          final (_, len) = _decodeVarint(bytes, offset);
          offset += len;
        } else if (wireType == 2) {
          final (length, lenLen) = _decodeVarint(bytes, offset);
          offset += lenLen + length;
        }
      }
    }

    return DialRequest(addrs: addrs);
  }

  static (int, int) _decodeVarint(Uint8List data, int offset) {
    var result = 0;
    var shift = 0;
    var pos = offset;
    while (pos < data.length) {
      final byte = data[pos];
      result |= (byte & 0x7F) << shift;
      pos++;
      if ((byte & 0x80) == 0) {
        return (result, pos - offset);
      }
      shift += 7;
      if (shift > 63) {
        throw FormatException('Varint too long at offset $offset');
      }
    }
    throw FormatException('Truncated varint at offset $offset');
  }

  static List<int> _encodeVarint(int value) {
    final result = <int>[];
    var v = value;
    while (v >= 0x80) {
      result.add((v & 0x7F) | 0x80);
      v >>= 7;
    }
    result.add(v);
    return result;
  }
}

/// AutoNAT dial response status.
enum DialResponseStatus {
  /// Dial succeeded.
  ok,

  /// Dial failed (peer not reachable).
  dialError,

  /// Peer is busy (rate limited).
  dialRefused,
}

/// AutoNAT dial response message.
///
/// ```protobuf
/// message DialResponse {
///   enum Status {
///     OK = 0;
///     DIAL_ERROR = 1;
///     DIAL_REFUSED = 2;
///   }
///   Status status = 1;
///   string statusText = 2;
/// }
/// ```
class DialResponse {
  /// Creates a DialResponse.
  DialResponse({
    required this.status,
    this.statusText,
  });

  /// The dial status.
  final DialResponseStatus status;

  /// Optional human-readable status text.
  final String? statusText;

  /// Encodes this response to protobuf bytes.
  Uint8List encode() {
    final result = <int>[];

    // Field 1: status (varint)
    result.addAll(_encodeVarint(8)); // tag: field 1, wire type 0
    result.addAll(_encodeVarint(status.index));

    // Field 2: statusText (string, optional)
    if (statusText != null) {
      final textBytes = _encodeUtf8(statusText!);
      result.addAll(_encodeVarint(18)); // tag: field 2, wire type 2
      result.addAll(_encodeVarint(textBytes.length));
      result.addAll(textBytes);
    }

    return Uint8List.fromList(result);
  }

  /// Decodes a DialResponse from protobuf bytes.
  static DialResponse decode(Uint8List bytes) {
    DialResponseStatus? status;
    String? statusText;
    var offset = 0;

    while (offset < bytes.length) {
      final (tag, tagLen) = _decodeVarint(bytes, offset);
      offset += tagLen;
      final wireType = tag & 0x07;
      final fieldNumber = tag >> 3;

      if (fieldNumber == 1 && wireType == 0) {
        final (value, len) = _decodeVarint(bytes, offset);
        offset += len;
        status = DialResponseStatus.values[value];
      } else if (fieldNumber == 2 && wireType == 2) {
        final (length, lenLen) = _decodeVarint(bytes, offset);
        offset += lenLen;
        statusText = _decodeUtf8(bytes.sublist(offset, offset + length));
        offset += length;
      } else {
        // Skip unknown fields
        if (wireType == 0) {
          final (_, len) = _decodeVarint(bytes, offset);
          offset += len;
        } else if (wireType == 2) {
          final (length, lenLen) = _decodeVarint(bytes, offset);
          offset += lenLen + length;
        }
      }
    }

    return DialResponse(
      status: status ?? DialResponseStatus.dialError,
      statusText: statusText,
    );
  }

  static (int, int) _decodeVarint(Uint8List data, int offset) {
    var result = 0;
    var shift = 0;
    var pos = offset;
    while (pos < data.length) {
      final byte = data[pos];
      result |= (byte & 0x7F) << shift;
      pos++;
      if ((byte & 0x80) == 0) {
        return (result, pos - offset);
      }
      shift += 7;
      if (shift > 63) {
        throw FormatException('Varint too long at offset $offset');
      }
    }
    throw FormatException('Truncated varint at offset $offset');
  }

  static List<int> _encodeVarint(int value) {
    final result = <int>[];
    var v = value;
    while (v >= 0x80) {
      result.add((v & 0x7F) | 0x80);
      v >>= 7;
    }
    result.add(v);
    return result;
  }

  static List<int> _encodeUtf8(String s) {
    return s.codeUnits;
  }

  static String _decodeUtf8(List<int> bytes) {
    return String.fromCharCodes(bytes);
  }
}

/// AutoNAT service client.
///
/// This service sends dialback requests to peers to determine NAT status.
class AutoNATService {
  /// Creates an AutoNATService.
  AutoNATService(this._router, this._config) {
    _logger = Logger(
      'AutoNATService',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
  }

  final RouterInterface _router;
  final IPFSConfig _config;
  late final Logger _logger;

  NATStatus _natStatus = NATStatus.unknown;
  final List<String> _observedAddrs = [];
  final Map<String, DateTime> _lastDialAttempts = {};

  /// Current NAT status.
  NATStatus get natStatus => _natStatus;

  /// Observed addresses (from identify protocol).
  List<String> get observedAddrs => List.unmodifiable(_observedAddrs);

  /// Updates the observed addresses (called by identify protocol).
  void updateObservedAddrs(List<String> addrs) {
    _observedAddrs.clear();
    _observedAddrs.addAll(addrs);
    _logger.debug('Updated observed addresses: ${addrs.length} addrs');
  }

  /// Performs a dialback test with a specific peer.
  ///
  /// [peerId] - The peer ID to send the dialback request to.
  ///
  /// Returns the NAT status determined from the response.
  Future<NATStatus> performDialback(String peerId) async {
    if (_observedAddrs.isEmpty) {
      _logger.warning('No observed addresses, cannot perform dialback');
      return NATStatus.unknown;
    }

    // Rate limiting: don't spam the same peer
    final lastAttempt = _lastDialAttempts[peerId];
    if (lastAttempt != null &&
        DateTime.now().difference(lastAttempt) < const Duration(minutes: 1)) {
      _logger.debug('Rate limited dialback to $peerId');
      return _natStatus;
    }

    _lastDialAttempts[peerId] = DateTime.now();

    try {
      _logger.debug('Sending dialback request to $peerId');

      // Encode observed addresses as multiaddr bytes
      final addrBytes = _observedAddrs
          .map((addr) => Uint8List.fromList(addr.codeUnits))
          .toList();

      final request = DialRequest(addrs: addrBytes);
      final requestBytes = request.encode();

      // Send request and wait for response
      final responseBytes = await _router.sendMessageWithResponse(
        peerId,
        requestBytes,
        protocolId: autonatProtocolId,
        timeout: const Duration(seconds: 30),
      );

      final response = DialResponse.decode(responseBytes);

      _logger.debug('Received dialback response: ${response.status}');

      // Update NAT status based on response
      if (response.status == DialResponseStatus.ok) {
        _natStatus = NATStatus.public;
        _logger.info('NAT status updated to PUBLIC');
      } else if (response.status == DialResponseStatus.dialError) {
        _natStatus = NATStatus.private;
        _logger.info('NAT status updated to PRIVATE');
      } else {
        _logger.debug('Dialback refused, status unchanged');
      }

      return _natStatus;
    } catch (e, stackTrace) {
      _logger.error('Dialback test failed for $peerId', e, stackTrace);
      return NATStatus.unknown;
    }
  }

  /// Resets the NAT status to unknown.
  void resetStatus() {
    _natStatus = NATStatus.unknown;
    _logger.debug('NAT status reset to UNKNOWN');
  }
}

/// AutoNAT server handler.
///
/// Responds to incoming dialback requests from peers.
class AutoNATServer {
  /// Creates an AutoNATServer.
  AutoNATServer(this._router, this._config) {
    _logger = Logger(
      'AutoNATServer',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
  }

  final RouterInterface _router;
  final IPFSConfig _config;
  late final Logger _logger;

  /// Maximum concurrent dialback requests (rate limiting).
  static const int _maxConcurrentDials = 10;

  /// Current number of active dialback requests.
  int _activeDials = 0;

  /// Starts the AutoNAT server by registering the protocol handler.
  void start() {
    _logger.debug('Starting AutoNAT server...');
    _router.registerProtocolHandler(autonatProtocolId, _handleDialRequest);
    _logger.info('AutoNAT server started');
  }

  /// Stops the AutoNAT server.
  void stop() {
    _logger.debug('Stopping AutoNAT server...');
    _router.unregisterProtocolHandler(autonatProtocolId);
    _logger.info('AutoNAT server stopped');
  }

  /// Handles incoming dialback requests.
  void _handleDialRequest(NetworkPacket packet) {
    _logger.verbose('Received dialback request from ${packet.srcPeerId}');

    // Rate limiting
    if (_activeDials >= _maxConcurrentDials) {
      _logger.warning('Rate limited dialback request from ${packet.srcPeerId}');
      _sendResponse(
        packet.srcPeerId,
        DialResponse(
          status: DialResponseStatus.dialRefused,
          statusText: 'Too many concurrent dials',
        ),
      );
      return;
    }

    try {
      final request = DialRequest.decode(packet.datagram);

      if (request.addrs.isEmpty) {
        _logger.warning('Dialback request has no addresses');
        _sendResponse(
          packet.srcPeerId,
          DialResponse(
            status: DialResponseStatus.dialError,
            statusText: 'No addresses provided',
          ),
        );
        return;
      }

      // Attempt to dial back to the first address
      _activeDials++;
      _attemptDialback(packet.srcPeerId, request.addrs.first).then((success) {
        _activeDials--;
        _sendResponse(
          packet.srcPeerId,
          DialResponse(
            status: success
                ? DialResponseStatus.ok
                : DialResponseStatus.dialError,
            statusText: success ? 'Dialback successful' : 'Dialback failed',
          ),
        );
      });
    } catch (e, stackTrace) {
      _logger.error('Error handling dialback request', e, stackTrace);
      _sendResponse(
        packet.srcPeerId,
        DialResponse(
          status: DialResponseStatus.dialError,
          statusText: 'Invalid request',
        ),
      );
    }
  }

  /// Attempts to dial back to a peer address.
  Future<bool> _attemptDialback(String peerId, Uint8List addrBytes) async {
    try {
      final addr = String.fromCharCodes(addrBytes);
      _logger.debug('Attempting dialback to $addr');

      // Try to connect to the address
      await _router.connect(addr);

      // If we successfully connected, the peer is reachable
      // Disconnect after verification
      await _router.disconnect(addr);

      _logger.debug('Dialback successful to $addr');
      return true;
    } catch (e) {
      _logger.debug('Dialback failed: $e');
      return false;
    }
  }

  /// Sends a dialback response to a peer.
  void _sendResponse(String peerId, DialResponse response) {
    try {
      final responseBytes = response.encode();
      _router.sendMessage(
        peerId,
        responseBytes,
        protocolId: autonatProtocolId,
      );
      _logger.verbose('Sent dialback response to $peerId');
    } catch (e) {
      _logger.error('Error sending dialback response', e);
    }
  }
}
