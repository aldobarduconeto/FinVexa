import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:finvexa/models/finance.dart';

String normalized(String value) {
  const from = 'áàãâäéèêëíìîïóòõôöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  var result = value.toLowerCase().trim();
  for (var i = 0; i < from.length; i++) {
    result = result.replaceAll(from[i], to[i]);
  }
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

const categories = [
  'Receita',
  'Despesa',
  'Lucro',
  'Caixa',
  'Patrimônio',
  'Outros',
];
String inferCategory(String description) {
  final s = normalized(description);
  if (RegExp('lucro|resultado liquido').hasMatch(s)) return 'Lucro';
  if (RegExp('fluxo|caixa|saldo bancario').hasMatch(s)) return 'Caixa';
  if (RegExp('patrimonio|ativo|passivo').hasMatch(s)) return 'Patrimônio';
  if (RegExp('receita|venda|faturamento|salario recebido').hasMatch(s)) {
    return 'Receita';
  }
  if (RegExp('despesa|custo|aluguel|pagamento|tarifa|imposto').hasMatch(s)) {
    return 'Despesa';
  }
  return 'Outros';
}

String normalizePeriod(String value) {
  var s = value.trim();
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(s);
  if (br != null) s = '${br[3]}-${br[2]}-${br[1]}';
  final month = RegExp(r'^(\d{2})/(\d{4})$').firstMatch(s);
  if (month != null) s = '${month[2]}-${month[1]}';
  if (RegExp(r'^\d{4}$').hasMatch(s)) return s;
  if (RegExp(r'^\d{4}-[TQ][1-4]$', caseSensitive: false).hasMatch(s)) {
    return s.toUpperCase().replaceAll('Q', 'T');
  }
  if (RegExp(r'^\d{4}-\d{2}(-\d{2})?$').hasMatch(s)) {
    final date = DateTime.tryParse(s.length == 7 ? '$s-01' : s);
    if (date != null && date.toIso8601String().startsWith(s)) return s;
  }
  throw FormatException(
    'Período inválido: $value. Use AAAA, AAAA-MM, AAAA-T1 ou DD/MM/AAAA.',
  );
}

String periodGroup(String period, String mode) {
  if (mode == 'Ano') return period.substring(0, 4);
  if (mode == 'Trimestre' && RegExp(r'^\d{4}-\d{2}').hasMatch(period)) {
    return '${period.substring(0, 4)}-T${(int.parse(period.substring(5, 7)) - 1) ~/ 3 + 1}';
  }
  if (mode == 'Mês' && RegExp(r'^\d{4}-\d{2}').hasMatch(period)) {
    return period.substring(0, 7);
  }
  return period;
}

class LedgerEntry {
  final String id,
      documentId,
      source,
      description,
      period,
      company,
      account,
      category,
      currency;
  final int row;
  final double amount;
  final Map<String, String> raw;
  LedgerEntry({
    required this.id,
    required this.documentId,
    required this.source,
    required this.row,
    required this.description,
    required this.period,
    required this.amount,
    this.company = 'Minha empresa',
    this.account = 'Geral',
    this.category = 'Outros',
    this.currency = 'BRL',
    this.raw = const {},
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'source': source,
    'row': row,
    'description': description,
    'period': period,
    'amount': amount,
    'company': company,
    'account': account,
    'category': category,
    'currency': currency,
    'raw': raw,
  };
  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
    id: j['id'],
    documentId: j['documentId'],
    source: j['source'],
    row: j['row'],
    description: j['description'],
    period: j['period'],
    amount: parseAmount(j['amount']),
    company: j['company'],
    account: j['account'],
    category: j['category'],
    currency: j['currency'],
    raw: Map<String, String>.from(j['raw'] ?? {}),
  );
  String get fingerprint => jsonEncode([
    normalized(company),
    normalized(account),
    period,
    normalized(description),
    amount,
    currency,
  ]);
}

class ReportDocument {
  final String id, name;
  final List<LedgerEntry> entries;
  ReportDocument(this.id, this.name, Iterable<LedgerEntry> entries)
    : entries = List.unmodifiable(entries);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'entries': entries.map((e) => e.toJson()).toList(),
  };
  factory ReportDocument.fromJson(Map<String, dynamic> j) => ReportDocument(
    j['id'],
    j['name'],
    (j['entries'] as List)
        .map((e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

bool overlapsMonths(String period, DateTime start, DateTime end) {
  final year = int.tryParse(period.split('-').first);
  if (year == null) return false;
  final parts = period.split('-');
  var firstMonth = 1;
  var lastMonth = 12;
  if (parts.length > 1) {
    final token = parts[1];
    if (token.startsWith('T')) {
      final quarter = int.tryParse(token.substring(1));
      if (quarter == null || quarter < 1 || quarter > 4) return false;
      firstMonth = (quarter - 1) * 3 + 1;
      lastMonth = firstMonth + 2;
    } else {
      final month = int.tryParse(token);
      if (month == null || month < 1 || month > 12) return false;
      firstMonth = lastMonth = month;
    }
  }
  return !DateTime(year, lastMonth).isBefore(start) &&
      !DateTime(year, firstMonth).isAfter(end);
}

class DataFilter {
  final String? company, account, category, period;
  final DateTime? startMonth, endMonth;
  final String currency;
  const DataFilter({
    this.company,
    this.account,
    this.category,
    this.period,
    this.startMonth,
    this.endMonth,
    this.currency = 'BRL',
  });
  bool accepts(LedgerEntry e) =>
      (company == null || company == e.company) &&
      (account == null || account == e.account) &&
      (category == null || category == e.category) &&
      (period == null || period == e.period) &&
      (startMonth == null ||
          endMonth == null ||
          overlapsMonths(e.period, startMonth!, endMonth!)) &&
      currency == e.currency;
  String get summary =>
      'Empresa: ${company ?? 'Todas'} | Conta: ${account ?? 'Todas'} | Categoria: ${category ?? 'Todas'} | Período: ${period ?? 'Todos'} | Moeda: $currency'
      '${startMonth == null || endMonth == null ? '' : ' | Intervalo: ${startMonth!.toIso8601String().substring(0, 7)} a ${endMonth!.toIso8601String().substring(0, 7)}'}';
}

class FinancialSeries {
  final String label;
  final List<LedgerEntry> entries;
  FinancialSeries(this.label, Iterable<LedgerEntry> entries)
    : entries = List.unmodifiable(entries);

  late final Map<String, double> values = Map.unmodifiable(
    _sumBy((entry) => normalized(entry.description)),
  );
  late final Map<String, double> _metrics = _sumBy(
    (entry) => categories.contains(entry.category)
        ? entry.category
        : inferCategory(entry.description),
  );

  Map<String, double> _sumBy(String Function(LedgerEntry) keyFor) {
    final totals = <String, double>{};
    for (final entry in entries) {
      final key = keyFor(entry);
      totals.update(
        key,
        (total) => total + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    return totals;
  }

  double? metric(String category) => _metrics[category];
  double? get profit => metric('Lucro');

  double? get margin {
    final revenue = metric('Receita');
    final income = profit;
    if (revenue == null || revenue == 0 || income == null) return null;
    return income / revenue.abs() * 100;
  }
}

class Analysis {
  final List<ReportDocument> documents;
  final DataFilter filter;
  final String mode;
  Analysis(
    Iterable<ReportDocument> documents, {
    this.filter = const DataFilter(),
    this.mode = 'Documento',
  }) : documents = List.unmodifiable(documents);
  late final List<LedgerEntry> entries = List.unmodifiable(
    documents.expand((d) => d.entries).where(filter.accepts),
  );
  late final List<FinancialSeries> series = _groupSeries();

  List<FinancialSeries> _groupSeries() {
    final groups = <String, List<LedgerEntry>>{};
    final documentLabels = mode == 'Documento'
        ? {
            for (final doc in documents)
              doc.id:
                  '${doc.name} · ${doc.id.substring(0, min(8, doc.id.length))}',
          }
        : const <String, String>{};
    for (final entry in entries) {
      final label = switch (mode) {
        'Documento' => documentLabels[entry.documentId]!,
        'Empresa' => entry.company,
        _ => periodGroup(entry.period, mode),
      };
      groups.putIfAbsent(label, () => []).add(entry);
    }
    final labels = groups.keys.toList()..sort();
    return List.unmodifiable(
      labels.map((label) => FinancialSeries(label, groups[label]!)),
    );
  }

  late final Map<String, String> indicatorNames = Map.unmodifiable({
    for (final entry in entries)
      normalized(entry.description): entry.description,
  });
}

class AuditAlert {
  final String id, kind, message;
  final List<String> entryIds;
  AuditAlert(this.id, this.kind, this.message, this.entryIds);
}

String stableId(String value) => sha256.convert(utf8.encode(value)).toString();

class ReviewDecision {
  final String status, note;
  ReviewDecision(this.status, this.note);
  Map<String, dynamic> toJson() => {'status': status, 'note': note};
  factory ReviewDecision.fromJson(Map<String, dynamic> j) =>
      ReviewDecision(j['status'], j['note']);
}

class ComparisonRecord {
  final String date, title, mode, filters, notes;
  final List<String> series;
  final String base;
  final List<List<dynamic>> rows;
  ComparisonRecord(
    this.date,
    this.title,
    this.mode,
    this.filters,
    this.notes,
    this.series, {
    this.base = '',
    this.rows = const [],
  });
  Map<String, dynamic> toJson() => {
    'date': date,
    'title': title,
    'mode': mode,
    'filters': filters,
    'notes': notes,
    'series': series,
    'base': base,
    'rows': rows,
  };
  factory ComparisonRecord.fromJson(Map<String, dynamic> j) => ComparisonRecord(
    j['date'],
    j['title'],
    j['mode'],
    j['filters'],
    j['notes'],
    List<String>.from(j['series']),
    base: j['base'] ?? '',
    rows: (j['rows'] as List? ?? []).map((r) => List<dynamic>.from(r)).toList(),
  );
}
