import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves assets from a directory on disk, like the app's asset bundle.
class DirectoryBundle extends CachingAssetBundle {
  final String root;

  DirectoryBundle(this.root);

  @override
  Future<ByteData> load(String key) async {
    final bytes = await File('$root/$key').readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

/// Serves in-memory JSON strings keyed by asset path.
class MapBundle extends CachingAssetBundle {
  final Map<String, String> files;

  MapBundle(this.files);

  @override
  Future<ByteData> load(String key) async {
    final s = files[key];
    if (s == null) throw StateError('missing asset $key');
    return ByteData.sublistView(Uint8List.fromList(s.codeUnits));
  }
}

/// Loads Roboto and Material Icons from the Flutter SDK so screenshots show
/// real text instead of the test font's boxes.
Future<void> loadRealFonts() async {
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final dir = '$flutterRoot/bin/cache/artifacts/material_fonts';
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File('$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await family('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]);
  await family('MaterialIcons', ['MaterialIcons-Regular.otf']);
}
