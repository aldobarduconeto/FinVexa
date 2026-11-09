import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel_plus/excel_plus.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/analytics.dart';
import '../models/finance.dart';
import '../models/import_table.dart';
import '../models/monthly_report.dart';
import 'pdf_theme.dart';

const _legacyColumns = [
  'indicador',
  'valor',
  'periodo',
  'empresa',
  'categoria',
  'moeda',
];
const _columns = [..._legacyColumns, 'relatorio'];
const _delimitedMarker = 'finvexa_mensal_v1';
const _pdfMarker = '%FinVexaMonthlyV1:';
final _formulaPrefix = RegExp(r'^\s*[=+@\-\t\r]');

List<List<dynamic>> _validatedRows(MonthlyReport report) {
  final company = report.company.trim();
  if (company.isEmpty) throw const FormatException('Informe a empresa.');
  final period = normalizePeriod(report.period);
  final title = report.title.trim();
  if (title.isEmpty) {
    throw const FormatException('Informe o título do relatório.');
  }
  final currency = normalizeCurrency(report.currency);
  if (report.lines.isEmpty) {
    throw const FormatException('Preencha pelo menos um indicador.');
  }
  final descriptions = <String>{};
  return report.lines.map((line) {
    final description = line.description.trim();
    if (description.isEmpty || !line.amount.isFinite) {
      throw const FormatException(
        'Preencha o nome e um valor válido para cada rubrica.',
      );
    }
    if (!descriptions.add(normalized(description))) {
      throw FormatException('A rubrica "$description" está repetida.');
    }
    return <dynamic>[
      description,
      line.amount,
      period,
      company,
      line.category,
      currency,
      title,
    ];
  }).toList();
}

Future<Uint8List> encodeMonthlyReport(
  MonthlyReport report, {
  MonthlyReportFormat format = MonthlyReportFormat.json,
}) async {
  final rows = _validatedRows(report);
  switch (format) {
    case MonthlyReportFormat.json:
      return Uint8List.fromList(
        utf8.encode(
          const JsonEncoder.withIndent('  ').convert({
            'entries': [
              for (final row in rows)
                Map<String, dynamic>.fromIterables(_columns, row),
            ],
          }),
        ),
      );
    case MonthlyReportFormat.csv:
    case MonthlyReportFormat.tsv:
      return Uint8List.fromList(
        utf8.encode(
          '\ufeff${ListToCsvConverter(fieldDelimiter: format == MonthlyReportFormat.csv ? ';' : '\t').convert([
            [..._columns, _delimitedMarker],
            for (final row in rows) [for (final cell in row) _escapeCell(cell), '1'],
          ])}',
        ),
      );
    case MonthlyReportFormat.xlsx:
      final workbook = xl.Excel.createExcel();
      workbook.rename('Sheet1', 'Relatório financeiro');
      final sheet = workbook['Relatório financeiro'];
      for (final row in [_columns, ...rows]) {
        sheet.appendRow([
          for (final cell in row)
            cell is double
                ? xl.DoubleCellValue(cell)
                : xl.TextCellValue(cell.toString()),
        ]);
      }
      sheet.setColumnWidth(0, 44);
      sheet.setColumnWidth(3, 28);
      return Uint8List.fromList(workbook.encode()!);
    case MonthlyReportFormat.pdf:
      return _encodePdf(rows);
  }
}

dynamic _escapeCell(dynamic cell) =>
    cell is String && (cell.startsWith("'") || _formulaPrefix.hasMatch(cell))
    ? "'$cell"
    : cell;

ImportTable? monthlyTableFromDelimited(String name, List<List<dynamic>> rows) {
  if (rows.isEmpty) return null;
  final header = rows.first.join('|');
  final columns = header == [..._columns, _delimitedMarker].join('|')
      ? _columns
      : header == [..._legacyColumns, _delimitedMarker].join('|')
      ? _legacyColumns
      : null;
  if (columns == null) return null;
  final values = <List<dynamic>>[];
  for (final row in rows.skip(1)) {
    if (row.every((cell) => cell == null || cell.toString().trim().isEmpty)) {
      continue;
    }
    if (row.length != columns.length + 1 || row.last != '1') {
      throw const FormatException('Linha inválida no relatório mensal.');
    }
    values.add([
      for (var i = 0; i < columns.length; i++)
        if (i == 1)
          parseAmount(row[i])
        else
          row[i].toString().replaceFirst(RegExp(r"^'"), ''),
    ]);
  }
  return ImportTable(name, columns, values);
}

Future<Uint8List> _encodePdf(List<List<dynamic>> rows) async {
  final doc = pw.Document(
    theme: await loadPdfTheme(),
    title: rows.first.last as String,
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 1000,
      build: (_) => [
        pw.Text(
          rows.first.last as String,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          '${rows.first[3]} | Competência ${rows.first[2]} | ${rows.first[5]}',
        ),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: ['Indicador', 'Valor', 'Categoria'],
          data: [
            for (final row in rows) [row[0], row[1].toString(), row[4]],
          ],
        ),
      ],
    ),
  );
  final pdf = await doc.save();
  // A comment before startxref keeps the PDF cross-reference offsets intact.
  final trailer = latin1.decode(pdf).lastIndexOf('\nstartxref');
  if (trailer < 0) throw StateError('PDF sem tabela de referências.');
  final payload = base64Encode(utf8.encode(jsonEncode(rows)));
  final comments = StringBuffer();
  for (var offset = 0; offset < payload.length; offset += 120) {
    final end = offset + 120 < payload.length ? offset + 120 : payload.length;
    comments.write('\n$_pdfMarker${payload.substring(offset, end)}');
  }
  return (BytesBuilder(copy: false)
        ..add(Uint8List.sublistView(pdf, 0, trailer))
        ..add(ascii.encode(comments.toString()))
        ..add(Uint8List.sublistView(pdf, trailer)))
      .takeBytes();
}

ImportTable? monthlyTableFromPdf(String name, Uint8List bytes) {
  final text = latin1.decode(bytes);
  if (!text.startsWith('%PDF-')) return null;
  final trailer = text.lastIndexOf('\nstartxref');
  if (trailer < 0) return null;
  final chunks = <String>[];
  var end = trailer;
  while (end > 0) {
    final start = text.lastIndexOf('\n', end - 1) + 1;
    if (!text.startsWith(_pdfMarker, start)) break;
    chunks.add(text.substring(start + _pdfMarker.length, end));
    end = start - 1;
  }
  if (chunks.isEmpty) return null;
  final decoded = jsonDecode(utf8.decode(base64Decode(chunks.reversed.join())));
  if (decoded is! List ||
      decoded.isEmpty ||
      decoded.first is! List ||
      decoded.any(
        (row) =>
            row is! List ||
            (row.length != _columns.length &&
                row.length != _legacyColumns.length) ||
            row.length != (decoded.first as List).length ||
            row[1] is! num,
      )) {
    throw const FormatException(
      'Dados estruturados inválidos no relatório PDF.',
    );
  }
  return ImportTable(
    name,
    (decoded.first as List).length == _columns.length
        ? _columns
        : _legacyColumns,
    decoded.map((row) => List<dynamic>.from(row as List)).toList(),
    warning: 'Dados estruturados do relatório mensal FinVexa. Confira a prévia antes de confirmar.',
  );
}
