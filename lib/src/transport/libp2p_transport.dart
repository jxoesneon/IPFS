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
  Libp2pTransport({
    required super.bindAddress,
    this.seed,
    this.listenAddress,
    super.logger,
    super.ttl,
  });

  /// Optional seed for persistent identity derivation.
  final Uint8List? seed;

  /// Optional multiaddress to listen on. Defaults to /ip4/0.0.0.0/tcp/{bindAddress.port}
  final String? listenAddress;

  libp2p.Host? _host;
  final Completer<void> _startCompleter = Completer<void>();
  final Map<libp2p.PeerId, libp2p.P2PStream<dynamic>> _streamCache = {};

  /// Returns true if the transport has started and the host is ready.
  bool get isStarted => _startCompleter.isCompleted && _host != null;

  @override
  Future<void> start() async {
    logger?.call('Libp2pTransport: start() called');
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

      // 2. Select Listen Address
      final libp2p.MultiAddr listenAddr;
      if (listenAddress != null) {
        listenAddr = libp2p.MultiAddr(listenAddress!);
      } else {
        // Extract port from bindAddress if possible, otherwise let libp2p decide
        final port = bindAddress.port;
        listenAddr = libp2p.MultiAddr('/ip4/0.0.0.0/tcp/$port');
      }
      logger?.call('Libp2pTransport: listener address: $listenAddr');

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

      logger?.call(
        'Libp2pHost started with ID: ${_host!.id} on addresses: ${_host!.addrs}',
      );
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
    logger?.call(
      'Libp2pTransport.send called with ${fullAddresses.length} addresses',
    );
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
      // 1. Derive Destination PeerId
      // p2plib packets have the destination PeerId in the header.
      // We parse the datagram to find who we are talking to.
      final dstPeerId = p2p.Message.getDstPeerId(datagram);
      // final dstPeerIdStr = dstPeerId.toString(); // Unused

      // Convert p2plib PeerId to libp2p PeerId.
      // p2plib PeerId is 64 bytes (encKey + signKey).
      // Standard LocalCrypto in dart_ipfs uses the same Ed25519 pubkey for both.
      final pubKeyBytes = dstPeerId.value.sublist(0, 32);
      final libp2pPeerId = libp2p.PeerId.fromPublicKey(
        libp2p.Ed25519PublicKey.fromRawBytes(pubKeyBytes),
      );

      logger?.call(
        'Libp2pTransport._sendOne targeting $libp2pPeerId via $dstAddress',
      );

      // 2. Get or Open Stream
      libp2p.P2PStream<dynamic>? stream = _streamCache[libp2pPeerId];
      if (stream == null || stream.isClosed) {
        // 3. Resolve Addresses for the Peer
        // First try the PeerStore (might have discovered addresses via Gossipsub/DHT/mDNS)
        var addresses = await _host!.peerStore.addrBook.addrs(libp2pPeerId);

        if (addresses.isEmpty) {
          // Fallback to the FullAddress provided by p2plib, converted to Libp2p MultiAddr
          // This assumes the peer listens on the same port for both p2plib (UDP) and libp2p (TCP).
          final ip = dstAddress.address.address;
          final port = dstAddress.port;
          final ma = libp2p.MultiAddr('/ip4/$ip/tcp/$port');
          addresses = [ma];

          logger?.call(
            'Libp2pTransport: No addresses in PeerStore, using fallback: $ma',
          );

          await _host!.peerStore.addrBook.addAddrs(
            libp2pPeerId,
            addresses,
            libp2p.AddressTTL.permanentAddrTTL,
          );
        }

        logger?.call(
          'Libp2pTransport: Opening new stream to $libp2pPeerId via ${addresses.first}',
        );

        // Ensure we are connected
        final info = libp2p.AddrInfo(libp2pPeerId, addresses);
        logger?.call('Libp2pTransport: Connecting to $info...');
        await _host!.connect(info);
        logger?.call('Libp2pTransport: Connected to $libp2pPeerId');

        logger?.call(
          'Libp2pTransport: Opening stream for $p2plibProtocolId...',
        );
        // Use a context with timeout to avoid hanging indefinitely if negation stalls
        final context = libp2p.Context(timeout: const Duration(seconds: 15));

        try {
          stream = await _host!.newStream(libp2pPeerId, [
            p2plibProtocolId,
          ], context);
          logger?.call('Libp2pTransport: Stream opened for $libp2pPeerId');
        } catch (e) {
          logger?.call(
            'Libp2pTransport: Failed to open stream for $libp2pPeerId: $e',
          );
          rethrow;
        }

        _streamCache[libp2pPeerId] = stream;

        // Handle stream closure cleanup
        // Note: dart_libp2p might not have a direct 'onClose',
        // we might check it periodically or on next send.
      } else {
        logger?.call(
          'Libp2pTransport: Reusing cached stream for $libp2pPeerId',
        );
      }

      // 4. Send framed data
      // Frame: Length (4 bytes) + Body
      final lenBytes = Uint8List(4);
      ByteData.view(lenBytes.buffer).setUint32(0, datagram.length);

      logger?.call(
        'Libp2pTransport: Sending ${datagram.length} bytes to $libp2pPeerId',
      );
      await stream.write(lenBytes);
      await stream.write(datagram);

      // We don't close the stream here to allow reuse.
      // It will stay in _streamCache.
    } catch (e) {
      logger?.call('Libp2pTransport: send error: $e');
      logger?.call('Libp2pTransport send error: $e');
      // If error occurs, clear cache for this peer as the stream might be dead
    }
  }

  Future<void> _handleIncomingStream(
    libp2p.P2PStream<dynamic> stream,
    libp2p.PeerId remotePeerId,
  ) async {
    logger?.call(
      'Libp2pTransport: Handling incoming stream from $remotePeerId on ${stream.protocol()}',
    );
    try {
      while (!stream.isClosed) {
        // Read Length (4 bytes)
        final lenBytes = await _readExactly(stream, 4);
        if (lenBytes == null) {
          logger?.call('Steam closed during length read from $remotePeerId');
          break;
        }

        final length = ByteData.view(lenBytes.buffer).getUint32(0);
        logger?.call(
          'Libp2pTransport: Reading datagram of length $length from $remotePeerId',
        );
        if (length == 0) continue;

        // Read Body
        final payload = await _readExactly(stream, length);
        if (payload == null) {
          logger?.call('Steam closed during payload read from $remotePeerId');
          break;
        }

        logger?.call(
          'Libp2pTransport: Received $length bytes from $remotePeerId via libp2p',
        );
        // Extract connection info
        final conn = stream.conn;
        final remoteAddr = conn.remoteMultiaddr;

        if (onMessage != null) {
          try {
            logger?.call(
              'Libp2pTransport: Calling onMessage handler for packet...',
            );
            await onMessage!(
              p2p.Packet(
                srcFullAddress: p2p.FullAddress(
                  address: remoteAddr.toIP() ?? InternetAddress('0.0.0.0'),
                  port: remoteAddr.port ?? 0,
                ),
                datagram: payload,
                header: p2p.PacketHeader.fromBytes(payload),
              ),
            );
            logger?.call(
              'Libp2pTransport: onMessage handler completed successfully',
            );
          } on p2p.StopProcessing catch (e) {
            logger?.call(
              'Libp2pTransport: StopProcessing signal received from router: $e',
            );
          } catch (e) {
            logger?.call('Libp2pTransport: Error in onMessage handler: $e');
          }
        } else {
          logger?.call(
            'Libp2pTransport: WARNING: onMessage is NULL! dropping packet',
          );
        }
      }
    } catch (e) {
      logger?.call('Libp2pTransport stream handler error: $e');
    } finally {
      logger?.call('Closing stream from $remotePeerId');
      _streamCache.remove(remotePeerId);
    }
  }

  Future<Uint8List?> _readExactly(
    libp2p.P2PStream<dynamic> stream,
    int length,
  ) async {
    final bytes = BytesBuilder(copy: false);
    int remaining = length;

    while (remaining > 0) {
      final chunk = await stream.read(remaining);
      if (chunk.isEmpty) {
        if (remaining != length) {
          logger?.call(
            'Partial read: got ${length - remaining} of $length bytes',
          );
        }
        return null;
      }
      bytes.add(chunk);
      remaining -= chunk.length;
    }

    return bytes.takeBytes();
  }
}
