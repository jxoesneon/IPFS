// test/services/rpc/mfs_handlers_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:mockito/mockito.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/mfs/mfs_manager.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/services/rpc/mfs_handlers.dart';

class FakeMFSManager extends Fake implements MFSManager {
  FakeMFSManager({this.lsResult = const [], this.statResult, this.readBytes});

  List<MFSListEntry> lsResult;
  MFSStat? statResult;
  List<int>? readBytes;

  final List<_WriteCall> writes = [];
  String lastMkdirPath = '';
  String lastCpSrc = '';
  String lastCpDst = '';
  String lastMvSrc = '';
  String lastMvDst = '';
  String lastRmPath = '';
  String lastFlushPath = '';
  String lastChcidPath = '';
  int? lastChcidVersion;
  String? lastChcidHash;
  bool shouldThrow = false;

  void _throwIfNeeded() {
    if (shouldThrow) throw Exception('mfs error');
  }

  @override
  Future<List<MFSListEntry>> ls(
    String path, {
    bool long = false,
    bool u = false,
  }) async {
    _throwIfNeeded();
    return lsResult;
  }

  @override
  Future<MFSStat> stat(
    String path, {
    bool withLocal = false,
    bool? hash,
    bool? size,
    String? cidBase,
  }) async {
    _throwIfNeeded();
    final base = statResult ?? MFSStat(hash: 'QmEmpty', size: 0, cumulativeSize: 0, blocks: 0, type: 'directory');
    if (withLocal) {
      return MFSStat(
        hash: base.hash,
        size: base.size,
        cumulativeSize: base.cumulativeSize,
        blocks: base.blocks,
        type: base.type,
        withLocal: true,
        local: true,
      );
    }
    return base;
  }

  @override
  Future<Stream<List<int>>> read(String path, {int? offset, int? count}) async {
    _throwIfNeeded();
    final data = readBytes ?? [];
    final start = offset ?? 0;
    final end = count == null ? data.length : (start + count).clamp(0, data.length);
    return Stream.fromIterable([data.sublist(start, end)]);
  }

  @override
  Future<void> write(
    String path,
    Stream<List<int>> data, {
    bool create = true,
    int? offset,
    bool truncate = true,
    int? count,
    int? cidVersion,
    bool? rawLeaves,
    String? hash,
  }) async {
    final bytes = await data.expand((b) => b).toList();
    _throwIfNeeded();
    writes.add(
      _WriteCall(
        path: path,
        bytes: Uint8List.fromList(bytes),
        create: create,
        offset: offset,
        truncate: truncate,
        count: count,
        cidVersion: cidVersion,
        rawLeaves: rawLeaves,
        hash: hash,
      ),
    );
  }

  @override
  Future<void> mkdir(
    String path, {
    bool recursive = false,
    bool parents = false,
    int? cidVersion,
    String? hash,
  }) async {
    lastMkdirPath = path;
    _throwIfNeeded();
  }

  @override
  Future<void> cp(String src, String dst) async {
    lastCpSrc = src;
    lastCpDst = dst;
    _throwIfNeeded();
  }

  @override
  Future<void> mv(String src, String dst) async {
    lastMvSrc = src;
    lastMvDst = dst;
    _throwIfNeeded();
  }

  @override
  Future<void> rm(
    String path, {
    bool recursive = false,
    bool force = false,
  }) async {
    lastRmPath = path;
    _throwIfNeeded();
  }

  @override
  Future<CID> flush({String? path}) async {
    lastFlushPath = path ?? '/';
    _throwIfNeeded();
    return CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
  }

  @override
  Future<void> chcid(
    String path, {
    int? cidVersion,
    String? hash = 'sha2-256',
  }) async {
    lastChcidPath = path;
    lastChcidVersion = cidVersion;
    lastChcidHash = hash;
    _throwIfNeeded();
  }
}

class _WriteCall {
  _WriteCall({
    required this.path,
    required this.bytes,
    required this.create,
    required this.offset,
    required this.truncate,
    required this.count,
    required this.cidVersion,
    required this.rawLeaves,
    required this.hash,
  });

  final String path;
  final Uint8List bytes;
  final bool create;
  final int? offset;
  final bool truncate;
  final int? count;
  final int? cidVersion;
  final bool? rawLeaves;
  final String? hash;
}

class FakeDenylistService extends Fake implements DenylistService {
  bool _configuredEnabled = true;
  final Set<String> blockedPaths = {};
  String action = 'block';

  @override
  bool get configuredEnabled => _configuredEnabled;
  set configuredEnabled(bool value) => _configuredEnabled = value;

  @override
  bool isBlockedPath(String path) => blockedPaths.contains(path);

  @override
  String recordHit(
    String cidOrMultihash, {
    required String source,
    String? reason,
  }) => action;
}

class FakeIPFSNode extends Fake implements IPFSNode {
  FakeIPFSNode(this.mfs, {this.denylistService});

  @override
  final MFSManager mfs;

  @override
  final DenylistService? denylistService;
}

MFSStat _makeStat({bool? hash, bool? size}) => MFSStat(
  hash: 'QmStat',
  size: 42,
  cumulativeSize: 100,
  blocks: 1,
  type: 'file',
  hashOnly: hash,
  sizeOnly: size,
);

MFSListEntry _makeEntry(String name) => MFSListEntry(
  name: name,
  type: 2,
  size: 10,
  hash: 'QmEntry',
);

void main() {
  group('MFSHandlers', () {
    late FakeMFSManager fakeMfs;
    late FakeDenylistService fakeDenylist;
    late MFSHandlers handlers;

    setUp(() {
      fakeMfs = FakeMFSManager(
        lsResult: [_makeEntry('file.txt')],
        statResult: _makeStat(),
        readBytes: [1, 2, 3],
      );
      fakeDenylist = FakeDenylistService();
      handlers = MFSHandlers(
        FakeIPFSNode(fakeMfs, denylistService: fakeDenylist),
      );
    });

    test('handleFilesLs returns entries and hash', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/ls?arg=/&long=true&U=true'),
      );
      final response = await handlers.handleFilesLs(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      expect(body['Entries'], hasLength(1));
      expect(body['Hash'], equals('QmStat'));
    });

    test('handleFilesLs error path', () async {
      fakeMfs.shouldThrow = true;
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/ls'),
      );
      final response = await handlers.handleFilesLs(request);
      expect(response.statusCode, equals(500));
      final body = json.decode(await response.readAsString());
      expect(body['Message'], contains('files/ls failed'));
    });

    test('handleFilesStat returns full stat', () async {
      final request = Request(
        'POST',
        Uri.parse(
          'http://localhost/api/v0/files/stat?arg=/&with-local=true&cid-base=base32',
        ),
      );
      final response = await handlers.handleFilesStat(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      expect(body['Hash'], equals('QmStat'));
      expect(body['WithLocal'], isTrue);
    });

    test('handleFilesStat hash only flag', () async {
      fakeMfs.statResult = _makeStat(hash: true);
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/stat?arg=/&hash=true'),
      );
      final response = await handlers.handleFilesStat(request);
      final body = json.decode(await response.readAsString());
      expect(body['Hash'], equals('QmStat'));
      expect(body.containsKey('Size'), isFalse);
    });

    test('handleFilesStat error path', () async {
      fakeMfs.shouldThrow = true;
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/stat?arg=/'),
      );
      final response = await handlers.handleFilesStat(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesRead returns octet stream', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/read?arg=/file&offset=0&count=2'),
      );
      final response = await handlers.handleFilesRead(request);
      expect(response.statusCode, equals(200));
      final bytes = await response.read().expand((c) => c).toList();
      expect(bytes, equals([1, 2]));
    });

    test('handleFilesRead missing path', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/read'),
      );
      final response = await handlers.handleFilesRead(request);
      expect(response.statusCode, equals(500));
      final body = json.decode(await response.readAsString());
      expect(body['Message'], contains('Missing argument'));
    });

    test('handleFilesRead invalid offset/count', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/read?arg=/file&offset=-1'),
      );
      final response = await handlers.handleFilesRead(request);
      expect(response.statusCode, equals(400));
    });

    test('handleFilesRead error path', () async {
      fakeMfs.shouldThrow = true;
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/read?arg=/file'),
      );
      final response = await handlers.handleFilesRead(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesWrite success with multipart', () async {
      const boundary = 'boundary';
      const content = 'hello';
      final body =
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="test.txt"\r\n'
          '\r\n'
          '$content\r\n'
          '--$boundary--\r\n';
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/write?arg=/test&create=true&truncate=true'),
        headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        body: body,
      );
      final response = await handlers.handleFilesWrite(request);
      expect(response.statusCode, equals(200));
      expect(fakeMfs.writes, hasLength(1));
      expect(fakeMfs.writes.first.bytes, equals(utf8.encode(content)));
      expect(fakeMfs.writes.first.create, isTrue);
    });

    test('handleFilesWrite missing path', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/files/write'));
      final response = await handlers.handleFilesWrite(request);
      expect(response.statusCode, equals(500));
      expect(fakeMfs.writes, isEmpty);
    });

    test('handleFilesWrite invalid offset', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/write?arg=/test&offset=-1'),
      );
      final response = await handlers.handleFilesWrite(request);
      expect(response.statusCode, equals(400));
    });

    test('handleFilesWrite invalid cid-version', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/write?arg=/test&cid-version=2'),
      );
      final response = await handlers.handleFilesWrite(request);
      expect(response.statusCode, equals(400));
    });

    test('handleFilesWrite missing content-type', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/write?arg=/test'),
        body: 'body',
      );
      final response = await handlers.handleFilesWrite(request);
      expect(response.statusCode, equals(500));
      expect(
        json.decode(await response.readAsString())['Message'],
        contains('Content-Type'),
      );
    });

    test('handleFilesWrite invalid content-type', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/write?arg=/test'),
        headers: {'content-type': 'text/plain'},
        body: 'body',
      );
      final response = await handlers.handleFilesWrite(request);
      expect(response.statusCode, equals(500));
      expect(
        json.decode(await response.readAsString())['Message'],
        contains('boundary'),
      );
    });

    test('handleFilesWrite empty multipart', () async {
      const boundary = 'boundary';
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/write?arg=/test'),
        headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        body: '--$boundary--\r\n',
      );
      final response = await handlers.handleFilesWrite(request);
      expect(response.statusCode, equals(500));
      expect(
        json.decode(await response.readAsString())['Message'],
        contains('No file content'),
      );
    });

    test('handleFilesWrite error path', () async {
      fakeMfs.shouldThrow = true;
      const boundary = 'boundary';
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/write?arg=/test'),
        headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        body: '--$boundary\r\n\r\ncontent\r\n--$boundary--\r\n',
      );
      final response = await handlers.handleFilesWrite(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesMkdir success', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/mkdir?arg=/new&parents=true&recursive=true'),
      );
      final response = await handlers.handleFilesMkdir(request);
      expect(response.statusCode, equals(200));
      expect(fakeMfs.lastMkdirPath, equals('/new'));
    });

    test('handleFilesMkdir missing path', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/files/mkdir'));
      final response = await handlers.handleFilesMkdir(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesMkdir invalid cid-version', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/mkdir?arg=/new&cid-version=-1'),
      );
      final response = await handlers.handleFilesMkdir(request);
      expect(response.statusCode, equals(400));
    });

    test('handleFilesMkdir error path', () async {
      fakeMfs.shouldThrow = true;
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/mkdir?arg=/new'),
      );
      final response = await handlers.handleFilesMkdir(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesCp success', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/cp?arg=/src&arg=/dst'),
      );
      final response = await handlers.handleFilesCp(request);
      expect(response.statusCode, equals(200));
      expect(fakeMfs.lastCpSrc, equals('/src'));
      expect(fakeMfs.lastCpDst, equals('/dst'));
    });

    test('handleFilesCp missing args', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/cp?arg=/src'),
      );
      final response = await handlers.handleFilesCp(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesCp blocked path returns 451', () async {
      fakeDenylist.blockedPaths.add('/src');
      fakeDenylist.action = 'block';
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/cp?arg=/src&arg=/dst'),
      );
      final response = await handlers.handleFilesCp(request);
      expect(response.statusCode, equals(451));
    });

    test('handleFilesCp blocked path log action proceeds', () async {
      fakeDenylist.blockedPaths.add('/src');
      fakeDenylist.action = 'log';
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/cp?arg=/src&arg=/dst'),
      );
      final response = await handlers.handleFilesCp(request);
      expect(response.statusCode, equals(200));
    });

    test('handleFilesCp denylist disabled', () async {
      fakeDenylist.configuredEnabled = false;
      fakeDenylist.blockedPaths.add('/src');
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/cp?arg=/src&arg=/dst'),
      );
      final response = await handlers.handleFilesCp(request);
      expect(response.statusCode, equals(200));
    });

    test('handleFilesCp error path', () async {
      fakeMfs.shouldThrow = true;
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/cp?arg=/src&arg=/dst'),
      );
      final response = await handlers.handleFilesCp(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesMv success', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/mv?arg=/src&arg=/dst'),
      );
      final response = await handlers.handleFilesMv(request);
      expect(response.statusCode, equals(200));
      expect(fakeMfs.lastMvSrc, equals('/src'));
      expect(fakeMfs.lastMvDst, equals('/dst'));
    });

    test('handleFilesMv blocked path', () async {
      fakeDenylist.blockedPaths.add('/src');
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/mv?arg=/src&arg=/dst'),
      );
      final response = await handlers.handleFilesMv(request);
      expect(response.statusCode, equals(451));
    });

    test('handleFilesMv missing args', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/mv?arg=/src'),
      );
      final response = await handlers.handleFilesMv(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesMv error path', () async {
      fakeMfs.shouldThrow = true;
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/mv?arg=/src&arg=/dst'),
      );
      final response = await handlers.handleFilesMv(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesRm success', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/rm?arg=/file&recursive=true&force=true'),
      );
      final response = await handlers.handleFilesRm(request);
      expect(response.statusCode, equals(200));
      expect(fakeMfs.lastRmPath, equals('/file'));
    });

    test('handleFilesRm missing path', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/files/rm'));
      final response = await handlers.handleFilesRm(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesRm error path', () async {
      fakeMfs.shouldThrow = true;
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/rm?arg=/file'),
      );
      final response = await handlers.handleFilesRm(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesFlush success', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/flush?arg=/'),
      );
      final response = await handlers.handleFilesFlush(request);
      expect(response.statusCode, equals(200));
      final body = json.decode(await response.readAsString());
      expect(body['Hash'], equals('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'));
    });

    test('handleFilesFlush error path', () async {
      fakeMfs.shouldThrow = true;
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/flush'),
      );
      final response = await handlers.handleFilesFlush(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesChcid success', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/chcid?arg=/test&cid-version=1&hash=sha2-256'),
      );
      final response = await handlers.handleFilesChcid(request);
      expect(response.statusCode, equals(200));
      expect(fakeMfs.lastChcidPath, equals('/test'));
      expect(fakeMfs.lastChcidVersion, equals(1));
    });

    test('handleFilesChcid missing path', () async {
      final request = Request('POST', Uri.parse('http://localhost/api/v0/files/chcid'));
      final response = await handlers.handleFilesChcid(request);
      expect(response.statusCode, equals(500));
    });

    test('handleFilesChcid invalid cid-version', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/chcid?arg=/test&cid-version=2'),
      );
      final response = await handlers.handleFilesChcid(request);
      expect(response.statusCode, equals(400));
    });

    test('handleFilesChcid error path', () async {
      fakeMfs.shouldThrow = true;
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v0/files/chcid?arg=/test'),
      );
      final response = await handlers.handleFilesChcid(request);
      expect(response.statusCode, equals(500));
    });
  });
}
