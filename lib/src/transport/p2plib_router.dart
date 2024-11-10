import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';

import '/../src/utils/base58.dart';
import '/../src/core/config/config.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import '../protocols/dht/routing_table.dart';
import 'dart:convert';
import '../protocols/bitswap/message.dart' show Message;
// lib/src/transport/p2plib_router.dart

/// A router implementation using the `p2plib` package.
class P2plibRouter {
  /// Creates a new [P2plibRouter] with the given [config].
  P2plibRouter(this._config)
      : _router = p2p.RouterL2(
          crypto: p2p.Crypto(),
          keepalivePeriod: const Duration(seconds: 30),
        ) {
    // Initialize the router with the provided configuration
    _router.transports.clear(); // Clear existing transports
    _router.transports.add(p2p.TransportUdp(
      bindAddress: p2p.FullAddress(
        address: InternetAddress.anyIPv4,
        port: p2p.TransportUdp.defaultPort,
      ),
      ttl: _router.messageTTL.inSeconds,
    ));
    _router.transports.add(p2p.TransportUdp(
      bindAddress: p2p.FullAddress(
        address: InternetAddress.anyIPv6,
        port: p2p.TransportUdp.defaultPort,
      ),
      ttl: _router.messageTTL.inSeconds,
    ));
    _router.messageTTL = const Duration(minutes: 1);

    // Initialize event controllers
    _connectionEventsController = StreamController<ConnectionEvent>.broadcast();
    _messageEventsController = StreamController<MessageEvent>.broadcast();
    _dhtEventsController = StreamController<DHTEvent>.broadcast();
    _pubSubEventsController = StreamController<PubSubEvent>.broadcast();
    _errorEventsController = StreamController<ErrorEvent>.broadcast();
    _streamEventsController = StreamController<StreamEvent>.broadcast();
  }

  // Modify the initialize method to handle peer ID initialization
  Future<void> initialize() async {
    // Generate random peer ID bytes
    final peerIdBytes = _generateRandomPeerId();
    // Initialize the router with the peer ID
    await _router.init(peerIdBytes);
    // Initialize crypto
    await _router.crypto.init();
  }

  final IPFSConfig _config;
  final p2p.RouterL2 _router;
  RoutingTable? _routingTable;

  late final StreamController<ConnectionEvent> _connectionEventsController;
  late final StreamController<MessageEvent> _messageEventsController;
  late final StreamController<DHTEvent> _dhtEventsController;
  late final StreamController<PubSubEvent> _pubSubEventsController;
  late final StreamController<ErrorEvent> _errorEventsController;
  late final StreamController<StreamEvent> _streamEventsController;

  // Getters for event streams
  Stream<ConnectionEvent> get connectionEvents =>
      _connectionEventsController.stream;
  Stream<MessageEvent> get messageEvents => _messageEventsController.stream;
  Stream<DHTEvent> get dhtEvents => _dhtEventsController.stream;
  Stream<PubSubEvent> get pubSubEvents => _pubSubEventsController.stream;
  Stream<ErrorEvent> get errorEvents => _errorEventsController.stream;
  Stream<StreamEvent> get streamEvents => _streamEventsController.stream;

  // Getter to access the RouterL0 instance
  p2p.RouterL0 get routerL0 => _router;

  /// The peer ID of this node.
  String get peerID => Base58().encode(_router.selfId.value);

  /// The connected peers.
  List<p2p.Route> get connectedPeers => _router.routes.values.toList();

  /// Starts the router.
  Future<void> start() async {
    await _router.start();
    // Connect to bootstrap peers
    for (final peer in _config.bootstrapPeers) {
      try {
        // Use Base58 to decode the peer ID string to bytes first
        final peerIdBytes = Base58().base58Decode(peer);
        final peerId = p2p.PeerId(value: peerIdBytes);

        _router.addPeerAddress(
          peerId: peerId,
          address: p2p.FullAddress(
            address: InternetAddress.anyIPv4,
            port: p2p.TransportUdp.defaultPort,
          ),
          properties: p2p.AddressProperties(),
        );
      } catch (e) {
        print('Error adding bootstrap peer: $e');
      }
    }
  }

  /// Stops the router.
  Future<void> stop() async {
    _router.stop();
    // Close all event controllers
    await _connectionEventsController.close();
    await _messageEventsController.close();
    await _dhtEventsController.close();
    await _pubSubEventsController.close();
    await _errorEventsController.close();
    await _streamEventsController.close();
  }

  /// Connects to a peer using its multiaddress.
  Future<void> connect(String multiaddress) async {
    try {
      final address = parseMultiaddr(multiaddress);
      _router.addPeerAddress(
        peerId: p2p.PeerId(value: _extractPeerIdFromMultiaddr(multiaddress)),
        address: address,
        properties: p2p.AddressProperties(),
      );
      _connectionEventsController.add(
        ConnectionEvent(
          type: ConnectionEventType.connected,
          peerId: multiaddress,
        ),
      );
    } catch (e) {
      _errorEventsController.add(
        ErrorEvent(
          type: ErrorEventType.connectionError,
          message: 'Failed to connect to $multiaddress: $e',
        ),
      );
      rethrow;
    }
  }

  /// Disconnects from a peer.
  Future<void> disconnect(String multiaddress) async {
    try {
      final peerIdBytes = _extractPeerIdFromMultiaddr(multiaddress);
      final peerId = p2p.PeerId(value: peerIdBytes);
      _router.removePeerAddress(peerId);
      _connectionEventsController.add(
        ConnectionEvent(
          type: ConnectionEventType.disconnected,
          peerId: multiaddress,
        ),
      );
    } catch (e) {
      _errorEventsController.add(
        ErrorEvent(
          type: ErrorEventType.disconnectionError,
          message: 'Failed to disconnect from $multiaddress: $e',
        ),
      );
      rethrow;
    }
  }

  /// Lists all connected peers.
  List<String> listConnectedPeers() {
    return connectedPeers.map((route) => route.peerId.toString()).toList();
  }

  /// Sends a message to a peer.
  Future<void> sendMessage(p2p.PeerId peer, Uint8List message) {
    final addresses = _router.resolvePeerId(peer);
    if (addresses.isEmpty) {
      throw Exception('No addresses found for peer ${peer.toString()}');
    }

    _router.sendDatagram(
      addresses: addresses,
      datagram: message,
    );
    return Future.value();
  }

  /// Receives messages from a specific peer.
  Stream<String> receiveMessages(String peerId) async* {
    // Convert the messageStream to filter messages from specific peer
    await for (final message in _router.messageStream) {
      if (message.srcPeerId.toString() == peerId) {
        final payload = message.payload;
        if (payload != null && payload.isNotEmpty) {
          yield utf8.decode(payload);
        }
      }
    }
  }

  /// Resolves a peer ID to a list of addresses.
  List<String> resolvePeerId(p2p.PeerId peerId) {
    return _router
        .resolvePeerId(peerId)
        .map((address) => '${address.address.address}:${address.port}')
        .toList();
  }

  /// Registers a callback for handling incoming messages
  void onMessage(void Function(Message) handler) {
    _router.messageStream.listen((message) async {
      // Check if payload exists before converting
      if (message.payload != null) {
        try {
          final bitswapMessage = await Message.fromBytes(message.payload!);
          handler(bitswapMessage);
        } catch (e) {
          print('Error converting message payload: $e');
        }
      } else {
        print('Received message with null payload, skipping...');
      }
    });
  }

  /// Map to store protocol handlers
  final Map<String, void Function(p2p.Packet)> _protocolHandlers = {};

  /// Adds a message handler for a specific protocol
  void addMessageHandler(String protocolId, void Function(p2p.Packet) handler) {
    if (!_registeredProtocols.contains(protocolId)) {
      throw Exception('Protocol $protocolId not registered');
    }

    _protocolHandlers[protocolId] = handler;

    // Subscribe to the message stream if not already subscribed
    if (_protocolHandlers.length == 1) {
      _router.messageStream.listen((message) {
        // Create a packet from the message
        final packet = p2p.Packet(
          datagram: message.payload ?? Uint8List(0),
          header: message.header,
          srcFullAddress: p2p.FullAddress(
            address: InternetAddress.anyIPv4,
            port: p2p.TransportUdp.defaultPort,
          ),
        );

        // Set the source and destination peer IDs after construction
        packet.srcPeerId = message.srcPeerId;
        packet.dstPeerId = message.dstPeerId;

        // Call the appropriate protocol handler
        for (final handler in _protocolHandlers.values) {
          handler(packet);
        }
      });
    }
  }

  /// Removes a message handler for a specific protocol
  void removeMessageHandler(String protocolId) {
    _protocolHandlers.remove(protocolId);
  }

  /// Sends a datagram to the specified addresses.
  Future<void> sendDatagram({
    required List<String> addresses,
    required Uint8List datagram,
  }) {
    // Convert string addresses to FullAddress objects
    final fullAddresses = addresses.map((addr) {
      final parts = addr.split(':');
      if (parts.length != 2) {
        throw FormatException('Invalid address format: $addr');
      }
      return p2p.FullAddress(
        address: InternetAddress(parts[0]),
        port: int.parse(parts[1]),
      );
    });

    _router.sendDatagram(
      addresses: fullAddresses,
      datagram: datagram,
    );
    return Future.value();
  }

  // Add a set to track registered protocols
  final Set<String> _registeredProtocols = {};

  void registerProtocol(String protocolId) {
    // Add protocol to registered set
    _registeredProtocols.add(protocolId);

    // Optional: Log registration
    print('Registered protocol: $protocolId');
  }

  /// Gets the routing table for DHT operations
  RoutingTable getRoutingTable() {
    // Create a new routing table if it doesn't exist
    _routingTable ??= RoutingTable(
      _router.selfId,
      DHTClient(networkHandler: NetworkHandler(_config)),
    );
    return _routingTable!;
  }

  /// Emits a network event with the given topic and data
  Future<void> emitEvent(String topic, Uint8List data) async {
    // Create a network event message
    final eventMessage = NetworkMessage(data);

    // Broadcast to all connected peers
    for (final route in connectedPeers) {
      try {
        await sendMessage(route.peerId, data);
      } catch (e) {
        print('Error sending event to peer ${route.peerId}: $e');
      }
    }

    // Notify local event handlers if registered
    if (_eventHandlers.containsKey(topic)) {
      for (final handler in _eventHandlers[topic]!) {
        handler(eventMessage);
      }
    }
  }

  final Map<String, List<Function(NetworkMessage)>> _eventHandlers = {};

  /// Registers an event handler for a specific topic
  void onEvent(String topic, Function(NetworkMessage) handler) {
    _eventHandlers.putIfAbsent(topic, () => []).add(handler);
  }

  /// Removes an event handler for a specific topic
  void offEvent(String topic, Function(NetworkMessage) handler) {
    if (_eventHandlers.containsKey(topic)) {
      _eventHandlers[topic]!.remove(handler);
    }
  }

  // Generates a random peer ID
  static Uint8List _generateRandomPeerId() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(32, (i) => random.nextInt(256)));
  }

  /// Parses a multiaddress string into a FullAddress object
  p2p.FullAddress parseMultiaddr(String multiaddr) {
    // Multiaddr format: /ip4/127.0.0.1/tcp/4001/p2p/QmHash...
    final parts = multiaddr.split('/').where((s) => s.isNotEmpty).toList();

    // Extract IP address and port
    String? ipAddress;
    int? port;

    for (var i = 0; i < parts.length; i++) {
      if (parts[i] == 'ip4' || parts[i] == 'ip6') {
        ipAddress = parts[i + 1];
      } else if (parts[i] == 'tcp' || parts[i] == 'udp') {
        port = int.parse(parts[i + 1]);
      }
    }

    if (ipAddress == null || port == null) {
      throw FormatException('Invalid multiaddr format: $multiaddr');
    }

    return p2p.FullAddress(
      address: InternetAddress(ipAddress),
      port: port,
    );
  }

  /// Extracts the peer ID from a multiaddress string
  Uint8List _extractPeerIdFromMultiaddr(String multiaddr) {
    final parts = multiaddr.split('/').where((s) => s.isNotEmpty).toList();
    final peerIdIndex = parts.indexOf('p2p') + 1;
    if (peerIdIndex >= parts.length) {
      throw FormatException('No peer ID found in multiaddr: $multiaddr');
    }
    return Base58().base58Decode(parts[peerIdIndex]);
  }
}

mixin MultiAddressHandler {
  String get multiaddr;
  void setMultiaddr(String addr);
}

class NetworkMessage {
  final Uint8List data;

  NetworkMessage(this.data);

  static NetworkMessage fromBytes(Uint8List bytes) {
    return NetworkMessage(bytes);
  }
}

// Event classes for type-safe event handling
class ConnectionEvent {
  final ConnectionEventType type;
  final String peerId;

  ConnectionEvent({required this.type, required this.peerId});
}

enum ConnectionEventType { connected, disconnected }

class MessageEvent {
  final String peerId;
  final Uint8List message;

  MessageEvent({required this.peerId, required this.message});
}

class DHTEvent {
  final DHTEventType type;
  final Map<String, dynamic> data;

  DHTEvent({required this.type, required this.data});
}

enum DHTEventType { valueFound, providerFound }

class PubSubEvent {
  final String topic;
  final Uint8List message;
  final String publisher;
  final String eventType;

  PubSubEvent({
    required this.topic,
    required this.message,
    required this.publisher,
    required this.eventType,
  });
}

class ErrorEvent {
  final ErrorEventType type;
  final String message;

  ErrorEvent({required this.type, required this.message});
}

enum ErrorEventType { connectionError, disconnectionError, messageError }

class StreamEvent {
  final StreamEventType type;
  final String streamId;
  final Uint8List? data;

  StreamEvent({required this.type, required this.streamId, this.data});
}

enum StreamEventType { opened, closed, data }
