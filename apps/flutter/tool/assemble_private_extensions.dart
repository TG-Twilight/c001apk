import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Run from apps/flutter. Public builds need no assembly step or credentials.
Future<void> main(List<String> arguments) async {
  try {
    await assemble(arguments);
  } catch (error) {
    stderr.writeln('Private extension assembly failed: $error');
    exitCode = 1;
  }
}

Future<void> assemble(List<String> arguments) async {
  String? source, output;
  var inPlace = false;
  for (var i = 0; i < arguments.length; i++) {
    switch (arguments[i]) {
      case '--source':
        source = arguments[++i];
      case '--output':
        output = arguments[++i];
      case '--in-place':
        inPlace = true;
      default:
        throw ArgumentError('Unknown argument: ${arguments[i]}');
    }
  }
  if (source == null || (output == null) == !inPlace) {
    throw ArgumentError(
        'Use --source <private clone> and either --output <new directory> or --in-place (GitHub Actions only)');
  }
  final root = Directory('../..').resolveSymbolicLinksSync();
  final private = Directory(source).resolveSymbolicLinksSync();
  final lock =
      jsonDecode(File('$root/private-extensions.lock.json').readAsStringSync())
          as Map;
  final expected = lock['revision'] as String;
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(expected)) {
    throw StateError('Private revision must be a full commit SHA');
  }
  final revision = await git(private, ['rev-parse', 'HEAD']);
  if (revision.trim() != expected) {
    throw StateError('Private checkout revision does not match the lock');
  }
  if ((await git(private, ['status', '--porcelain'])).trim().isNotEmpty) {
    throw StateError('Private checkout has uncommitted changes');
  }
  final manifest =
      jsonDecode(File('$private/manifest.json').readAsStringSync()) as Map;
  if (manifest['schemaVersion'] != 1 ||
      manifest['interfaceVersion'] != lock['interfaceVersion']) {
    throw StateError('Unsupported private interface version');
  }
  final files = manifest['files'] as List;
  if (files.isEmpty || files.length > 2000) {
    throw StateError('Invalid overlay size');
  }
  final validated = <String, List<int>>{};
  for (final entry in files.cast<Map>()) {
    final path = entry['path'] as String;
    if (!allowed(path) || validated.containsKey(path)) {
      throw StateError('Invalid overlay path: $path');
    }
    final file = File('$private/overlay/$path');
    final resolved = file.resolveSymbolicLinksSync();
    if (!within(resolved, '$private/overlay')) {
      throw StateError('Overlay link escapes source');
    }
    final bytes = file.readAsBytesSync();
    if (sha256.convert(bytes).toString() != entry['sha256']) {
      throw StateError('Overlay digest mismatch: $path');
    }
    validated[path] = bytes;
  }
  final paths = (await git(root,
          ['ls-files', '--cached', '--others', '--exclude-standard', '-z']))
      .split('\x00')
      .where((path) => path.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  final publicFiles = <String, String>{};
  for (final path in paths) {
    final input = File('$root/$path');
    if (!input.existsSync()) continue;
    if (!within(input.resolveSymbolicLinksSync(), root)) {
      throw StateError('Public source link escapes checkout');
    }
    publicFiles[path] = sha256.convert(input.readAsBytesSync()).toString();
  }
  final publicRevision = (await git(root, ['rev-parse', 'HEAD'])).trim();
  final publicDirty =
      (await git(root, ['status', '--porcelain'])).trim().isNotEmpty;
  late final String destination;
  if (inPlace) {
    if (Platform.environment['GITHUB_ACTIONS'] != 'true' ||
        Platform.environment['GITHUB_REPOSITORY'] != 'TG-Twilight/c001apk' ||
        !{'push', 'workflow_dispatch'}
            .contains(Platform.environment['GITHUB_EVENT_NAME']) ||
        !{'refs/heads/main', 'refs/heads/test'}
            .contains(Platform.environment['GITHUB_REF'])) {
      throw StateError(
          'In-place assembly is restricted to trusted main/test Actions builds');
    }
    destination = root;
  } else {
    destination = Directory.current.uri.resolve('$output/').toFilePath();
    final local = Directory('$root/.local').resolveSymbolicLinksSync();
    if (!within(destination, local)) {
      throw StateError(
          'Local assembly output must be inside this checkout .local directory');
    }
    if (Directory(destination).existsSync()) {
      throw StateError(
          'Assembly output already exists; choose a new directory');
    }
    Directory(destination).createSync(recursive: true);
    for (final path in publicFiles.keys) {
      final input = File('$root/$path');
      if (!input.existsSync()) continue;
      final target = File('$destination/$path');
      target.parent.createSync(recursive: true);
      input.copySync(target.path);
    }
  }
  // Validate the entire overlay before any replacement; tooling/workflows,
  // signing configuration and pubspec/lockfile cannot be replaced by it.
  for (final entry in validated.entries) {
    final target = File('$destination/${entry.key}');
    target.parent.createSync(recursive: true);
    if (!within(target.parent.resolveSymbolicLinksSync(), destination)) {
      throw StateError('Output link escapes destination');
    }
    target.writeAsBytesSync(entry.value);
  }
  final provenance = File('$destination/.private-build-provenance.json');
  provenance.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({
        'repository': lock['repository'],
        'revision': expected,
        'interfaceVersion': manifest['interfaceVersion'],
        'manifestSha256': sha256
            .convert(File('$private/manifest.json').readAsBytesSync())
            .toString(),
        'overlayFiles': validated.length,
        'publicRevision': publicRevision,
        'publicDirty': publicDirty,
        'publicSnapshotSha256':
            sha256.convert(utf8.encode(jsonEncode(publicFiles))).toString(),
        'publicFiles': publicFiles,
      })}\n');
  stdout.writeln(
      'Official extensions assembled: ${validated.length} verified files at $expected');
  if (!inPlace) {
    stdout.writeln('Flutter working directory: $destination/apps/flutter');
  }
}

bool within(String path, String parent) {
  String normalize(String value) {
    final path = value.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), '');
    return Platform.isWindows ? path.toLowerCase() : path;
  }

  return normalize(path).startsWith('${normalize(parent)}/');
}

bool allowed(String path) {
  if (path.contains('\\') ||
      path.contains(':') ||
      path
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..')) {
    return false;
  }
  if (path ==
      'apps/flutter/lib/components/settings/media_auto_load_settings.dart') {
    return true;
  }
  return RegExp(
          r'^apps/flutter/(lib/(components/(liquid_[a-z_]+\.dart|media_[a-z_]+\.dart|imageview\.dart)|constants/(liquid_glass_level|implementation_variant)\.dart|logic/media/[a-z_]+\.dart|pages/others/imageview_page\.dart|utils/download_util\.dart)|shaders/[a-z_]+\.frag|third_party/(liquid_navigation|native_media)/[A-Za-z0-9_./-]+|android/app/src/(main/(AndroidManifest\.xml|kotlin/app/awavenue/c001apk/(Media[A-Za-z]+|MainActivity)\.kt)|test/[A-Za-z0-9_./-]+)|windows/(runner/(media_[a-z_]+\.(cpp|h)|flutter_window\.(cpp|h)|CMakeLists\.txt|tests/[A-Za-z0-9_./-]+)|cmake/media_dependencies\.cmake)|test/(media/[A-Za-z0-9_./-]+|ui/(liquid_[a-z_]+|imageview[a-z_]*|media_[a-z_]+|body_media_owner_test|profile_glass_test)\.dart))$')
      .hasMatch(path);
}

Future<String> git(String directory, List<String> arguments) async {
  final result = await Process.run('git', ['-C', directory, ...arguments]);
  if (result.exitCode != 0) {
    throw StateError('Git operation failed: ${arguments.first}');
  }
  return result.stdout as String;
}
