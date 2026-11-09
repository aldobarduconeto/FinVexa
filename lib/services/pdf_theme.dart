import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

Future<pw.ThemeData> loadPdfTheme() async => pw.ThemeData.withFont(
  base: pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf')),
  bold: pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf')),
);
