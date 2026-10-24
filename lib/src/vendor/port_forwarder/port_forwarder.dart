/// UPnP / NAT-PCP / NAT-PMP port forwarding.
///
/// Vendored from the MIT-licensed `port_forwarder` package:
///
/// - Upstream: https://github.com/Auties00/port_forwarder
/// - Upstream version: 1.0.0 (last published 2025-04-16)
/// - Copyright (c) 2025 Alessandro Autiero — see `LICENSE` in this directory.
///
/// Why it is vendored: upstream constrains `xml` to `^6.5.0`, while this
/// project needs `xml ^7.1.0` (the version the local `dependency_overrides`
/// pinned before this copy existed). Declaring `xml` directly was not an
/// option — it made the published package unresolvable for consumers, because
/// `port_forwarder`'s `^6.5.0` constraint conflicts with a direct `^7.1.0`
/// dependency. Vendoring removes the conflicting constraint, so `xml ^7.1.0`
/// now reaches consumers instead of only local development and CI.
///
/// Only the import paths and the `xml` constraint differ from upstream; the
/// protocol implementations are unchanged. Keep this copy in sync with
/// upstream when port_forwarder publishes a new release.
library;

export 'src/error/base_error.dart';
export 'src/error/upnp_error.dart';

export 'src/gateway/base_gateway.dart';
export 'src/gateway/upnp_gateway.dart';
export 'src/gateway/pcp_gateway.dart';
export 'src/gateway/pmp_gateway.dart';

export 'src/type/gateway_type.dart';
export 'src/type/port_type.dart';
