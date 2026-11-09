import 'dart:io';
import 'dart:typed_data';

Future<void> completePickedFile(String path, Uint8List bytes) async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
}
