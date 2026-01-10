import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_libp2p/config/config.dart';
import 'package:dart_libp2p/core/crypto/ed25519.dart' as crypto;
import 'package:dart_libp2p/dart_libp2p.dart' as libp2p;
import 'package:dart_libp2p/p2p/host/resource_manager/limiter.dart';
import 'package:dart_libp2p/p2p/host/resource_manager/resource_manager_impl.dart';
import 'package:dart_libp2p/p2p/transport/tcp_transport.dart';
import 'package:p2plib/p2plib.dart' as p2p;

/// Protocol ID for p2plib traffic tunneled over libp2p.
const String p2plibProtocolId = '/p2plib/1.0.0';

/// A transport adapter that bridges p2plib traffic over a libp2p connection.
class Libp2pTransport extends p2p.TransportBase {
  /// Creates a new [Libp2pTransport].
  Libp2pTransport({required super.bindAddress, this.seed, super.logger, super.ttl});

  /// Optional seed for persistent identity derivation.
  final Uint8List? seed;

  libp2p.Host? _host;
  final Completer<void> _startCompleter = Completer<void>();
  final Map<libp2p.PeerId, libp2p.P2PStream<dynamic>> _streamCache = {};

  /// Returns true if the transport has started and the host is ready.
  bool get isStarted => _startCompleter.isCompleted && _host != null;

  @override
  Future<void> start() async {
    if (isStarted) return;
    logger?.call('Starting Libp2pTransport on $bindAddress');

    try {
      // 1. Resolve Identity
      final libp2p.KeyPair keyPair;
      if (seed != null) {
        logger?.call('Deriving libp2p identity from provided seed...');
        keyPair = await crypto.generateEd25519KeyPairFromSeed(seed!);
      } else {
        logger?.call('Generating temporary libp2p identity...');
        keyPair = await crypto.generateEd25519KeyPair();
      }

      // Initialize required resources for Transport
      final resourceManager = ResourceManagerImpl(limiter: FixedLimiter());

      // Extract port from bindAddress if possible, otherwise let libp2p decide
      final port = bindAddress.port;
      final listenAddr = libp2p.MultiAddr('/ip4/0.0.0.0/tcp/$port');

      _host = await Libp2p.new_([
        Libp2p.transport(TCPTransport(resourceManager: resourceManager)),
        Libp2p.listenAddrs([listenAddr]),
        Libp2p.identity(keyPair),
        Libp2p.userAgent('dart_ipfs/1.0.0-bridge'),
      ]);

      await _host!.start();

      // Register incoming stream handler for p2plib protocol
      _host!.setStreamHandler(p2plibProtocolId, (stream, remotePeerId) {
        unawaited(_handleIncomingStream(stream, remotePeerId));
        return Future.value();
      });

      logger?.call('Libp2pHost started with ID: ${_host!.id} on addresses: ${_host!.addrs}');
      _startCompleter.complete();
    } catch (e) {
      logger?.call('Failed to start Libp2pTransport: $e');
      if (!_startCompleter.isCompleted) {
        _startCompleter.completeError(e);
      }
      rethrow;
    }
  }

  @override
  void stop() {
    logger?.call('Stopping Libp2pTransport');
    // Close cached streams
    for (final stream in _streamCache.values) {
      unawaited(stream.close());
    }
    _streamCache.clear();

    _host?.close();
    _host = null;
  }

  @override
  void send(Iterable<p2p.FullAddress> fullAddresses, Uint8List datagram) {
    // p2plib might pass multiple addresses, but libp2p handles routing via PeerId.
    // However, the interface requires us to handle these addresses.
    // In our bridge, we mostly care about the PeerId if available,
    // or the Multiaddr constructed from FullAddress.
    for (final addr in fullAddresses) {
      unawaited(_sendOne(addr, datagram));
    }
  }

  Future<void> _sendOne(p2p.FullAddress dstAddress, Uint8List datagram) async {
    await _startCompleter.future;
    if (_host == null) return;

    try {
      // 1. Construct Libp2p MultiAddr from dstAddress
      final ip = dstAddress.address.address;
      final port = dstAddress.port;
      final ma = libp2p.MultiAddr('/ip4/$ip/tcp/$port');

      // 2. Derive Destination PeerId
      // p2plib packets have the destination PeerId in the header.
      // We parse the datagram to find who we are talking to.
      final dstPeerId = p2p.Message.getDstPeerId(datagram);

      // Convert p2plib PeerId to libp2p PeerId.
      // p2plib PeerId is 64 bytes (encKey + signKey).
      // Standard LocalCrypto in dart_ipfs uses the same Ed25519 pubkey for both.
      final pubKeyBytes = dstPeerId.value.sublist(0, 32);
      final libp2pPeerId = libp2p.PeerId.fromPublicKey(
        libp2p.Ed25519PublicKey.fromRawBytes(pubKeyBytes),
      );

      // 3. Get or Open Stream
      libp2p.P2PStream<dynamic>? stream = _streamCache[libp2pPeerId];
      if (stream == null || stream.isClosed) {
        logger?.call('Opening new stream to $libp2pPeerId via $ma');

        // Ensure we have the address in the peerstore
        await _host!.peerStore.addrBook.addAddrs(libp2pPeerId, [
          ma,
        ], libp2p.AddressTTL.permanentAddrTTL);

        // Ensure we are connected
        final info = libp2p.AddrInfo(libp2pPeerId, [ma]);
        await _host!.connect(info);

        stream = await _host!.newStream(libp2pPeerId, [p2plibProtocolId], libp2p.Context());

        _streamCache[libp2pPeerId] = stream;

        // Handle stream closure cleanup
        // Note: dart_libp2p might not have a direct 'onClose',
        // we might check it periodically or on next send.
      }

      // 4. Send framed data
      // Frame: Length (4 bytes) + Body
      final lenBytes = Uint8List(4);
      ByteData.view(lenBytes.buffer).setUint32(0, datagram.length);

      await stream.write(lenBytes);
      await stream.write(datagram);

      // We don't close the stream here to allow reuse.
      // It will stay in _streamCache.
    } catch (e) {
      logger?.call('Libp2pTransport send error: $e');
      // If error occurs, clear cache for this peer as the stream might be dead
      // (PeerId derivation might also fail if packet is malformed)
    }
  }

  Future<void> _handleIncomingStream(
    libp2p.P2PStream<dynamic> stream,
    libp2p.PeerId remotePeerId,
  ) async {
    try {
      while (!stream.isClosed) {
        // Read Length (4 bytes)
        final lenBytes = await stream.read(4);
        if (lenBytes.isEmpty) break;
        if (lenBytes.length < 4) break;

        final length = ByteData.view(lenBytes.buffer).getUint32(0);

        // Read Body
        final payload = await stream.read(length);
        if (payload.length < length) break;

        // Extract connection info
        final conn = stream.conn;
        final remoteAddr = conn.remoteMultiaddr;

        if (onMessage != null) {
          await onMessage!(
            p2p.Packet(
              srcFullAddress: p2p.FullAddress(
                address: InternetAddress(remoteAddr.toIP()?.address ?? '0.0.0.0'),
                port: remoteAddr.port ?? 0,
              ),
              datagram: Uint8List.fromList(payload),
              header: p2p.PacketHeader.fromBytes(payload),
            ),
          );
        }
      }
    } catch (e) {
      logger?.call('Stream error: $e');
    } finally {
      _streamCache.remove(remotePeerId);
      await stream.close();
    }
  }
}
