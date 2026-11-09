import 'dart:convert';

import '../models/analytics.dart';
import '../models/finance.dart';

List<AuditAlert> auditEntries(
  List<LedgerEntry> entries, {
  double outlierMultiplier = 3,
}) {
  final alerts = <AuditAlert>[];
  final duplicate = <String, List<LedgerEntry>>{};
  final descriptions = <String, List<LedgerEntry>>{};
  final values = <String, List<LedgerEntry>>{};
  final outliers = <String, List<LedgerEntry>>{};
  for (final e in entries) {
    duplicate.putIfAbsent(e.fingerprint, () => []).add(e);
    descriptions
        .putIfAbsent(
          jsonEncode([
            normalized(e.company),
            normalized(e.description),
            e.currency,
          ]),
          () => [],
        )
        .add(e);
    values
        .putIfAbsent(
          jsonEncode([
            normalized(e.company),
            normalized(e.account),
            e.period,
            normalized(e.description),
            e.currency,
          ]),
          () => [],
        )
        .add(e);
    outliers
        .putIfAbsent(
          jsonEncode([
            normalized(e.company),
            normalized(e.account),
            normalized(e.description),
            e.currency,
          ]),
          () => [],
        )
        .add(e);
    if (e.category == 'Outros') {
      alerts.add(
        AuditAlert(
          'class-${e.id}',
          'Classificação',
          '${e.description}: categoria não identificada. Confira a classificação.',
          [e.id],
        ),
      );
    }
  }
  void add(String kind, String message, List<LedgerEntry> group) {
    final ids = group.map((e) => e.id).toList()..sort();
    alerts.add(
      AuditAlert('$kind-${stableId(ids.join('|'))}', kind, message, ids),
    );
  }

  for (final group in duplicate.values.where((g) => g.length > 1)) {
    add(
      'Duplicidade',
      '${group.first.description}: ${group.length} ocorrências com empresa, conta, data/período, moeda e valor iguais. Possível duplicidade; confira as origens.',
      group,
    );
  }
  for (final group in descriptions.values) {
    if (group.map((e) => e.category).toSet().length > 1) {
      add(
        'Classificação',
        '${group.first.description}: categorias diferentes para a mesma descrição e empresa.',
        group,
      );
    }
  }
  for (final group in values.values) {
    if (group.map((e) => e.documentId).toSet().length > 1 &&
        group.map((e) => e.amount).toSet().length > 1) {
      add(
        'Divergência',
        '${group.first.description}: valores diferentes entre documentos no mesmo período, empresa e conta.',
        group,
      );
    }
  }
  for (final group in outliers.values.where((g) => g.length >= 4)) {
    final amounts = group.map((e) => e.amount.abs()).toList()..sort();
    final median =
        (amounts[(amounts.length - 1) ~/ 2] + amounts[amounts.length ~/ 2]) / 2;
    for (final e in group) {
      if (median > 0 && e.amount.abs() > median * outlierMultiplier) {
        add(
          'Valor atípico',
          '${e.description}: magnitude maior que $outlierMultiplier vezes a mediana de ${money(median)} da mesma conta e empresa. Requer conferência.',
          [e],
        );
      }
    }
  }
  return alerts;
}
