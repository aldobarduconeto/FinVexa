import 'dart:convert';
import 'dart:typed_data';

import '../models/analytics.dart';
import '../models/export_snapshot.dart';
import '../models/preferences.dart';
import '../models/workspace_data.dart';
import 'importers.dart';

Uint8List encodeBackup(WorkspaceData workspace, AppPreferences preferences) =>
    Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'finvexa-backup',
          'version': 1,
          'createdAt': DateTime.now().toIso8601String(),
          'workspace': workspace.toJson(),
          'preferences': preferences.toJson(),
        }),
      ),
    );

({
  Map<String, dynamic> rawWorkspace,
  WorkspaceData workspace,
  AppPreferences preferences,
})
decodeBackup(Uint8List bytes) {
  final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  if (data['format'] != 'finvexa-backup' || data['version'] != 1) {
    throw FormatException('Formato ou versão de backup não reconhecido.');
  }
  final w = data['workspace'] as Map<String, dynamic>;
  final docs = (w['documents'] as List)
      .map((d) => ReportDocument.fromJson(Map<String, dynamic>.from(d)))
      .toList();
  if (docs.map((d) => d.id).toSet().length != docs.length) {
    throw FormatException('IDs de documento duplicados.');
  }
  for (final d in docs) {
    if (d.id.isEmpty || d.name.isEmpty) {
      throw FormatException('Documento inválido.');
    }
    for (final e in d.entries) {
      normalizePeriod(e.period);
      normalizeCurrency(e.currency);
      if (e.documentId != d.id ||
          !e.amount.isFinite ||
          e.description.trim().isEmpty) {
        throw FormatException('Lançamento inválido.');
      }
    }
  }
  final reviews = (w['decisions'] as Map).map(
    (k, v) => MapEntry(
      k.toString(),
      ReviewDecision.fromJson(Map<String, dynamic>.from(v)),
    ),
  );
  if (reviews.values.any(
    (r) => !['Pendente', 'Confirmado', 'Descartado'].contains(r.status),
  )) {
    throw FormatException('Revisão inválida.');
  }
  final records = (w['history'] as List)
      .map((h) => ComparisonRecord.fromJson(Map<String, dynamic>.from(h)))
      .toList();
  if (records.any(
    (h) => h.rows.any((r) => r.length != comparisonHeaders.length),
  )) {
    throw FormatException('Histórico inválido.');
  }
  final defaults = AppPreferences.fromJson(
    Map<String, dynamic>.from(data['preferences']),
  );
  return (
    rawWorkspace: w,
    workspace: WorkspaceData(
      documents: docs,
      decisions: reviews,
      history: records,
    ),
    preferences: defaults,
  );
}
