// Kubo-style identify probe: dial a node, open /ipfs/id/1.0.0, write an
// identify record first (go-libp2p initiator semantics), half-close, then
// read the responder's record with a bounded timeout.
// Usage: dart run tool/identify_probe.dart <multiaddr> [--write-first]
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_libp2p/config/config.dart' as config;
import 'package:ipfs_libp2p/core/crypto/ed25519.dart' as crypto;
import 'package:ipfs_libp2p/core/network/context.dart';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/host/resource_manager/limiter.dart';
import 'package:ipfs_libp2p/p2p/host/resource_manager/resource_manager_impl.dart';
import 'package:ipfs_libp2p/p2p/transport/tcp_transport.dart';
import 'package:logging/logging.dart' as logging;

Uint8List _varint(int n) {
  final out = <int>[];
  var v = n;
  while (v >= 0x80) {
    out.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  out.add(v);
  return Uint8List.fromList(out);
}

Future<void> main(List<String> args) async {
  final addr = args[0];
  final writeFirst = args.contains('--write-first');

  logging.hierarchicalLoggingEnabled = true;
  logging.Logger.root.level = logging.Level.WARNING;
  logging.Logger.root.onRecord.listen((r) {
    stderr.writeln('${r.level.name} ${r.loggerName}: ${r.message}');
  });

  final keyPair = await crypto.generateEd25519KeyPair();
  final host = await config.Libp2p.new_([
    config.Libp2p.transport(
      TCPTransport(
        resourceManager: ResourceManagerImpl(limiter: FixedLimiter()),
      ),
    ),
    config.Libp2p.listenAddrs([libp2p.MultiAddr('/ip4/0.0.0.0/tcp/0')]),
    config.Libp2p.identity(keyPair),
  ]);
  await host.start();
  stderr.writeln('client up: ${host.id}');

  final maddr = libp2p.MultiAddr(addr);
  final parts = addr.split('/p2p/');
  final peerId = libp2p.PeerId.fromString(parts.last);
  await host.peerStore.addrBook
      .addAddrs(peerId, [maddr], const Duration(minutes: 5));
  await host.connect(libp2p.AddrInfo(peerId, [maddr]));
  stderr.writeln('connected');

  final stream =
      await host.newStream(peerId, ['/ipfs/id/1.0.0'], Context());
  stderr.writeln('stream negotiated');

  if (writeFirst) {
    // Simulate kubo: initiator writes its identify record then closeWrite.
    final record = Uint8List.fromList(List.generate(64, (i) => i & 0xff));
    await stream.write(Uint8List.fromList([..._varint(record.length), ...record]));
    stderr.writeln('wrote ${record.length}B record');
    await stream.closeWrite();
    stderr.writeln('closeWrite done');
  }

  final buf = <int>[];
  try {
    while (true) {
      final chunk = await stream.read(4096).timeout(const Duration(seconds: 5));
      if (chunk.isEmpty) break;
      buf.addAll(chunk);
    }
  } on TimeoutException {
    stderr.writeln('READ TIMEOUT after ${buf.length}B');
  } catch (e) {
    stderr.writeln('READ ERR: $e (got ${buf.length}B)');
  }
  stderr.writeln('READ ${buf.length}B: ${buf.take(40).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

  await host.close();
  exit(0);
}
