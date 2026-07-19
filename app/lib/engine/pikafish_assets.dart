// Copies the bundled NNUE network (declared as a Flutter asset — see
// pubspec.yaml and native/scripts/fetch-pikafish-net.sh) out to a plain
// filesystem path the native engine can open with fopen(). Flutter assets
// live inside the app bundle's asset archive, not as loose files, so
// Pikafish's `EvalFile` UCI option can't point at them directly.
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class PikafishAssets {
  /// [documentsDirOverride] lets tests point this at a temp directory
  /// instead of going through the path_provider platform channel.
  const PikafishAssets({this.documentsDirOverride});

  final Future<Directory> Function()? documentsDirOverride;

  /// Extracts `assets/pikafish.nnue` to the app's documents directory (if
  /// not already there) and returns its absolute path. Cheap to call
  /// repeatedly — skips the copy once the file exists.
  Future<String> ensureNetworkFile() async {
    final docs = documentsDirOverride != null
        ? await documentsDirOverride!()
        : await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/pikafish.nnue');

    if (!await file.exists()) {
      final data = await rootBundle.load('assets/pikafish.nnue');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    return file.path;
  }
}
