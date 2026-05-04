import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class FileStorageHelper {
  FileStorageHelper._();

  static Future<File> savePdfToUserVisibleLocation({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final candidates = <Directory>[];

    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        candidates.add(downloads);
      }
    } catch (_) {}

    if (Platform.isAndroid) {
      candidates.add(Directory('/storage/emulated/0/Download'));
      candidates.add(Directory('/sdcard/Download'));
      try {
        final external = await getExternalStorageDirectory();
        if (external != null) {
          candidates.add(external);
        }
      } catch (_) {}
    }

    try {
      candidates.add(await getApplicationDocumentsDirectory());
    } catch (_) {}

    candidates.add(Directory.systemTemp);

    for (final dir in candidates) {
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        return file;
      } catch (_) {
        // Try next candidate directory.
      }
    }

    throw const FileSystemException('Unable to save file in any known directory');
  }
}
