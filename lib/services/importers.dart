import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel_plus/excel_plus.dart' as xl;
import 'package:pdfrx/pdfrx.dart';

import 'package:finvexa/models/analytics.dart';
import 'package:finvexa/models/finance.dart';

import '../models/import_table.dart';
import 'monthly_report_service.dart';
export '../models/import_table.dart';
export '../models/finance.dart' show normalizeCurrency;

ImportResult mapTable(
  ImportTable table,
  Map<String, int> mapping, {
  required String documentId,
  String company = 'Minha empresa',
  String period = '',
  String currency = 'BRL',
  String decimal = 'auto',
  bool suggestCategories = true,
}) {
  final entries = <LedgerEntry>[];
  final errors = <String>[];
  String cell(List<dynamic> row, String field) {
    final i = mapping[field] ?? -1;
    return i >= 0 && i < row.length ? (row[i] ?? '').toString().trim() : '';
  }

  if ((mapping['description'] ?? -1) < 0 || (mapping['amount'] ?? -1) < 0) {
    return ImportResult([], ['Mapeie as colunas de descrição e valor.']);
  }
  for (var i = 0; i < table.rows.length; i++) {
    final row = table.rows[i];
    if (row.every((e) => e == null || e.toString().trim().isEmpty)) continue;
    try {
      final description = cell(row, 'description');
      if (description.isEmpty) {
        throw const FormatException('Descrição obrigatória.');
      }
      final p = normalizePeriod(
        cell(row, 'period').isEmpty ? period : cell(row, 'period'),
      );
      final raw = cell(row, 'amount');
      var amountText = raw
          .replaceAll(RegExp(r'R\$|US\$|USD|BRL|EUR|€'), '')
          .trim();
      if (decimal == 'ponto') amountText = amountText.replaceAll(',', '');
      if (decimal == 'virgula') amountText = amountText.replaceAll('.', '');
      final amountIndex = mapping['amount']!;
      final original = amountIndex < row.length ? row[amountIndex] : null;
      final amount = parseAmount(original is num ? original : amountText);
      final explicitCategory = cell(row, 'category');
      final category = explicitCategory.isEmpty
          ? suggestCategories
                ? inferCategory(description)
                : 'Outros'
          : categories.firstWhere(
              (c) => normalized(c) == normalized(explicitCategory),
              orElse: () => explicitCategory,
            );
      final companyName = cell(row, 'company').isEmpty
          ? company.trim()
          : cell(row, 'company');
      if (companyName.isEmpty) {
        throw const FormatException('Empresa obrigatória.');
      }
      final rowCurrency = cell(row, 'currency');
      entries.add(
        LedgerEntry(
          id: '$documentId-$i',
          documentId: documentId,
          source: table.source,
          row: table.sourceRows[i],
          description: description,
          period: p,
          amount: amount,
          raw: {
            for (var c = 0; c < table.headers.length; c++)
              '${c + 1}. ${table.headers[c]}': c < row.length
                  ? '${row[c] ?? ''}'
                  : '',
          },
          company: companyName,
          account: cell(row, 'account').isEmpty
              ? 'Geral'
              : cell(row, 'account'),
          category: category,
          currency: normalizeCurrency(
            rowCurrency.isEmpty ? currency : rowCurrency,
          ),
        ),
      );
    } on FormatException catch (e) {
      errors.add('Linha ${table.sourceRows[i]}: ${e.message}');
    }
  }
  if (entries.isEmpty && errors.isEmpty) {
    errors.add('Nenhum lançamento encontrado.');
  }
  return ImportResult(entries, errors);
}

ImportTable recognizeTable(String source, List<List<dynamic>> raw) {
  if (raw.isEmpty) throw const FormatException('Tabela vazia.');
  var header = raw.indexWhere(
    (r) =>
        r.any((c) => fieldAliases['description']!.contains(normalized('$c'))),
  );
  if (header < 0) header = 0;
  final headers = raw[header].map((e) => (e ?? '').toString().trim()).toList();
  final rows = raw.skip(header + 1).toList();
  final yearColumns = <int, String>{};
  for (var i = 0; i < headers.length; i++) {
    try {
      yearColumns[i] = normalizePeriod(headers[i]);
    } on FormatException {
      /* Not a period column. */
    }
  }
  if (yearColumns.isNotEmpty &&
      !headers.any((h) => fieldAliases['amount']!.contains(normalized(h)))) {
    final label = headers.indexWhere(
      (h) => fieldAliases['description']!.contains(normalized(h)),
    );
    if (label >= 0) {
      final expanded = <List<dynamic>>[];
      final sourceRows = <int>[];
      final metadata = List.generate(
        headers.length,
        (i) => i,
      ).where((i) => i != label && !yearColumns.containsKey(i)).toList();
      for (var r = 0; r < rows.length; r++) {
        for (final c in yearColumns.entries) {
          if (c.key < rows[r].length &&
              rows[r][c.key] != null &&
              rows[r][c.key].toString().trim().isNotEmpty) {
            expanded.add([
              rows[r][label],
              rows[r][c.key],
              c.value,
              ...metadata.map((i) => i < rows[r].length ? rows[r][i] : ''),
            ]);
            sourceRows.add(header + r + 2);
          }
        }
      }
      return ImportTable(
        source,
        ['indicador', 'valor', 'periodo', ...metadata.map((i) => headers[i])],
        expanded,
        sourceRows: sourceRows,
        warning: 'Colunas de períodos convertidas em linhas. Confira a prévia.',
      );
    }
  }
  return ImportTable(
    source,
    headers,
    rows,
    sourceRows: List.generate(rows.length, (i) => header + i + 2),
  );
}

List<ImportTable> parseOfx(String name, String text) {
  String tag(String body, String tag) =>
      (RegExp(
                '<$tag>\\s*([^<\\r\\n]+)',
                caseSensitive: false,
              ).firstMatch(body)?.group(1)?.trim() ??
              '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"');
  final statements = RegExp(
    r'<(?:STMTRS|CCSTMTRS)>([\s\S]*?)</(?:STMTRS|CCSTMTRS)>',
    caseSensitive: false,
  ).allMatches(text).map((m) => m[1]!).toList();
  final bodies = statements.isEmpty ? [text] : statements;
  final tables = <ImportTable>[];
  for (
    var statementIndex = 0;
    statementIndex < bodies.length;
    statementIndex++
  ) {
    final body = bodies[statementIndex];
    final currency = tag(body, 'CURDEF');
    final account = tag(body, 'ACCTID');
    final blocks = RegExp(
      r'<STMTTRN>([\s\S]*?)</STMTTRN>',
      caseSensitive: false,
    ).allMatches(body).toList();
    if (blocks.isEmpty) continue;
    final rows = <List<dynamic>>[];
    final sourceRows = <int>[];
    for (final block in blocks) {
      final b = block[1]!;
      final date = tag(b, 'DTPOSTED');
      final p = date.length >= 8
          ? '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}'
          : date;
      final description = [
        tag(b, 'NAME'),
        tag(b, 'MEMO'),
      ].where((s) => s.isNotEmpty).join(' · ');
      final amount = tag(b, 'TRNAMT');
      rows.add([
        description.isEmpty ? tag(b, 'TRNTYPE') : description,
        amount,
        p,
        account,
        currency.isEmpty ? 'BRL' : currency,
        (double.tryParse(amount) ?? 0) < 0 ? 'Despesa' : 'Receita',
        tag(b, 'FITID'),
        tag(b, 'TRNTYPE'),
      ]);
      sourceRows.add(
        text.substring(0, text.indexOf(body) + block.start).split('\n').length,
      );
    }
    tables.add(
      ImportTable(
        bodies.length == 1
            ? name
            : '$name / conta $account (${statementIndex + 1})',
        [
          'descricao',
          'valor',
          'periodo',
          'conta',
          'moeda',
          'categoria',
          'referencia',
          'tipo OFX',
        ],
        rows,
        sourceRows: sourceRows,
        warning: 'Créditos classificados como receita e débitos como despesa. Confira transferências e estornos antes de confirmar.',
      ),
    );
  }
  if (tables.isEmpty) {
    throw const FormatException('Nenhuma transação STMTTRN encontrada no OFX.');
  }
  return tables;
}

ImportTable parsePdfLines(String name, String text) {
  final rows = <List<dynamic>>[];
  final years = <String>[];
  final numeric = RegExp(
    r'(?:R\$\s*)?\(?-?\d[\d.,]*[\d)](?:\s*[DC])?|(?:R\$\s*)?\(?-?\d\)?',
  );
  var multi = false;
  for (final line in text.split(RegExp(r'[\r\n]+'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final yearMatches = RegExp(r'\b20\d{2}(?:-\d{2})?\b')
        .allMatches(trimmed)
        .map((m) => m[0]!)
        .toList();
    if (yearMatches.length >= 2 &&
        !trimmed.contains(',') &&
        !trimmed.contains('R\$')) {
      years.clear();
      years.addAll(yearMatches);
      continue;
    }
    final matches = numeric.allMatches(trimmed).toList();
    if (matches.isEmpty) continue;
    final first = matches.first.start;
    final label = trimmed.substring(0, first).trim();
    if (label.isEmpty || !RegExp(r'[a-zA-ZÀ-ÿ]').hasMatch(label)) continue;
    final amounts = matches
        .map((m) => m[0]!.replaceAll(RegExp(r'\s*[DC]$'), ''))
        .toList();
    if (years.isNotEmpty && amounts.length == years.length) {
      multi = true;
      for (var i = 0; i < years.length; i++) {
        rows.add([label, amounts[i], years[i]]);
      }
    } else if (amounts.length == 1) {
      rows.add([label, amounts.single, '']);
    }
  }
  if (rows.isEmpty) {
    throw const FormatException(
      'Nenhuma linha financeira identificada. PDF digitalizado requer OCR; tabelas complexas devem ser exportadas para Excel/CSV.',
    );
  }
  return ImportTable(
    name,
    ['indicador', 'valor', 'periodo'],
    rows,
    warning:
        'Extração heurística de PDF: confira TODAS as linhas e valores. ${multi ? 'Períodos reconhecidos no cabeçalho.' : 'Informe o período do documento.'} Tabelas complexas e imagens podem não ser reconhecidas.',
  );
}

Future<List<ImportTable>> readImport(String name, Uint8List bytes) async {
  final ext = name.split('.').last.toLowerCase();
  if (bytes.length > 20 * 1024 * 1024) {
    throw const FormatException('Limite de 20 MB por arquivo.');
  }
  if (ext == 'xlsx' || ext == 'xls') {
    final workbook = await xl.Excel.decodeBytesAsync(bytes);
    final tables = <ImportTable>[];
    for (final sheet in workbook.tables.entries) {
      final raw = sheet.value.rows
          .map(
            (r) => r.map((c) {
              final value = c?.value;
              if (value is xl.DoubleCellValue) return value.value;
              if (value is xl.IntCellValue) return value.value;
              if (value is xl.DateCellValue) {
                return value.asDateTimeUtc().toIso8601String().substring(0, 10);
              }
              if (value is xl.DateTimeCellValue) {
                return value.toString().substring(0, 10);
              }
              if (value is xl.FormulaCellValue) {
                return value.cachedValue ?? '=SEM_RESULTADO';
              }
              return value?.toString();
            }).toList(),
          )
          .toList();
      if (raw.isNotEmpty) {
        tables.add(recognizeTable('$name / ${sheet.key}', raw));
      }
    }
    if (tables.isEmpty) {
      throw const FormatException('A planilha não contém tabelas.');
    }
    return tables;
  }
  if (ext == 'pdf') {
    final monthly = monthlyTableFromPdf(name, bytes);
    if (monthly != null) return [monthly];
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(bytes, sourceName: name);
    try {
      final buffer = StringBuffer();
      for (final page in document.pages) {
        buffer.writeln((await page.loadText())?.fullText ?? '');
      }
      if (buffer.toString().trim().isEmpty) {
        throw const FormatException(
          'PDF sem texto extraível. Execute OCR e importe novamente.',
        );
      }
      return [parsePdfLines(name, buffer.toString())];
    } finally {
      await document.dispose();
    }
  }
  String text;
  try {
    text = utf8.decode(bytes).replaceFirst('\ufeff', '');
  } on FormatException {
    text = latin1.decode(bytes);
  }
  if (ext == 'ofx') return parseOfx(name, text);
  if (ext == 'json') {
    final dynamic json = jsonDecode(text);
    if (json is Map && json['values'] is Map) {
      final values = json['values'] as Map;
      return [
        ImportTable(
          name,
          ['indicador', 'valor', 'periodo', 'empresa'],
          values.entries
              .map(
                (e) => [
                  e.key,
                  e.value,
                  json['period'],
                  json['company'] ?? 'Minha empresa',
                ],
              )
              .toList(),
        ),
      ];
    }
    final dynamic records = json is Map
        ? json['entries'] ?? json['lancamentos']
        : json;
    if (records is! List || records.isEmpty || records.any((e) => e is! Map)) {
      throw const FormatException(
        'JSON deve conter uma lista de lançamentos ou name/period/values.',
      );
    }
    final headers = records
        .expand((e) => (e as Map).keys.map((k) => k.toString()))
        .toSet()
        .toList();
    return [
      ImportTable(
        name,
        headers,
        records.map((r) => headers.map((h) => r[h]).toList()).toList(),
      ),
    ];
  }
  final first = text.split(RegExp(r'[\r\n]+')).first;
  final delimiter = first.contains(';')
      ? ';'
      : first.contains('\t')
      ? '\t'
      : ',';
  final rows = CsvToListConverter(
    fieldDelimiter: delimiter,
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(text.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
  final monthly = monthlyTableFromDelimited(name, rows);
  return [monthly ?? recognizeTable(name, rows)];
}
