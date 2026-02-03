import 'package:dart_ipfs/src/transport/router_events.dart';

/// Type aliases for commonly used p2plib types.
///
/// These aliases provide cleaner naming and decouple
/// the codebase from direct p2plib imports.

/// A peer identifier in the libp2p network.
typedef LibP2PPeerId = String;

/// A complete network address including IP and port.
// typedef LibP2PFullAddress = p2p.FullAddress; // Removing for now as FullAddress implies IP/Port which might differ on web

/// A network packet with datagram and source info.
typedef LibP2PPacket = NetworkPacket;

/// The low-level router for datagram transmission.
// typedef LibP2PRouterL0 = p2p.RouterL0; // Removed, use P2plibRouter interface

