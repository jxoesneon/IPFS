# Vendored `port_forwarder`

This directory is a verbatim copy of the MIT-licensed
[`port_forwarder`](https://github.com/Auties00/port_forwarder) package
(upstream version **1.0.0**, last published 2025-04-16), with two changes:

1. The self-referential imports (`package:port_forwarder/port_forwarder.dart`)
   were rewritten to the relative path of the vendored barrel file.
2. The package's `xml` constraint is no longer inherited from upstream —
   `xml` is now a direct dependency of `dart_ipfs` at `^7.1.0`.

`LICENSE` in this directory is upstream's MIT license (Copyright (c) 2025
Alessandro Autiero).

## Why it is vendored

Upstream `port_forwarder` constrains `xml` to `^6.5.0`. This project needs
`xml ^7.1.0`:

- Declaring `xml` as a direct dependency of `dart_ipfs` was tried before and
  **broke the published package for consumers**: `port_forwarder`'s `^6.5.0`
  constraint and a direct `^7.1.0` constraint cannot both be satisfied, so
  `dart_ipfs` failed to resolve (this is what the 1.11.6 release did, and
  1.11.7 reverted it).
- Keeping `xml` only in `dependency_overrides` worked locally and in CI, but
  overrides are not published — consumers of `dart_ipfs` kept resolving the
  older `xml` 6.x line.

Vendoring removes the conflicting constraint entirely: `dart_ipfs` depends on
`xml ^7.1.0` directly and no longer depends on `port_forwarder` at all, so
consumers resolve the same `xml` version the project is tested against.

## Keeping it in sync

Upstream is currently dormant (last push 2025-04-16). When it publishes a new
release:

1. Copy the new `lib/` over this directory.
2. Rewrite `package:port_forwarder/port_forwarder.dart` imports to
   `../../port_forwarder.dart`.
3. Re-apply the barrel-file header note in `port_forwarder.dart`.
4. Run `dart analyze lib test` and `dart test test/network/`.

The protocol implementations (UPnP, NAT-PCP, NAT-PMP) are unchanged from
upstream; only the import paths differ.

## Coverage

Each file in this directory starts with `// coverage:ignore-file`. The
changed-line coverage gate (`tool/changed_line_coverage.dart`) requires new
code to be covered; vendored third-party code is excluded with the gate's
own `coverage:ignore-file` escape hatch, the same way the generated protobuf
codecs are excluded. Upstream ships no tests for this package, and
re-implementing its protocol suites is out of scope for a dependency refresh.

If this copy is ever un-vendored or substantially rewritten, remove the
markers and add real tests instead.
