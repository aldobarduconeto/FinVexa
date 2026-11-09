import 'dart:convert';
import 'dart:typed_data';

import '../services/importers.dart';
import '../services/exports.dart';
import '../services/report_files.dart';
import '../models/analytics.dart';
import '../models/preferences.dart';
import '../models/report_sources.dart';
import '../models/workspace_data.dart';
import '../services/audit_service.dart';
import '../services/workspace_storage.dart';

class WorkspaceController {
  final _storage = WorkspaceStorage();
  WorkspaceData data = WorkspaceData();
  Set<String> selected = {};
  List<ReportSource> sources = [];

  List<LedgerEntry> get allEntries =>
      data.documents.expand((doc) => doc.entries).toList();

  Future<void> restore() async {
    try {
      sources = await _storage.loadSources();
    } catch (_) {
      sources = [];
    }
    data = await _storage.load();
    selected = data.documents.map((doc) => doc.id).toSet();
  }

  Analysis analysis(DataFilter filter, String mode) => Analysis(
    data.documents.where((doc) => selected.contains(doc.id)),
    filter: filter,
    mode: mode,
  );

  Future<bool> save() => _storage.save(data);
  Future<bool> saveSources(List<ReportSource> updated) =>
      _storage.saveSources(updated);

  Future<void> restoreBackup(
    Map<String, dynamic> workspace,
    Future<bool> Function() savePreferences,
  ) => _storage.restoreBackup(workspace, savePreferences);

  Future<bool> removeLegacyReports() => _storage.removeLegacyReports();

  Future<List<({ImportTable table, String id})>> prepareReport(
    String name,
    Uint8List bytes,
  ) async {
    final tables = await readImport(name, bytes);
    final fileId = stableId(base64Encode(bytes));
    return [
      for (final table in tables)
        (table: table, id: '$fileId-${stableId(table.source)}'),
    ];
  }

  Future<bool> exportComparison(String format, ExportSnapshot snapshot) async {
    if (format == 'pdf') {
      return printReportPdf(
        'FinVexa-comparacao.pdf',
        await exportPdf(snapshot),
      );
    }
    return saveReportFile(
      title: 'Salvar relatório',
      name: 'FinVexa-comparacao.$format',
      extension: format,
      bytes: format == 'xlsx' ? exportExcel(snapshot) : exportCsv(snapshot),
    );
  }

  void addDocument(ReportDocument document) {
    data.documents.add(document);
    selected.add(document.id);
  }

  void replace(WorkspaceData workspace) {
    data = workspace;
    selected = data.documents.map((doc) => doc.id).toSet();
  }

  List<AuditAlert> alertsFor(Analysis analysis, AppPreferences preferences) =>
      auditEntries(
            analysis.entries,
            outlierMultiplier: preferences.outlierMultiplier,
          )
          .where(
            (a) => a.kind == 'Duplicidade'
                ? preferences.auditDuplicates
                : a.kind == 'Divergência'
                ? preferences.auditDivergence
                : a.kind == 'Classificação'
                ? preferences.auditClassification
                : preferences.auditOutliers,
          )
          .toList();
}
