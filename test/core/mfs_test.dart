import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/mfs/mfs_manager.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/storage/hive_datastore.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

/// Minimal denylist stub: only [isBlockedPath] is consulted by [MFSManager].
class _FakeDenylistService extends Fake implements DenylistService {
  _FakeDenylistService(this.blockedPaths);

  final Set<String> blockedPaths;

  @override
  bool isBlockedPath(String path) => blockedPaths.contains(path);
}

void main() {
  group('MFSManager', () {
    late MFSManager mfs;
    late BlockStore blockStore;
    late HiveDatastore datastore;
    late String tempDir;

    setUp(() async {
      tempDir = await getPlatform().createTempDirectory('mfs_test_');
      blockStore = BlockStore(path: tempDir);
      datastore = HiveDatastore('$tempDir/datastore');

      await blockStore.start();
      await datastore.init();

      mfs = MFSManager(blockStore, datastore);
      await mfs.init();
    });

    tearDown(() async {
      await mfs.stop();
      await blockStore.stop();
      await datastore.close();
      await getPlatform().delete(tempDir);
    });

    test('mkdir creates directory', () async {
      await mfs.mkdir('/test');
      final contents = await mfs.ls('/');
      expect(contents.any((l) => l.name == 'test'), isTrue);
    });

    test('mkdir recursive', () async {
      await mfs.mkdir('/a/b/c', recursive: true);
      final aContents = await mfs.ls('/a');
      expect(aContents.any((l) => l.name == 'b'), isTrue);

      final bContents = await mfs.ls('/a/b');
      expect(bContents.any((l) => l.name == 'c'), isTrue);
    });

    test('write and read file', () async {
      const text = 'Hello MFS!';
      final data = Stream.value(utf8.encode(text));

      await mfs.write('/hello.txt', data, create: true);

      final readStream = await mfs.read('/hello.txt');
      final readData = await readStream.expand((b) => b).toList();
      expect(utf8.decode(readData), equals(text));
    });

    test('stat returns correct info', () async {
      await mfs.mkdir('/docs');
      final info = await mfs.stat('/docs');

      expect(info.type, equals('directory'));
      expect(info.hash, isNotNull);
      expect(info.size, equals(0));
    });

    test('rm removes file/directory', () async {
      await mfs.mkdir('/to_remove');
      await mfs.rm('/to_remove', recursive: true);

      final contents = await mfs.ls('/');
      expect(contents.any((l) => l.name == 'to_remove'), isFalse);
    });

    test('cp copies content', () async {
      await mfs.write(
        '/original.txt',
        Stream.value(utf8.encode('data')),
        create: true,
      );
      await mfs.cp('/original.txt', '/copy.txt');

      final contents = await mfs.ls('/');
      expect(contents.any((l) => l.name == 'copy.txt'), isTrue);

      final readStream = await mfs.read('/copy.txt');
      final readData = await readStream.expand((b) => b).toList();
      expect(utf8.decode(readData), equals('data'));
    });

    test('mv moves content', () async {
      await mfs.write(
        '/source.txt',
        Stream.value(utf8.encode('move me')),
        create: true,
      );
      await mfs.mv('/source.txt', '/dest.txt');

      final rootContents = await mfs.ls('/');
      expect(rootContents.any((l) => l.name == 'source.txt'), isFalse);
      expect(rootContents.any((l) => l.name == 'dest.txt'), isTrue);

      final readStream = await mfs.read('/dest.txt');
      final readData = await readStream.expand((b) => b).toList();
      expect(utf8.decode(readData), equals('move me'));
    });

    test('flush returns root CID', () async {
      await mfs.mkdir('/flushed');
      final rootCid = await mfs.flush(path: '/');
      expect(rootCid, isNotNull);
    });

    test('chcid changes CID version', () async {
      await mfs.mkdir('/chcid_dir');
      final before = await mfs.stat('/chcid_dir');
      await mfs.chcid('/chcid_dir', cidVersion: 1);
      final after = await mfs.stat('/chcid_dir');
      expect(after.hash, isNot(equals(before.hash)));
    });

    group('write offset/truncate', () {
      test('write with offset patches existing file', () async {
        await mfs.write(
          '/patch.txt',
          Stream.value(utf8.encode('hello world')),
          create: true,
        );
        await mfs.write(
          '/patch.txt',
          Stream.value(utf8.encode('X')),
          offset: 0,
          truncate: false,
        );

        final readStream = await mfs.read('/patch.txt');
        final readData = await readStream.expand((b) => b).toList();
        expect(utf8.decode(readData), equals('Xello world'));
      });

      test('truncate true zeros leading bytes and writes at offset', () async {
        await mfs.write(
          '/trunc.txt',
          Stream.value(utf8.encode('initial')),
          create: true,
        );
        await mfs.write(
          '/trunc.txt',
          Stream.value(utf8.encode('abc')),
          offset: 4,
          truncate: true,
        );

        final readStream = await mfs.read('/trunc.txt');
        final readData = await readStream.expand((b) => b).toList();
        expect(readData.length, equals(7));
        expect(readData.sublist(0, 4), equals([0, 0, 0, 0]));
        expect(utf8.decode(readData.sublist(4)), equals('abc'));
      });

      test('truncate false requires existing file', () async {
        expect(
          () => mfs.write(
            '/new.txt',
            Stream.value(utf8.encode('data')),
            create: false,
            truncate: false,
          ),
          throwsException,
        );
      });

      test('count limits bytes written', () async {
        await mfs.write(
          '/count.txt',
          Stream.value(utf8.encode('hello world')),
          count: 5,
          create: true,
        );

        final readStream = await mfs.read('/count.txt');
        final readData = await readStream.expand((b) => b).toList();
        expect(utf8.decode(readData), equals('hello'));
      });

      test('negative offset or count throws ArgumentError', () async {
        expect(
          () => mfs.write(
            '/neg.txt',
            Stream.value(utf8.encode('data')),
            offset: -1,
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => mfs.write(
            '/neg.txt',
            Stream.value(utf8.encode('data')),
            count: -1,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    test('read stream terminates on read error', () async {
      await mfs.write(
        '/broken.txt',
        Stream.value(utf8.encode('data')),
        create: true,
      );
      final stat = await mfs.stat('/broken.txt');

      // Remove the file's block so the recursive read fails mid-stream.
      await blockStore.removeBlock(stat.hash);

      final stream = await mfs.read('/broken.txt');
      // The controller used to addError without closing, leaving consumers
      // of the stream hanging forever.
      await expectLater(
        stream,
        emitsInOrder([emitsError(anything), emitsDone]),
      );
    });

    test('write with offset surfaces read errors instead of hanging', () async {
      await mfs.write(
        '/fragile.txt',
        Stream.value(utf8.encode('data')),
        create: true,
      );
      final stat = await mfs.stat('/fragile.txt');
      await blockStore.removeBlock(stat.hash);

      // _readAllBytes drives the same read controller; an unclosed stream
      // would make this hang rather than throw the underlying error.
      await expectLater(
        mfs
            .write(
              '/fragile.txt',
              Stream.value(utf8.encode('x')),
              offset: 0,
              truncate: false,
            )
            .timeout(const Duration(seconds: 5)),
        throwsA(isNot(isA<TimeoutException>())),
      );
    });

    test('stat honors cid-base', () async {
      await mfs.mkdir('/base', cidVersion: 1);
      final stat = await mfs.stat('/base', cidBase: 'base32');
      expect(stat.hash, startsWith('b'));
    });

    group('kubo parity semantics', () {
      Future<Uint8List> readAll(String path, {int? offset, int? count}) async {
        final stream = await mfs.read(path, offset: offset, count: count);
        final builder = BytesBuilder();
        await for (final chunk in stream) {
          builder.add(chunk);
        }
        return builder.toBytes();
      }

      test('mkdir fails when path exists without parents', () async {
        await mfs.mkdir('/exists');
        await expectLater(mfs.mkdir('/exists'), throwsA(anything));
      });

      test('mkdir -p on existing directory succeeds', () async {
        await mfs.mkdir('/exists');
        await mfs.mkdir('/exists', parents: true);
      });

      test('mkdir over an existing file fails even with parents', () async {
        await mfs.write('/afile', Stream.value(utf8.encode('x')), create: true);
        await expectLater(
          mfs.mkdir('/afile', parents: true),
          throwsA(anything),
        );
      });

      test('mkdir without parents fails when parent is missing', () async {
        await expectLater(mfs.mkdir('/no/such/dir'), throwsA(anything));
      });

      test('write without create fails on missing file', () async {
        await expectLater(
          mfs.write('/nope.txt', Stream.value(utf8.encode('x'))),
          throwsA(anything),
        );
      });

      test('write without create succeeds on existing file', () async {
        await mfs.write(
          '/keep.txt',
          Stream.value(utf8.encode('hello world')),
          create: true,
        );
        // Non-truncating write replaces the prefix and keeps the tail.
        await mfs.write('/keep.txt', Stream.value(utf8.encode('HELLO')));
        expect(await readAll('/keep.txt'), equals(utf8.encode('HELLO world')));
      });

      test('write to a directory path fails', () async {
        await mfs.mkdir('/somedir');
        await expectLater(
          mfs.write('/somedir', Stream.value(utf8.encode('x')), create: true),
          throwsA(anything),
        );
      });

      test('write to the root path fails', () async {
        await expectLater(
          mfs.write('/', Stream.value(utf8.encode('x')), create: true),
          throwsA(anything),
        );
      });

      test('write with parents creates intermediate directories', () async {
        await mfs.write(
          '/deep/nested/file.txt',
          Stream.value(utf8.encode('deep')),
          create: true,
          parents: true,
        );
        expect(
          await readAll('/deep/nested/file.txt'),
          equals(utf8.encode('deep')),
        );
      });

      test('write without parents fails when parent is missing', () async {
        await expectLater(
          mfs.write(
            '/missing/file.txt',
            Stream.value(utf8.encode('x')),
            create: true,
          ),
          throwsA(anything),
        );
      });

      test('write with mode/mtime stores unixfs 1.5 metadata', () async {
        await mfs.write(
          '/meta.txt',
          Stream.value(utf8.encode('meta')),
          create: true,
          mode: 0x1A4, // 0644
          mtimeSecs: 1700000000,
          mtimeNsecs: 42,
        );
        final stat = await mfs.stat('/meta.txt');
        expect(stat.mode, equals(0x1A4));
        expect(stat.mtime, equals(1700000000));
        expect(stat.mtimeNsecs, equals(42));
        final json = stat.toJson();
        // Kubo serializes Mode as a four-digit octal string.
        expect(json['Mode'], equals('0644'));
        expect(json['Mtime'], equals(1700000000));
        expect(json['MtimeNsecs'], equals(42));
      });

      test('touch sets mtime and chmod sets mode', () async {
        await mfs.write('/t.txt', Stream.value(utf8.encode('t')), create: true);
        await mfs.touch('/t.txt', mtimeSecs: 1600000000, mtimeNsecs: 7);
        await mfs.chmod('/t.txt', 0x1ED); // 0755
        final stat = await mfs.stat('/t.txt');
        expect(stat.mtime, equals(1600000000));
        expect(stat.mtimeNsecs, equals(7));
        expect(stat.mode, equals(0x1ED));
      });

      test('mtime alias behaves like touch', () async {
        await mfs.mkdir('/mdir');
        await mfs.mtime('/mdir', mtimeSecs: 1500000000);
        final stat = await mfs.stat('/mdir');
        expect(stat.mtime, equals(1500000000));
      });

      test('touch without mtime uses the current time', () async {
        await mfs.write(
          '/now.txt',
          Stream.value(utf8.encode('n')),
          create: true,
        );
        final before = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        await mfs.touch('/now.txt');
        final stat = await mfs.stat('/now.txt');
        expect(stat.mtime, isNotNull);
        expect(stat.mtime!, greaterThanOrEqualTo(before));
      });

      test('touch on missing path throws', () async {
        await expectLater(mfs.touch('/ghost'), throwsA(anything));
      });

      test('write bumps stored mtime like kubo', () async {
        await mfs.write(
          '/bump.txt',
          Stream.value(utf8.encode('v1')),
          create: true,
          mtimeSecs: 1000,
        );
        await mfs.write(
          '/bump.txt',
          Stream.value(utf8.encode('v2')),
          truncate: true,
        );
        final stat = await mfs.stat('/bump.txt');
        // The stored mtime was updated to "now" rather than cleared.
        expect(stat.mtime, isNotNull);
        expect(stat.mtime!, greaterThan(1000));
      });

      test('cp into a directory requires a trailing slash', () async {
        await mfs.write('/f.txt', Stream.value(utf8.encode('c')), create: true);
        await mfs.mkdir('/target');
        // Kubo: `cp /f.txt /target/` copies inside the directory.
        await mfs.cp('/f.txt', '/target/');
        expect(await readAll('/target/f.txt'), equals(utf8.encode('c')));
      });

      test(
        'cp onto an existing directory without trailing slash fails',
        () async {
          await mfs.write(
            '/f.txt',
            Stream.value(utf8.encode('c')),
            create: true,
          );
          await mfs.mkdir('/target');
          // Kubo PutNode errors with "already exists" — the destination is
          // not treated as a container without a trailing slash.
          await expectLater(mfs.cp('/f.txt', '/target'), throwsA(anything));
        },
      );

      test('cp onto an existing path fails without force', () async {
        await mfs.write('/a.txt', Stream.value(utf8.encode('a')), create: true);
        await mfs.write('/b.txt', Stream.value(utf8.encode('b')), create: true);
        await expectLater(mfs.cp('/a.txt', '/b.txt'), throwsA(anything));
      });

      test('cp with force overwrites an existing path', () async {
        await mfs.write('/a.txt', Stream.value(utf8.encode('a')), create: true);
        await mfs.write('/b.txt', Stream.value(utf8.encode('b')), create: true);
        await mfs.cp('/a.txt', '/b.txt', force: true);
        expect(await readAll('/b.txt'), equals(utf8.encode('a')));
      });

      test('cp with force refuses to overwrite a directory', () async {
        await mfs.write('/a.txt', Stream.value(utf8.encode('a')), create: true);
        await mfs.mkdir('/adir');
        await expectLater(
          mfs.cp('/a.txt', '/adir', force: true),
          throwsA(anything),
        );
      });

      test('cp with parents creates intermediate directories', () async {
        await mfs.write('/s.txt', Stream.value(utf8.encode('s')), create: true);
        await mfs.cp('/s.txt', '/x/y/z.txt', parents: true);
        expect(await readAll('/x/y/z.txt'), equals(utf8.encode('s')));
      });

      test('cp supports /ipfs/<cid> sources', () async {
        await mfs.write(
          '/origin.txt',
          Stream.value(utf8.encode('ipfs src')),
          create: true,
        );
        final stat = await mfs.stat('/origin.txt');
        await mfs.cp('/ipfs/${stat.hash}', '/cloned.txt');
        expect(await readAll('/cloned.txt'), equals(utf8.encode('ipfs src')));
      });

      test('mv into an existing directory moves under basename', () async {
        await mfs.write(
          '/mvf.txt',
          Stream.value(utf8.encode('m')),
          create: true,
        );
        await mfs.mkdir('/mvdst');
        await mfs.mv('/mvf.txt', '/mvdst');
        expect(await readAll('/mvdst/mvf.txt'), equals(utf8.encode('m')));
        await expectLater(readAll('/mvf.txt'), throwsA(anything));
      });

      test('mv onto an existing file replaces it', () async {
        // Kubo mv unlinks an existing file destination before linking.
        await mfs.write(
          '/src.txt',
          Stream.value(utf8.encode('new')),
          create: true,
        );
        await mfs.write(
          '/dst.txt',
          Stream.value(utf8.encode('old')),
          create: true,
        );
        await mfs.mv('/src.txt', '/dst.txt');
        expect(await readAll('/dst.txt'), equals(utf8.encode('new')));
        await expectLater(readAll('/src.txt'), throwsA(anything));
      });

      test('mv onto a name colliding inside the target dir fails', () async {
        await mfs.write('/c.txt', Stream.value(utf8.encode('c')), create: true);
        await mfs.mkdir('/holder');
        await mfs.write(
          '/holder/c.txt',
          Stream.value(utf8.encode('kept')),
          create: true,
        );
        await expectLater(mfs.mv('/c.txt', '/holder'), throwsA(anything));
        // The source is left intact on failure.
        expect(await readAll('/c.txt'), equals(utf8.encode('c')));
        expect(await readAll('/holder/c.txt'), equals(utf8.encode('kept')));
      });

      test('mv a path onto itself is a no-op', () async {
        await mfs.write(
          '/self.txt',
          Stream.value(utf8.encode('s')),
          create: true,
        );
        await mfs.mv('/self.txt', '/self.txt');
        expect(await readAll('/self.txt'), equals(utf8.encode('s')));
      });

      test('mv on a missing source fails', () async {
        await expectLater(mfs.mv('/ghost', '/dst'), throwsA(anything));
      });

      test(
        'rm without recursive on a directory fails; force removes it',
        () async {
          await mfs.mkdir('/doomed');
          await expectLater(mfs.rm('/doomed'), throwsA(anything));
          await mfs.rm('/doomed', force: true);
          expect((await mfs.ls('/')).any((e) => e.name == 'doomed'), isFalse);
        },
      );

      test('rm missing path fails without force; force ignores it', () async {
        await expectLater(mfs.rm('/ghost'), throwsA(anything));
        await mfs.rm('/ghost', force: true);
      });

      test('ls on a file lists the file itself', () async {
        await mfs.write(
          '/single.txt',
          Stream.value(utf8.encode('one')),
          create: true,
        );
        // Non-long: Kubo returns only the entry name.
        final entries = await mfs.ls('/single.txt');
        expect(entries, hasLength(1));
        expect(entries.first.name, equals('single.txt'));
        expect(entries.first.type, equals(0));
        expect(entries.first.hash, isEmpty);
        // Long: type 0 = file, logical size and hash populated.
        final longEntries = await mfs.ls('/single.txt', long: true);
        expect(longEntries, hasLength(1));
        expect(longEntries.first.type, equals(0));
        expect(longEntries.first.size, equals(3));
        expect(longEntries.first.hash, isNotEmpty);
      });

      test('ls populates Kubo types: 0=file, 1=directory', () async {
        await mfs.mkdir('/typed_dir');
        await mfs.write(
          '/typed_file',
          Stream.value(utf8.encode('f')),
          create: true,
        );
        final entries = await mfs.ls('/', long: true);
        final dir = entries.firstWhere((e) => e.name == 'typed_dir');
        final file = entries.firstWhere((e) => e.name == 'typed_file');
        expect(dir.type, equals(1));
        expect(dir.size, equals(0));
        expect(file.type, equals(0));
        expect(file.size, equals(1));
      });

      test('ls without -l only returns names', () async {
        await mfs.mkdir('/ndir');
        final entries = await mfs.ls('/');
        final entry = entries.firstWhere((e) => e.name == 'ndir');
        expect(entry.hash, isEmpty);
        expect(entry.size, equals(0));
        expect(entry.type, equals(0));
      });

      test('ls -l includes mode and mtime', () async {
        await mfs.write(
          '/long.txt',
          Stream.value(utf8.encode('l')),
          create: true,
          mode: 0x1A4,
          mtimeSecs: 1700000000,
        );
        final entries = await mfs.ls('/', long: true);
        final entry = entries.firstWhere((e) => e.name == 'long.txt');
        expect(entry.mode, equals(0x1A4));
        expect(entry.mtime, equals(1700000000));
      });

      test('read on a directory throws', () async {
        await mfs.mkdir('/d');
        await expectLater(readAll('/d'), throwsA(anything));
      });

      test('read offset/count applies across chunk boundaries', () async {
        // 600 KiB forces a multi-chunk layout (chunk size 256 KiB).
        final data = Uint8List(600 * 1024);
        for (var i = 0; i < data.length; i++) {
          data[i] = i % 251;
        }
        await mfs.write('/big.bin', Stream.value(data), create: true);

        const offset = 100000;
        const count = 300000;
        final bytes = await readAll('/big.bin', offset: offset, count: count);
        expect(
          bytes,
          equals(Uint8List.fromList(data.sublist(offset, offset + count))),
        );
      });

      test('read offset beyond EOF returns empty', () async {
        await mfs.write('/e.txt', Stream.value(utf8.encode('e')), create: true);
        expect(await readAll('/e.txt', offset: 99), isEmpty);
      });

      test('write with raw-leaves reads back correctly', () async {
        final data = Uint8List(300 * 1024);
        for (var i = 0; i < data.length; i++) {
          data[i] = i % 253;
        }
        await mfs.write(
          '/raw.bin',
          Stream.value(data),
          create: true,
          rawLeaves: true,
          cidVersion: 1,
        );
        expect(await readAll('/raw.bin'), equals(data));
      });

      test('flush returns the CID of the flushed path', () async {
        await mfs.mkdir('/fdir');
        final stat = await mfs.stat('/fdir');
        final flushed = await mfs.flush(path: '/fdir');
        expect(flushed.encode(), equals(stat.hash));
        final root = await mfs.flush();
        expect(root.encode(), equals(mfs.rootCid.encode()));
      });

      test('flush is deterministic once mutations settle', () async {
        await mfs.write(
          '/det.txt',
          Stream.value(utf8.encode('d')),
          create: true,
        );
        final first = await mfs.flush();
        final second = await mfs.flush();
        expect(first.encode(), equals(second.encode()));
      });

      test('flush on a missing path throws', () async {
        await expectLater(mfs.flush(path: '/missing'), throwsA(anything));
      });

      test('sync persists the root for restart durability', () async {
        await mfs.write('/s.txt', Stream.value(utf8.encode('s')), create: true);
        await mfs.sync();
        final mfs2 = MFSManager(blockStore, datastore);
        await mfs2.init();
        expect(mfs2.rootCid.encode(), equals(mfs.rootCid.encode()));
      });

      test('chcid on root path throws', () async {
        await expectLater(mfs.chcid('/'), throwsA(anything));
      });

      test('chcid on a file fails (directories only)', () async {
        await mfs.write(
          '/chf.txt',
          Stream.value(utf8.encode('c')),
          create: true,
        );
        await expectLater(
          mfs.chcid('/chf.txt', cidVersion: 1),
          throwsA(anything),
        );
      });

      test('chcid with no options is a no-op', () async {
        await mfs.mkdir('/noopdir');
        final before = await mfs.stat('/noopdir');
        await mfs.chcid('/noopdir');
        final after = await mfs.stat('/noopdir');
        expect(after.hash, equals(before.hash));
      });

      test('chcid with hash only upgrades to CIDv1', () async {
        await mfs.mkdir('/hdir');
        final before = await mfs.stat('/hdir');
        expect(before.hash, startsWith('Qm')); // CIDv0
        await mfs.chcid('/hdir', hash: 'sha2-256');
        final after = await mfs.stat('/hdir');
        expect(after.hash, startsWith('b')); // CIDv1 base32
      });

      test('stat with-local reports Local and SizeLocal', () async {
        await mfs.write(
          '/loc.txt',
          Stream.value(utf8.encode('l')),
          create: true,
        );
        final stat = await mfs.stat('/loc.txt', withLocal: true);
        final json = stat.toJson();
        expect(json['WithLocality'], isTrue);
        expect(json['Local'], isTrue);
        expect(json['SizeLocal'], isA<int>());
      });

      test('stat supports /ipfs paths', () async {
        await mfs.write(
          '/ipfssrc.txt',
          Stream.value(utf8.encode('src')),
          create: true,
        );
        final stat = await mfs.stat('/ipfssrc.txt');
        final ipfsStat = await mfs.stat('/ipfs/${stat.hash}');
        expect(ipfsStat.hash, equals(stat.hash));
        expect(ipfsStat.size, equals(stat.size));
      });

      test('stat returns the full Kubo shape', () async {
        await mfs.write('/h.txt', Stream.value(utf8.encode('h')), create: true);
        final stat = await mfs.stat('/h.txt');
        final json = stat.toJson();
        for (final key in [
          'Hash',
          'Size',
          'CumulativeSize',
          'Blocks',
          'Type',
        ]) {
          expect(json.containsKey(key), isTrue, reason: 'missing $key');
        }
        expect(json['Type'], equals('file'));
        // Mode is omitted when unset (Kubo omitempty on a zero mode).
        expect(json.containsKey('Mode'), isFalse);
      });

      test('path normalization handles dot segments', () async {
        await mfs.mkdir('/norm/sub', parents: true);
        await mfs.write(
          '/norm/sub/f.txt',
          Stream.value(utf8.encode('n')),
          create: true,
        );
        expect(await readAll('/norm/./sub/f.txt'), equals(utf8.encode('n')));
        // '..' that stays within the root resolves fine.
        expect(
          await readAll('/norm/../norm/sub/f.txt'),
          equals(utf8.encode('n')),
        );
        // '..' escaping the root clamps at '/', matching Kubo's
        // gopath.Clean semantics — '/../norm/...' resolves like '/norm/...'.
        expect(
          await readAll('/../../norm/sub/f.txt'),
          equals(utf8.encode('n')),
        );
        // '/../etc' clamps to '/etc', which does not exist.
        await expectLater(readAll('/../etc'), throwsA(anything));
      });

      test('write with offset beyond EOF zero-fills the gap', () async {
        // Kubo's DagModifier expands sparse on seek past the end of file.
        await mfs.write(
          '/sparse.txt',
          Stream.value(utf8.encode('ab')),
          create: true,
        );
        await mfs.write(
          '/sparse.txt',
          Stream.value(utf8.encode('z')),
          offset: 5,
        );
        final bytes = await readAll('/sparse.txt');
        expect(bytes, equals(Uint8List.fromList([97, 98, 0, 0, 0, 122])));
      });

      test('write with offset beyond EOF on a new file zero-fills', () async {
        await mfs.write(
          '/fresh.txt',
          Stream.value(utf8.encode('x')),
          create: true,
          offset: 3,
        );
        expect(
          await readAll('/fresh.txt'),
          equals(Uint8List.fromList([0, 0, 0, 120])),
        );
      });
    });

    group('edge cases and defensive branches', () {
      Future<Uint8List> readAll(String path) async {
        final stream = await mfs.read(path);
        final builder = BytesBuilder();
        await for (final chunk in stream) {
          builder.add(chunk);
        }
        return builder.toBytes();
      }

      test('mkdir on root without parents throws', () async {
        await expectLater(mfs.mkdir('/'), throwsA(anything));
        // With parents (or recursive) it is a no-op, matching Kubo.
        await mfs.mkdir('/', parents: true);
      });

      test('mkdir with mode/mtime stores unixfs 1.5 metadata', () async {
        await mfs.mkdir(
          '/metadir',
          mode: 0x1ED,
          mtimeSecs: 1700000000,
          mtimeNsecs: 55,
        );
        final stat = await mfs.stat('/metadir');
        expect(stat.mode, equals(0x1ED));
        expect(stat.mtime, equals(1700000000));
        expect(stat.mtimeNsecs, equals(55));
      });

      test('mkdir with only mtime-nsecs stores the nsec fraction', () async {
        await mfs.mkdir('/nsecdir', mtimeNsecs: 42);
        final stat = await mfs.stat('/nsecdir');
        expect(stat.mtimeNsecs, equals(42));
      });

      test(
        'cp to a destination that resolves to the MFS root throws',
        () async {
          await mfs.write(
            '/cpf.txt',
            Stream.value(utf8.encode('c')),
            create: true,
          );
          // '' and '/..' both normalize to '/', which cannot be overwritten.
          await expectLater(mfs.cp('/cpf.txt', ''), throwsA(anything));
          await expectLater(mfs.cp('/cpf.txt', '/..'), throwsA(anything));
        },
      );

      test('mv of the MFS root throws', () async {
        await expectLater(mfs.mv('/', '/elsewhere'), throwsA(anything));
      });

      test('mv into a trailing-slash directory moves under basename', () async {
        await mfs.write(
          '/ts.txt',
          Stream.value(utf8.encode('t')),
          create: true,
        );
        await mfs.mkdir('/tsdir');
        await mfs.mv('/ts.txt', '/tsdir/');
        expect(await readAll('/tsdir/ts.txt'), equals(utf8.encode('t')));
        await expectLater(readAll('/ts.txt'), throwsA(anything));
      });

      test('mv on a denylisted source throws StateError', () async {
        final denylisted = MFSManager(
          blockStore,
          datastore,
          denylistService: _FakeDenylistService({'/blocked.txt'}),
        );
        await denylisted.init();
        await denylisted.write(
          '/blocked.txt',
          Stream.value(utf8.encode('b')),
          create: true,
        );
        await expectLater(
          denylisted.mv('/blocked.txt', '/dst.txt'),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          denylisted.cp('/blocked.txt', '/dst.txt'),
          throwsA(isA<StateError>()),
        );
      });

      test('cp on a missing source throws', () async {
        await expectLater(mfs.cp('/ghost', '/dst'), throwsA(anything));
      });

      test('chmod rejects out-of-range modes', () async {
        await mfs.write(
          '/cm.txt',
          Stream.value(utf8.encode('c')),
          create: true,
        );
        await expectLater(
          mfs.chmod('/cm.txt', -1),
          throwsA(isA<ArgumentError>()),
        );
        await expectLater(
          mfs.chmod('/cm.txt', 0x100000000),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('chmod on the root updates the root node metadata', () async {
        await mfs.chmod('/', 0x1ED);
        final stat = await mfs.stat('/');
        expect(stat.mode, equals(0x1ED));
      });

      test('an invalid /ipfs path throws MFSPathError', () async {
        await expectLater(
          mfs.stat('/ipfs/not-a-cid'),
          throwsA(isA<MFSPathError>()),
        );
        await expectLater(
          mfs.ls('/ipfs/not-a-cid'),
          throwsA(isA<MFSPathError>()),
        );
      });

      test('/ipfs/<cid>/sub paths walk named dag links', () async {
        await mfs.mkdir('/walk');
        await mfs.write(
          '/walk/f.txt',
          Stream.value(utf8.encode('w')),
          create: true,
        );
        final root = mfs.rootCid.encode();
        final stat = await mfs.stat('/ipfs/$root/walk/f.txt');
        expect(stat.type, equals('file'));
        expect(stat.size, equals(1));
        // A link that does not exist resolves to null -> path not found.
        await expectLater(
          mfs.stat('/ipfs/$root/walk/missing'),
          throwsA(anything),
        );
      });

      test(
        '/ipfs/<cid>/sub with a missing block resolves to not found',
        () async {
          final ghost = await CID.fromContent(
            Uint8List.fromList([1, 2, 3]),
            codec: 'dag-pb',
          );
          await expectLater(
            mfs.stat('/ipfs/${ghost.encode()}/x'),
            throwsA(anything),
          );
        },
      );

      test(
        '/ipfs/<cid>/sub on an unparseable node resolves to not found',
        () async {
          // Bytes that fail PBNode decoding (truncated length-delimited field).
          final garbage = Uint8List.fromList([0x0a, 0xff, 0xff]);
          final garbageCid = await CID.fromContent(garbage, codec: 'raw');
          await blockStore.putBlock(
            Block(cid: garbageCid, data: garbage, format: 'raw'),
          );
          await expectLater(
            mfs.stat('/ipfs/${garbageCid.encode()}/x'),
            throwsA(anything),
          );
        },
      );

      test('stat on a raw block reports file size and locality', () async {
        final payload = Uint8List.fromList(utf8.encode('raw payload'));
        final rawCid = await CID.fromContent(payload, codec: 'raw');
        await blockStore.putBlock(
          Block(cid: rawCid, data: payload, format: 'raw'),
        );
        final stat = await mfs.stat(
          '/ipfs/${rawCid.encode()}',
          withLocal: true,
        );
        expect(stat.type, equals('file'));
        expect(stat.size, equals(payload.length));
        expect(stat.cumulativeSize, equals(payload.length));
        expect(stat.blocks, equals(0));
        expect(stat.local, isTrue);
        expect(stat.sizeLocal, equals(payload.length));
      });

      test('metadata on a raw block linked into mfs fails', () async {
        // An empty payload still parses as an (empty) PBNode, which lets
        // `cp` link the raw leaf into the MFS tree while keeping the
        // `raw` codec on the stored CID.
        final payload = Uint8List(0);
        final rawCid = await CID.fromContent(payload, codec: 'raw');
        await blockStore.putBlock(
          Block(cid: rawCid, data: payload, format: 'raw'),
        );
        await mfs.cp('/ipfs/${rawCid.encode()}', '/leaf.bin');
        await expectLater(mfs.chmod('/leaf.bin', 0x1A4), throwsA(anything));
        await expectLater(mfs.touch('/leaf.bin'), throwsA(anything));
      });

      test('metadata on a path whose block is missing fails', () async {
        await mfs.write(
          '/gone.txt',
          Stream.value(utf8.encode('g')),
          create: true,
        );
        final stat = await mfs.stat('/gone.txt');
        await blockStore.removeBlock(stat.hash);
        await expectLater(mfs.chmod('/gone.txt', 0x1A4), throwsA(anything));
      });

      test('metadata on a node without unixfs data defaults to file', () async {
        // A bare dag-pb node carrying no UnixFS Data payload at all.
        final bareData = Uint8List.fromList(PBNode().writeToBuffer());
        final bareCid = await CID.fromContent(bareData, codec: 'dag-pb');
        await blockStore.putBlock(
          Block(cid: bareCid, data: bareData, format: 'dag-pb'),
        );
        await mfs.cp('/ipfs/${bareCid.encode()}', '/bare');
        await mfs.chmod('/bare', 0x1A4);
        final stat = await mfs.stat('/bare');
        expect(stat.mode, equals(0x1A4));
      });

      test('stat with-local on a directory walks child links', () async {
        await mfs.mkdir('/localdir');
        await mfs.write(
          '/localdir/f.txt',
          Stream.value(utf8.encode('f')),
          create: true,
        );
        final stat = await mfs.stat('/localdir', withLocal: true);
        expect(stat.local, isTrue);
        expect(stat.sizeLocal, greaterThan(0));
      });

      test(
        'stat with-local reports false when a child block is missing',
        () async {
          await mfs.mkdir('/partdir');
          await mfs.write(
            '/partdir/f.txt',
            Stream.value(utf8.encode('f')),
            create: true,
          );
          final childStat = await mfs.stat('/partdir/f.txt');
          await blockStore.removeBlock(childStat.hash);
          final stat = await mfs.stat('/partdir', withLocal: true);
          expect(stat.local, isFalse);
        },
      );
    });
  });
}
