import 'dart:io';

import 'package:test/test.dart';

import '../../tool/release_surfaces.dart';

void main() {
  group('release_surfaces', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('release_surfaces_test');
      _writeFixture(root.path);
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('check passes when every surface matches', () {
      expect(run(['--check', '--root', root.path]), 0);
    });

    test('check fails on a drifted surface', () {
      File('${root.path}/docker-compose.yml')
          .writeAsStringSync('image: x/dart-ipfs:0.0.1\n');
      expect(run(['--check', '--root', root.path]), 1);
    });

    test('check fails when CHANGELOG lacks the version section', () {
      File('${root.path}/CHANGELOG.md').writeAsStringSync('# Changelog\n');
      expect(run(['--check', '--root', root.path]), 1);
    });

    test('check fails on hardcoded version literals in lib/', () {
      File('${root.path}/lib/src/evil.dart').writeAsStringSync(
        "const s = 'dart_ipfs/0.0.1';\n",
      );
      expect(run(['--check', '--root', root.path]), 1);
    });

    test('sync rewrites drifted surfaces and re-check passes', () {
      File('${root.path}/ROADMAP.md').writeAsStringSync(
        '**Current Version**: 0.0.1\n**Last Updated**: d (v0.0.1)\n',
      );
      expect(run(['--check', '--root', root.path]), 1);
      expect(run(['--sync', '--root', root.path]), 0);
      expect(run(['--check', '--root', root.path]), 0);
      expect(
        File('${root.path}/ROADMAP.md').readAsStringSync(),
        contains('**Current Version**: 9.9.9'),
      );
    });

    test('tag matching verifies umbrella and sub-package pubspecs', () {
      expect(run(['--check', '--root', root.path, '--tag', 'v9.9.9']), 0);
      expect(run(['--check', '--root', root.path, '--tag', 'v9.9.8']), 1);
      expect(
        run(['--check', '--root', root.path, '--tag', 'core-v0.0.1']),
        0,
      );
      expect(
        run(['--check', '--root', root.path, '--tag', 'quic-v9.9.9']),
        1,
      );
    });
  });
}

void _writeFixture(String root) {
  const v = '9.9.9';
  final files = <String, String>{
    'pubspec.yaml': 'name: x\nversion: $v\n',
    'CHANGELOG.md': '# Changelog\n\n## [$v] - 2026-01-01\n',
    'lib/src/version.dart': "const String packageVersion = '$v';\n",
    'docker-compose.yml': 'image: x/dart-ipfs:$v\n',
    'docker-compose.debug.yml': 'image: x/dart-ipfs:$v-debug\n',
    'helm/dart-ipfs/Chart.yaml': 'appVersion: "$v"\n',
    'helm/dart-ipfs/README.md': 'dart-ipfs:$v\n',
    'k8s/base/deployment.yaml': 'dart-ipfs:$v\n',
    'k8s/base/kustomization.yaml': 'newTag: "$v"\n',
    'k8s/overlays/production/kustomization.yaml': 'newTag: "$v"\n',
    'README.md': '  dart_ipfs: ^$v\n(current: v$v)\n',
    'ROADMAP.md': '**Current Version**: $v\n**Last Updated**: d (v$v)\n',
    'packages/dart_ipfs_core/pubspec.yaml': 'name: c\nversion: 0.0.1\n',
    'packages/dart_ipfs_core/CHANGELOG.md': '## [0.0.1]\n',
    'packages/dart_ipfs_quic/pubspec.yaml': 'name: q\nversion: 0.0.2\n',
    'packages/dart_ipfs_quic/CHANGELOG.md': '## [0.0.2]\n',
  };
  files.forEach((path, content) {
    final file = File('$root/$path')..createSync(recursive: true);
    file.writeAsStringSync(content);
  });
}
