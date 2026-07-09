// lib/src/protocols/peering/peering_handler.dart
//
// Peering protocol support for dart_ipfs.
//
// This file provides a protocol-level entry point for the libp2p peering
// service. The concrete implementation lives in [lib/src/core/peering] and is
// re-exported here so that transport and protocol layers can depend on a stable
// protocol surface.
//
// See https://github.com/libp2p/specs/blob/master/peering/peering.md

export '../../core/peering/peering_service.dart'
    show PeeringConfig, PeeringEvent, PeeringService, PeeringEventType;
