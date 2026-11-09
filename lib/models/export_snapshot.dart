import 'dart:convert';

import 'analytics.dart';

class ExportOptions {
  final String title, notes;
  final bool charts, table, entries, audit, history;
  const ExportOptions({
    this.title = 'Relatório comparativo Finvexa',
    this.notes = '',
    this.charts = true,
    this.table = true,
    this.entries = true,
    this.audit = true,
    this.history = true,
  });
}

class ExportSnapshot {
  final Analysis analysis;
  final String base;
  final ExportOptions options;
  final List<AuditAlert> alerts;
  final Map<String, ReviewDecision> decisions;
  final List<ComparisonRecord> history;
  ExportSnapshot(
    this.analysis,
    this.base,
    this.options,
    this.alerts,
    this.decisions,
    this.history,
  );
  List<FinancialSeries> get series => analysis.series;
  List<List<dynamic>> get metricRows => series
      .map((s) => [s.label, ...categories.take(5).map(s.metric), s.margin])
      .toList();
  List<List<dynamic>> get comparisonRows {
    final items = series;
    if (items.isEmpty) return [];
    final baseline = items.firstWhere(
      (s) => s.label == base,
      orElse: () => items.first,
    );
    final rows = <List<dynamic>>[];
    for (final indicator in analysis.indicatorNames.entries) {
      final previous = baseline.values[indicator.key];
      for (final target in items) {
        final current = target.values[indicator.key];
        rows.add([
          indicator.value,
          baseline.label,
          target.label,
          previous,
          current,
          difference(previous, current),
          variation(previous, current),
        ]);
      }
    }
    return rows;
  }

  List<List<dynamic>> get entryRows => analysis.entries
      .map(
        (e) => [
          e.source,
          e.row,
          e.description,
          e.amount,
          e.currency,
          e.period,
          e.company,
          e.account,
          e.category,
          jsonEncode(e.raw),
        ],
      )
      .toList();
  List<List<dynamic>> get auditRows => alerts
      .map(
        (a) => [
          a.kind,
          a.message,
          decisions[a.id]?.status ?? 'Pendente',
          decisions[a.id]?.note ?? '',
          a.entryIds.join(', '),
        ],
      )
      .toList();
  List<List<dynamic>> get historyRows => history
      .map(
        (h) => [
          h.date,
          h.title,
          h.mode,
          h.filters,
          h.series.join(' / '),
          h.notes,
          h.base,
        ],
      )
      .toList();
  List<List<dynamic>> get historyResultRows => [
    for (final h in history)
      for (final r in h.rows) [h.date, h.title, ...r],
  ];
}

double? difference(double? base, double? current) =>
    base == null || current == null ? null : current - base;
double? variation(double? base, double? current) =>
    base == null || current == null || base == 0
    ? null
    : (current - base) / base.abs() * 100;
const comparisonHeaders = [
  'Indicador',
  'Base',
  'Comparado',
  'Valor base',
  'Valor comparado',
  'Diferença',
  'Variação (%)',
];
const metricHeaders = [
  'Série',
  'Receita',
  'Despesa',
  'Lucro',
  'Caixa',
  'Patrimônio',
  'Margem líquida (%)',
];
const entryHeaders = [
  'Origem',
  'Linha',
  'Descrição',
  'Valor',
  'Moeda',
  'Período',
  'Empresa',
  'Conta',
  'Categoria',
  'Campos de origem (JSON)',
];
const auditHeaders = [
  'Tipo',
  'Alerta',
  'Revisão',
  'Observação',
  'IDs dos lançamentos',
];
const historyHeaders = [
  'Data',
  'Título',
  'Agrupamento',
  'Filtros',
  'Séries',
  'Observações',
  'Base',
];
const historyResultHeaders = ['Data', 'Título', ...comparisonHeaders];
