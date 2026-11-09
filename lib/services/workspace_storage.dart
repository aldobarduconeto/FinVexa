import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/analytics.dart';
import '../models/finance.dart';
import '../models/report_sources.dart';
import '../models/workspace_data.dart';

class WorkspaceStorage {
  Future<void> restoreBackup(
    Map<String, dynamic> workspace,
    Future<bool> Function() savePreferences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString('workspace_v2');
    if (!await prefs.setString('workspace_v2', jsonEncode(workspace))) {
      throw StateError('Storage');
    }
    try {
      if (!await savePreferences()) throw StateError('Preferences');
    } catch (_) {
      final restored = previous == null
          ? await prefs.remove('workspace_v2')
          : await prefs.setString('workspace_v2', previous);
      if (!restored) throw StateError('Rollback');
      rethrow;
    }
  }

  Future<bool> removeLegacyReports() async =>
      (await SharedPreferences.getInstance()).remove('reports');

  Future<WorkspaceData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('workspace_v2');
    if (saved != null) {
      return WorkspaceData.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } else if (prefs.getString('reports') != null) {
      final legacy = jsonDecode(prefs.getString('reports')!) as List;
      final documents = List.generate(legacy.length, (i) {
        final report = FinancialReport.fromJson(
          Map<String, dynamic>.from(legacy[i]),
        );
        final id = 'legacy-$i';
        return ReportDocument(
          id,
          report.name,
          report.values.entries
              .map(
                (e) => LedgerEntry(
                  id: '$id-${stableId(e.key)}',
                  documentId: id,
                  source: report.name,
                  row: report.values.keys.toList().indexOf(e.key) + 2,
                  description: e.key,
                  period: normalizePeriod(report.period),
                  amount: e.value,
                  category: inferCategory(e.key),
                ),
              )
              .toList(),
        );
      });
      return WorkspaceData(documents: documents);
    }
    return WorkspaceData();
  }

  Future<bool> save(WorkspaceData data) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString('workspace_v2', jsonEncode(data.toJson()));
  }

  Future<List<ReportSource>> loadSources() async {
    final prefs = await SharedPreferences.getInstance();
    final items =
        jsonDecode(prefs.getString('report_sources_v1') ?? '[]') as List;
    return items
        .map((item) => ReportSource.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> saveSources(List<ReportSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(
      'report_sources_v1',
      jsonEncode(sources.map((item) => item.toJson()).toList()),
    );
  }
}
