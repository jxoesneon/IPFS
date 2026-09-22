@Tags(['p0'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/dart_ipfs_client.dart';
// ignore: avoid_relative_lib_imports
import '../lib/kubo_client.dart';

const kKuboApiHost = 'kubo';
const kKuboApiPort = 5001;
const kDartIpfsApiHost = 'dart_ipfs';
const kDartIpfsApiPort = 5001;

void main() {
  group('P0 UnixFS directory parity with Kubo', () {
    late KuboClient kubo;
    late DartIpfsClient dartIpfs;

    setUpAll(() async {
      kubo = KuboClient(host: kKuboApiHost, port: kKuboApiPort);
      dartIpfs = DartIpfsClient(host: kDartIpfsApiHost, port: kDartIpfsApiPort);

      await kubo.id();
      await dartIpfs.id();

      final kuboId = await kubo.id();
      final dartIpfsId = await dartIpfs.id();
      final kuboPeerId = kuboId['ID'] as String;
      final dartIpfsPeerId = dartIpfsId['ID'] as String;

      try {
        await kubo.swarmConnect('/dns4/dart_ipfs/tcp/4001/p2p/$dartIpfsPeerId');
        await dartIpfs.swarmConnect('/dns4/kubo/tcp/4001/p2p/$kuboPeerId');
      } catch (e) {
        // Best effort - tests may still work
      }
    });

    test('wrap-with-directory produces the same root CID as Kubo', () async {
      // Identical files, added in name order: link ordering and cumulative
      // Tsize must match Kubo byte-for-byte for the dir CID to agree.
      final files = <String, List<int>>{
        'a.txt': 'alpha'.codeUnits,
        'b.txt': 'bravo contents'.codeUnits,
      };

      // First verify the child file CIDs agree — isolates file-level
      // divergence from dir-level divergence.
      for (final entry in files.entries) {
        final kuboFile = await kubo.add(Uint8List.fromList(entry.value));
        final dartFile = await dartIpfs.add(entry.value);
        expect(
          dartFile['Hash'],
          equals(kuboFile['Hash']),
          reason: 'file CID for ${entry.key} must match Kubo',
        );
      }

      final kuboDir = await kubo.addWrapped(files);
      final dartDir = await dartIpfs.addWrapped(files);

      print('Kubo wrapped dir: ${kuboDir['Hash']}');
      print('dart_ipfs wrapped dir: ${dartDir['Hash']}');

      if (dartDir['Hash'] != kuboDir['Hash']) {
        // Decode both dir blocks for a field-level diff in the CI log.
        final kuboBlock = dag_pb.PBNode.fromBuffer(
          await kubo.blockGet(kuboDir['Hash'] as String),
        );
        final dartBlock = dag_pb.PBNode.fromBuffer(
          Uint8List.fromList(
            await dartIpfs.blockGet(dartDir['Hash'] as String),
          ),
        );
        print('Kubo links:');
        for (final l in kuboBlock.links) {
          print(
            '  name=${l.name} tsize=${l.size} hash=${base64.encode(l.hash)}',
          );
        }
        print('dart_ipfs links:');
        for (final l in dartBlock.links) {
          print(
            '  name=${l.name} tsize=${l.size} hash=${base64.encode(l.hash)}',
          );
        }
        print('Kubo data: ${base64.encode(kuboBlock.data)}');
        print('dart data: ${base64.encode(dartBlock.data)}');
      }

      expect(
        dartDir['Hash'],
        equals(kuboDir['Hash']),
        reason: 'wrap-with-directory root CID must match Kubo',
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('dart_ipfs resolves files inside a Kubo-added directory', () async {
      final dirCid = await kubo.addDirRecursive('interopdir', {
        'nested/deep.txt': 'deep kubo content'.codeUnits,
        'top.txt': 'top level'.codeUnits,
      });
      print('Kubo recursive dir CID: $dirCid');

      // Allow Bitswap propagation
      await Future<void>.delayed(const Duration(seconds: 5));

      final top = await dartIpfs.cat('$dirCid/top.txt');
      expect(
        String.fromCharCodes(top),
        equals('top level'),
        reason: 'top-level file in Kubo dir must resolve',
      );

      final deep = await dartIpfs.cat('$dirCid/nested/deep.txt');
      expect(
        String.fromCharCodes(deep),
        equals('deep kubo content'),
        reason: 'nested file in Kubo dir must resolve',
      );
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('Kubo resolves files inside a dart_ipfs wrapped directory', () async {
      final files = <String, List<int>>{
        'from_dart.txt': 'wrapped by dart_ipfs'.codeUnits,
      };
      final dartDir = await dartIpfs.addWrapped(files);
      final dirCid = dartDir['Hash'] as String;
      print('dart_ipfs wrapped dir CID: $dirCid');

      await Future<void>.delayed(const Duration(seconds: 5));

      final data = await kubo.cat('$dirCid/from_dart.txt');
      expect(
        String.fromCharCodes(data),
        equals('wrapped by dart_ipfs'),
        reason: 'Kubo must resolve dart_ipfs-built directory paths',
      );
    }, timeout: const Timeout(Duration(seconds: 90)));
  });
}
