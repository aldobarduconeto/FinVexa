import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

import 'save_bytes_stub.dart' if (dart.library.io) 'save_bytes_io.dart';

Future<FilePickerResult?> pickReportFiles(
  List<String> extensions, {
  bool multiple = false,
}) => FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: extensions,
  withData: true,
  allowMultiple: multiple,
);

Future<bool> saveReportFile({
  required String title,
  required String name,
  required String extension,
  required Uint8List bytes,
}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: title,
    fileName: name,
    type: FileType.custom,
    allowedExtensions: [extension],
    bytes: bytes,
  );
  if (path == null) return false;
  await completePickedFile(path, bytes);
  return true;
}

Future<bool> printReportPdf(String name, Uint8List bytes) =>
    Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
