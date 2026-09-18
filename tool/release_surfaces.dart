// tool/release_surfaces.dart
//
// Release surface manager for dart_ipfs.
//
// `version` in pubspec.yaml is the single source of truth. This tool keeps
// every version-bearing file in sync with it and audits them as a publish
// gate. Run from the repository root:
//
//   dart run tool/release_surfaces.dart --list
//   dart run tool/release_surfaces.dart --check [--tag v1.2.3]
//   dart run tool/release_surfaces.dart --sync
//
// --check exits non-zero when any surface drifts, when the CHANGELOG lacks a
// section for the current version, when a hardcoded version literal survives
// in lib/, or when --tag disagrees with the pubspec it would publish.
// --sync rewrites every managed surface to the pubspec version.
//
// ignore_for_file: avoid_print
import 'dart:io';

/// Semver-ish capture group used by every managed pattern.
const semverGroup = r'(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)';

/// A file region whose embedded version must equal the pubspec version.
/// The pattern must contain exactly one capture group: the version string.
class Surface {
  const Surface(this.path, this.pattern, this.description);

  final String path;
  final RegExp pattern;
  final String description;
}

/// Umbrella-package release surfaces, updated on every `v*` release.
final surfaces = <Surface>[
  Surface('lib/src/version.dart',
      RegExp("packageVersion = '$semverGroup'"), 'package version constant'),
  Surface('docker-compose.yml', RegExp('dart-ipfs:$semverGroup'),
      'compose image tag'),
  Surface('docker-compose.debug.yml',
      RegExp('dart-ipfs:$semverGroup-debug'), 'debug compose image tag'),
  Surface('helm/dart-ipfs/Chart.yaml', RegExp('appVersion: "$semverGroup"'),
      'chart appVersion'),
  Surface('helm/dart-ipfs/README.md', RegExp('dart-ipfs:$semverGroup'),
      'chart README image tag'),
  Surface('k8s/base/deployment.yaml', RegExp('dart-ipfs:$semverGroup'),
      'k8s base image tag'),
  Surface('k8s/base/kustomization.yaml', RegExp('newTag: "$semverGroup"'),
      'k8s base overlay tag'),
  Surface('k8s/overlays/production/kustomization.yaml',
      RegExp('newTag: "$semverGroup"'), 'k8s production overlay tag'),
  Surface('README.md', RegExp('dart_ipfs: \\^$semverGroup'),
      'README install snippet'),
  Surface('README.md', RegExp('\\(current: v$semverGroup\\)'),
      'README current-release marker'),
  Surface('ROADMAP.md', RegExp('\\*\\*Current Version:?\\*\\*:? $semverGroup'),
      'roadmap current version'),
  Surface('ROADMAP.md', RegExp('Last Updated[^\\n]*\\(v$semverGroup\\)'),
      'roadmap footer version'),
];

void main(List<String> args) => exit(run(args));

int run(List<String> args) {
  final root = _argValue(args, '--root') ?? '.';
  final tag = _argValue(args, '--tag');
  final mode = args.contains('--sync')
      ? 'sync'
      : args.contains('--list')
          ? 'list'
          : 'check';

  if (mode == 'list') {
    for (final s in surfaces) {
      print('${s.path}  —  ${s.description}');
    }
    return 0;
  }

  final version = _pubspecVersion('$root/pubspec.yaml');
  if (version == null) {
    print('ERROR: no version field in $root/pubspec.yaml');
    return 2;
  }

  var failures = 0;
  for (final s in surfaces) {
    final file = File('$root/${s.path}');
    if (!file.existsSync()) {
      print('MISSING  ${s.path} (${s.description})');
      failures++;
      continue;
    }
    final content = file.readAsStringSync();
    final found =
        s.pattern.allMatches(content).map((m) => m.group(1)!).toSet();

    if (mode == 'sync') {
      if (found.isEmpty) {
        print('NOMATCH  ${s.path} (${s.description}) — pattern found nothing');
        failures++;
        continue;
      }
      if (found.length == 1 && found.single == version) {
        print('OK       ${s.path} (${s.description})');
        continue;
      }
      file.writeAsStringSync(_replaceGroup(content, s.pattern, version));
      print('SYNCED   ${s.path} (${s.description}): $found -> $version');
      continue;
    }

    if (found.isEmpty) {
      print('NOMATCH  ${s.path} (${s.description}) — pattern found nothing');
      failures++;
    } else if (found.length == 1 && found.single == version) {
      print('OK       ${s.path} (${s.description})');
    } else {
      print('DRIFT    ${s.path} (${s.description}): found $found, '
          'expected $version');
      failures++;
    }
  }

  failures += _checkChangelog(root, version);
  failures += _checkLibLiterals(root);
  if (tag != null) failures += _checkTag(root, tag);

  if (mode == 'sync') {
    print(failures == 0
        ? 'All surfaces synced to $version.'
        : '$failures surface(s) could not be synced.');
    return failures == 0 ? 0 : 1;
  }
  print(failures == 0
      ? 'All release surfaces match pubspec version $version.'
      : '$failures release surface check(s) FAILED.');
  return failures == 0 ? 0 : 1;
}

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

String? _pubspecVersion(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  for (final line in file.readAsLinesSync()) {
    final m = RegExp(r'^version:\s*(\S+)').firstMatch(line);
    if (m != null) return m.group(1);
  }
  return null;
}

/// Replaces the first capture group of every [pattern] match with [version].
String _replaceGroup(String content, RegExp pattern, String version) {
  return content.replaceAllMapped(pattern, (m) {
    final whole = m.group(0)!;
    final old = m.group(1)!;
    final at = whole.indexOf(old);
    return '${whole.substring(0, at)}$version${whole.substring(at + old.length)}';
  });
}

int _checkChangelog(String root, String version,
    {String path = 'CHANGELOG.md'}) {
  final file = File('$root/$path');
  if (!file.existsSync()) {
    print('MISSING  $path');
    return 1;
  }
  final has = RegExp('^## \\[${RegExp.escape(version)}\\]',
          multiLine: true)
      .hasMatch(file.readAsStringSync());
  if (has) {
    print('OK       $path has a [$version] section');
    return 0;
  }
  print('DRIFT    $path has no [$version] section');
  return 1;
}

/// Guards against re-introduced hardcoded `dart_ipfs/x.y.z` or
/// `'version': 'x.y.z'` literals in lib/ (version.dart is the only exception).
int _checkLibLiterals(String root) {
  var failures = 0;
  final agent = RegExp('dart_ipfs/$semverGroup');
  final mapVer = RegExp("'version': '$semverGroup");
  for (final entity in Directory('$root/lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    if (entity.path.endsWith('lib/src/version.dart')) continue;
    final rel = entity.path.substring(root.length + 1);
    var lineNo = 0;
    for (final line in entity.readAsLinesSync()) {
      lineNo++;
      if (agent.hasMatch(line) || mapVer.hasMatch(line)) {
        print('DRIFT    $rel:$lineNo — hardcoded version literal '
            '(use packageVersion/agentVersion from src/version.dart)');
        failures++;
      }
    }
  }
  if (failures == 0) {
    print('OK       lib/ has no hardcoded version literals');
  }
  return failures;
}

/// Verifies a release tag against the pubspec it would publish:
/// `v*` -> umbrella, `core-v*` -> packages/dart_ipfs_core,
/// `quic-v*` -> packages/dart_ipfs_quic.
int _checkTag(String root, String tag) {
  final m = RegExp('^(?:(core|quic)-)?v$semverGroup\$').firstMatch(tag);
  if (m == null) {
    print('ERROR    unrecognized tag format: $tag');
    return 1;
  }
  final sub = m.group(1);
  final tagVersion = m.group(2)!;
  final dir = sub == null ? root : '$root/packages/dart_ipfs_$sub';
  final pubspecVersion = _pubspecVersion('$dir/pubspec.yaml');
  if (pubspecVersion == null) {
    print('MISSING  $dir/pubspec.yaml');
    return 1;
  }
  var failures = 0;
  if (pubspecVersion == tagVersion) {
    print('OK       tag $tag matches $dir/pubspec.yaml');
  } else {
    print('DRIFT    tag $tag but $dir/pubspec.yaml is $pubspecVersion');
    failures++;
  }
  if (sub != null) {
    failures += _checkChangelog(root, tagVersion,
        path: 'packages/dart_ipfs_$sub/CHANGELOG.md');
  }
  return failures;
}
