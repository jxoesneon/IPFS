import 'package:p2plib/p2plib.dart' as p2p;

/// Type aliases for commonly used p2plib types.
///
/// These aliases provide cleaner naming and decouple
/// the codebase from direct p2plib imports.

/// A peer identifier in the libp2p network.
typedef LibP2PPeerId = p2p.PeerId;

/// A complete network address including IP and port.
typedef LibP2PFullAddress = p2p.FullAddress;

/// A network packet with datagram and source info.
typedef LibP2PPacket = p2p.Packet;

/// The low-level router for datagram transmission.
typedef LibP2PRouterL0 = p2p.RouterL0;
