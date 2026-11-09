import 'package:finvexa/services/pdf_theme.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel_plus/excel_plus.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:finvexa/models/analytics.dart';

import '../models/export_snapshot.dart';
export '../models/export_snapshot.dart';

String display(dynamic value) => value == null
    ? 'N/D'
    : value is double
    ? value.toStringAsFixed(2)
    : value.toString();
String safeCsv(dynamic value) {
  final s = display(value);
  return value is String && RegExp(r'^\s*[=+@\-\t\r]').hasMatch(s) ? "'$s" : s;
}

Uint8List exportCsv(ExportSnapshot snapshot) {
  final o = snapshot.options;
  final rows = <List<dynamic>>[
    ['SEÇÃO', 'DADOS'],
    ['Configuração', o.title],
    ['Filtros', snapshot.analysis.filter.summary],
    ['Agrupamento', snapshot.analysis.mode],
    ['Base', snapshot.base],
    ['Observações', o.notes],
    [
      'Método',
      'Variação = (comparado-base)/abs(base)*100. N/D: ausente/base zero. Não há conversão cambial.',
    ],
    if (o.charts) ...[
      ['INDICADORES'],
      metricHeaders,
      ...snapshot.metricRows,
    ],
    if (o.table) ...[
      ['COMPARAÇÃO'],
      comparisonHeaders,
      ...snapshot.comparisonRows,
    ],
    if (o.entries) ...[
      ['LANÇAMENTOS'],
      entryHeaders,
      ...snapshot.entryRows,
    ],
    if (o.audit) ...[
      ['AUDITORIA'],
      auditHeaders,
      ...snapshot.auditRows,
    ],
    if (o.history) ...[
      ['HISTÓRICO'],
      historyHeaders,
      ...snapshot.historyRows,
      ['RESULTADOS HISTÓRICOS'],
      historyResultHeaders,
      ...snapshot.historyResultRows,
    ],
  ];
  return Uint8List.fromList(
    utf8.encode(
      '\ufeff${ListToCsvConverter(fieldDelimiter: ';').convert(rows.map((r) => r.map(safeCsv).toList()).toList())}',
    ),
  );
}

Uint8List exportExcel(ExportSnapshot snapshot) {
  final workbook = xl.Excel.createExcel();
  workbook.rename('Sheet1', 'Configuração');
  void sheet(String name, List<String> headers, List<List<dynamic>> rows) {
    final s = workbook[name];
    for (final row in <List<dynamic>>[headers, ...rows]) {
      s.appendRow(
        row
            .map<xl.CellValue?>(
              (v) => v == null
                  ? null
                  : v is num
                  ? xl.DoubleCellValue(v.toDouble())
                  : xl.TextCellValue(v.toString()),
            )
            .toList(),
      );
    }
    for (var c = 0; c < headers.length; c++) {
      s
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('FF00368F'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
      );
      s.setColumnWidth(c, c == 0 ? 32 : 23);
    }
  }

  sheet(
    'Configuração',
    ['Campo', 'Valor'],
    [
      ['Título', snapshot.options.title],
      ['Observações', snapshot.options.notes],
      ['Filtros', snapshot.analysis.filter.summary],
      ['Base', snapshot.base],
      ['Agrupamento', snapshot.analysis.mode],
      [
        'Método',
        'Variação = (comparado-base)/abs(base)*100. Célula vazia: ausente ou base zero.',
      ],
      ['Moedas', 'Sem conversão cambial. Uma moeda por análise.'],
    ],
  );
  if (snapshot.options.table) {
    sheet('Comparação', comparisonHeaders, snapshot.comparisonRows);
  }
  if (snapshot.options.charts) {
    sheet('Indicadores', metricHeaders, snapshot.metricRows);
  }
  if (snapshot.options.entries) {
    sheet('Lançamentos', entryHeaders, snapshot.entryRows);
  }
  if (snapshot.options.audit) {
    sheet('Auditoria', auditHeaders, snapshot.auditRows);
  }
  if (snapshot.options.history) {
    sheet('Histórico', historyHeaders, snapshot.historyRows);
    sheet(
      'Histórico resultados',
      historyResultHeaders,
      snapshot.historyResultRows,
    );
  }
  if (snapshot.options.charts && snapshot.series.isNotEmpty) {
    sheet(
      'Gráficos',
      ['Série', ...categories],
      snapshot.series
          .map((s) => [s.label, ...categories.map(s.metric)])
          .toList(),
    );
    for (var i = 0; i < categories.length - 1; i++) {
      final col = String.fromCharCode(66 + i);
      workbook['Gráficos'].addChart(
        xl.Chart.column(
          anchor: xl.CellIndex.indexByColumnRow(
            columnIndex: 9,
            rowIndex: i * 18,
          ),
          title: categories[i],
          categories: 'A2:A${snapshot.series.length + 1}',
          series: [
            xl.ChartSeries(
              name: categories[i],
              values: '${col}2:$col${snapshot.series.length + 1}',
            ),
          ],
        ),
      );
    }
  }
  return Uint8List.fromList(workbook.encode()!);
}

Future<Uint8List> exportPdf(ExportSnapshot snapshot) async {
  final pdf = pw.Document(theme: await loadPdfTheme());
  final o = snapshot.options;
  final widgets = <pw.Widget>[
    pw.Text(
      'FINVEXA',
      style: pw.TextStyle(
        fontSize: 24,
        color: PdfColors.blue900,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
    pw.SizedBox(height: 8),
    pw.Text(o.title, style: const pw.TextStyle(fontSize: 20)),
    pw.Text('Gerado em ${DateTime.now().toIso8601String()}'),
    pw.SizedBox(height: 12),
    pw.Text(snapshot.analysis.filter.summary),
    pw.Text('Agrupamento: ${snapshot.analysis.mode} | Base: ${snapshot.base}'),
    pw.SizedBox(height: 8),
    pw.Text(
      'Variação = (comparado-base)/abs(base) x 100. N/D: ausente ou base zero. Sem conversão cambial. Categorias e sinais são preservados; crescimento não implica melhora. Indicadores de lucro, caixa e patrimônio são exibidos apenas quando informados nos arquivos.',
    ),
    if (o.notes.trim().isNotEmpty) ...[
      pw.SizedBox(height: 12),
      pw.Text(
        'Observações',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(o.notes),
    ],
  ];
  void table(String title, List<String> headers, List<List<dynamic>> rows) {
    widgets.addAll([
      pw.SizedBox(height: 18),
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      if (rows.isEmpty)
        pw.Text('Sem registros neste recorte.')
      else
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows.map((r) => r.map(display).toList()).toList(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          cellAlignment: pw.Alignment.centerLeft,
        ),
    ]);
  }

  if (o.charts) {
    table('Indicadores financeiros', metricHeaders, snapshot.metricRows);
    for (final category in categories.take(5)) {
      final series = snapshot.series
          .where((s) => s.metric(category) != null)
          .toList();
      if (series.isEmpty) continue;
      var maxValue = series
          .map((s) => s.metric(category)!.abs())
          .fold<double>(0, (a, b) => a > b ? a : b);
      if (maxValue == 0) maxValue = 1;
      widgets.addAll([
        pw.SizedBox(height: 18),
        pw.Text(
          '$category (${snapshot.analysis.filter.currency})',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
      ]);
      for (final s in series) {
        final value = s.metric(category)!;
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 180,
                  child: pw.Text(
                    s.label,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
                pw.SizedBox(
                  width: 100,
                  child: pw.Text(
                    value.toStringAsFixed(2),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Container(
                  width: 300 * value.abs() / maxValue,
                  height: 10,
                  color: value < 0 ? PdfColors.orange700 : PdfColors.blue700,
                ),
              ],
            ),
          ),
        );
      }
      widgets.add(
        pw.Text(
          'Barras representam magnitude; o sinal é apresentado no valor.',
          style: const pw.TextStyle(fontSize: 8),
        ),
      );
    }
  }
  if (o.table) {
    table('Comparação completa', comparisonHeaders, snapshot.comparisonRows);
  }
  if (o.entries) {
    table('Lançamentos completos do recorte', entryHeaders, snapshot.entryRows);
  }
  if (o.audit) table('Auditoria e revisões', auditHeaders, snapshot.auditRows);
  if (o.history) {
    table('Histórico de comparações', historyHeaders, snapshot.historyRows);
    table(
      'Resultados históricos',
      historyResultHeaders,
      snapshot.historyResultRows,
    );
  }
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 1000,
      build: (_) => widgets,
      footer: (c) => pw.Text(
        'Finvexa | ${c.pageNumber}/${c.pagesCount}',
        style: const pw.TextStyle(fontSize: 8),
      ),
    ),
  );
  return pdf.save();
}
