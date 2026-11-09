import 'dart:math';
import 'dart:convert';
import 'preferences_scope.dart';
import 'monthly_report_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/report_files.dart';
import '../services/backup_service.dart';
import '../services/report_download.dart';
import 'package:finvexa/models/analytics.dart';
import 'package:finvexa/services/exports.dart';
import 'package:finvexa/models/preferences.dart';
import 'package:finvexa/views/sources_view.dart';
import 'package:finvexa/views/settings_view.dart';
import '../controllers/workspace_controller.dart';
import 'package:finvexa/views/import_review.dart';
import 'package:finvexa/views/dashboard_view.dart';
import 'package:finvexa/models/report_sources.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final controller = WorkspaceController();
  List<ReportDocument> get documents => controller.data.documents;
  Map<String, ReviewDecision> get decisions => controller.data.decisions;
  List<ComparisonRecord> get history => controller.data.history;
  Set<String> get selected => controller.selected;
  set selected(Set<String> ids) => controller.selected = ids;
  int tab = 0, dataPage = 0, comparisonPage = 0, settingsGeneration = 0;
  bool busy = true, lineChart = false;
  String mode = 'Mês', currency = 'BRL', search = '', auditStatus = 'Todos';
  String? company, account, category, period, baseline;
  String? storageError;
  final title = TextEditingController(text: 'Relatório comparativo FinVexa');
  final notes = TextEditingController();
  final searchController = TextEditingController();
  bool includeCharts = true, includeTable = true, includeEntries = true, includeAudit = true, includeHistory = true;
  List<LedgerEntry> get allEntries => controller.allEntries;
  DataFilter get filter => DataFilter(
    company: company,
    account: account,
    category: category,
    period: period,
    startMonth: sourceStart,
    endMonth: sourceEnd,
    currency: currency,
  );
  List<ReportSource> get reportSources => controller.sources;
  DateTime? sourceStart, sourceEnd;
  String? downloadProgress;
  bool stopDownloads = false;

  Future<void> saveSources(List<ReportSource> updated) async {
    try {
      if (!await controller.saveSources(updated)) throw StateError('Storage');
      if (mounted) setState(() => controller.sources = updated);
    } catch (_) {
      if (mounted) notify('Não foi possível salvar as fontes.');
    }
  }

  Future<void> downloadAndAnalyze(ReportSource source, DateTime start,DateTime end) async {
    if (busy) return;
    setState(() => busy = true);
    stopDownloads = false;
    final imported = <ReportDocument>[];
    final errors = <String>[];
    try {
      final limit = preferences.importLimitMb * 1024 * 1024;
      final reports = source.reports(start, end).toList();
      for (final (index, report) in reports.indexed) {
        if (!mounted) return;
        if (stopDownloads) break;
        final label = report.period ?? 'Consolidado';
        setState(() => downloadProgress ='Relatório ${index + 1} de ${reports.length} · $label');
        try {
          final bytes = await fetchReport(report.uri, limit);
          if (!mounted) return;
          if (stopDownloads) break;
          imported.addAll(
            await reviewReport(
              '${source.company} - $label.${source.extension}',
              bytes,
              companyName: source.company,
              initialPeriod: report.period,
            ),
          );
        } catch (error) {
          errors.add(
            '$label: ${error is FormatException ? error.message : 'Falha ao baixar ou ler o relatório.'}',
          );
        }
      }
      if (!mounted) return;
      final matching = imported
          .expand((doc) => doc.entries)
          .where((entry) => entry.company == source.company && overlapsMonths(entry.period, start, end))
          .toList();
      if (matching.isNotEmpty) {
        setState(() {
          selected = imported.map((doc) => doc.id).toSet();
          company = source.company;
          sourceStart = start;
          sourceEnd = end;
          account = category = period = baseline = null;
          currency = matching.any((entry) => entry.currency == currency)
              ? currency
              : matching.first.currency;
          mode = end.year * 12 + end.month - start.year * 12 - start.month >= 24
              ? 'Ano'
              : 'Mês';
          tab = 0;
          dataPage = comparisonPage = 0;
        });
      }
      if (errors.isNotEmpty || matching.isEmpty || stopDownloads) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              matching.isEmpty ? 'Sem dados para analisar' : 'Download parcial',
            ),
            content: SingleChildScrollView(
              child: Text(
                [
                  if (matching.isEmpty) 'Nenhum lançamento confirmado corresponde à empresa e ao período selecionados.',
                  if (stopDownloads)
                    'Os downloads restantes foram interrompidos.',
                  ...errors,
                ].join('\n'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      }
    } on FormatException catch (error) {
      if (mounted) notify(error.message.toString());
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          downloadProgress = null;
        });
      }
    }
  }

  Future<List<ReportDocument>> reviewReport(
    String name,
    Uint8List bytes, {
    String? companyName,
    String? initialPeriod,
  }) async {
    final tables = await controller.prepareReport(name, bytes);
    final documentsById = {for (final doc in documents) doc.id: doc};
    final results = <ReportDocument>[];
    for (final (table: table, id: id) in tables) {
      if (!mounted) break;
      final existing = documentsById[id];
      if (existing != null) {
        if (companyName == null) {
          notify('${table.source}: este arquivo já foi importado.');
        }
        results.add(existing);
        continue;
      }
      final doc = await Navigator.of(context).push<ReportDocument>(
        MaterialPageRoute(
          builder: (_) => ImportReview(
            table: table,
            documentId: id,
            defaults: preferences,
            initialCompany: companyName,
            initialPeriod: initialPeriod,
          ),
        ),
      );
      if (doc == null || !mounted) continue;
      documentsById[doc.id] = doc;
      setState(() {
        controller.addDocument(doc);
        if (documents.length == 1) currency = doc.entries.first.currency;
      });
      await persist();
      results.add(doc);
    }
    return results;
  }

  Analysis get analysis => controller.analysis(filter, mode);
  AppPreferences get preferences => PreferencesScope.read(context).value;
  int get rowsPerPage => preferences.pageSize;
  List<AuditAlert> alertsFor(Analysis analysis) =>
      controller.alertsFor(analysis, preferences);
  @override
  void initState() {
    super.initState();
    restore();
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> restore() async {
    try {
      final defaults = preferences;
      mode = defaults.grouping;
      currency = defaults.currency;
      tab = defaults.startPage;
      lineChart = defaults.chart == 'line';
      title.text = defaults.exportTitle;
      includeCharts = defaults.exportCharts;
      includeTable = defaults.exportTable;
      includeEntries = defaults.exportEntries;
      includeAudit = defaults.exportAudit;
      includeHistory = defaults.exportHistory;
      await controller.restore();
      if (!mounted) return;
      if (allEntries.isNotEmpty &&
          !allEntries.any((e) => e.currency == currency)) {
        currency = allEntries.first.currency;
      }
    } catch (_) {
      storageError = 'Não foi possível recuperar todos os dados locais. Os dados anteriores foram preservados.';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<bool> persist() async {
    try {
      final saved = await controller.save();
      if (!saved) throw Exception('Storage');
      return true;
    } catch (_) {
      if (mounted) {
        notify(
          'Não foi possível salvar localmente. Exporte os dados antes de fechar.',
        );
      }
      return false;
    }
  }

  void notify(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  Future<void> importFiles() async {
    setState(() => busy = true);
    final errors = <String>[];
    try {
      final files = await pickReportFiles(reportExtensions, multiple: true);
      if (files == null) return;
      for (final file in files.files) {
        try {
          if (file.bytes == null) {
            throw FormatException('Arquivo indisponível.');
          }
          if (file.size > preferences.importLimitMb * 1024 * 1024) {
            throw FormatException(
              'Limite configurado: ${preferences.importLimitMb} MB por arquivo.',
            );
          }
          await reviewReport(file.name, file.bytes!);
        } catch (e) {
          errors.add(
            '${file.name}: ${e is FormatException ? e.message : 'Não foi possível ler este arquivo. Confira se está válido e sem senha.'}',
          );
        }
      }
      if (errors.isNotEmpty && mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text('Resultado da importação'),
            content: SingleChildScrollView(
              child: SelectableText(errors.join('\n\n')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text('Fechar'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) notify('Não foi possível abrir o seletor de arquivos.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> demo() async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      for (var y = 0; y < 3; y++) {
        final id = 'demo-$stamp-$y';
        final p = '2025-0${y + 1}';
        final data = {
          'Receita líquida': 85000.0 + y * 16000,
          'Custos': 42000.0 + y * 4000,
          'Despesas operacionais': 18000.0 + y * 2000,
          'Lucro líquido': 25000.0 + y * 10000,
          'Fluxo de caixa': 16000.0 + y * 5000,
          'Patrimônio líquido': 200000.0 + y * 25000,
        };
        final entries = data.entries
            .map(
              (e) => LedgerEntry(
                id: '$id-${stableId(e.key)}',
                documentId: id,
                source: 'Exemplo $p',
                row: data.keys.toList().indexOf(e.key) + 2,
                description: e.key,
                period: p,
                amount: e.value,
                category: inferCategory(e.key),
              ),
            )
            .toList();
        documents.add(ReportDocument(id, 'Exemplo $p', entries));
        selected.add(id);
      }
      mode = 'Mês';
      currency = 'BRL';
    });
    await persist();
  }

  ComparisonRecord record() {
    final a = analysis;
    final base = effectiveBase(a.series);
    final snapshot = ExportSnapshot(a, base, ExportOptions(), [], {}, []);
    return ComparisonRecord(
      DateTime.now().toIso8601String(),
      title.text.trim().isEmpty ? 'Comparação financeira' : title.text.trim(),
      mode,
      filter.summary,
      notes.text,
      a.series.map((s) => s.label).toList(),
      base: base,
      rows: snapshot.comparisonRows,
    );
  }

  Future<void> inspectHistory(ComparisonRecord record) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(record.title),
      content: SizedBox(
        width: 1000,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                '${record.date}\n${record.filters}\nBase: ${record.base}\n${record.notes}',
              ),
              SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: comparisonHeaders
                      .map((h) => DataColumn(label: Text(h)))
                      .toList(),
                  rows: record.rows
                      .map(
                        (r) => DataRow(
                          cells: r
                              .map((v) => DataCell(Text(display(v))))
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text('Fechar')),
      ],
    ),
  );
  Future<void> saveComparison() async {
    setState(() => history.insert(0, record()));
    if (await persist() && mounted) {
      notify('Comparação registrada no histórico.');
    }
  }

  Future<void> export(String format) async {
    final currentAnalysis = analysis;
    if (currentAnalysis.series.length < 2) {
      notify('Selecione ao menos duas séries para comparar.');
      return;
    }
    setState(() => busy = true);
    try {
      final currentRecord = record();
      final snapshot = ExportSnapshot(
        currentAnalysis,
        effectiveBase(currentAnalysis.series),
        ExportOptions(
          title: currentRecord.title,
          notes: notes.text,
          charts: includeCharts,
          table: includeTable,
          entries: includeEntries,
          audit: includeAudit,
          history: includeHistory,
        ),
        alertsFor(currentAnalysis),
        decisions,
        [currentRecord, ...history],
      );
      final completed = await controller.exportComparison(format, snapshot);
      if (completed && mounted) {
        setState(() => history.insert(0, currentRecord));
        await persist();
        if (mounted) notify('Relatório exportado e comparação registrada.');
      }
    } catch (e) {
      if (mounted) {
        notify(
          'Não foi possível exportar o relatório. Tente novamente com menos dados.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String effectiveBase(List<FinancialSeries> series) =>
      series.any((s) => s.label == baseline) ? baseline! : series.first.label;
  Future<void> reviewAlert(AuditAlert alert) async {
    final previous = decisions[alert.id];
    final controller = TextEditingController(text: previous?.note ?? '');
    final status = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(alert.kind),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.message),
                SizedBox(height: 12),
                ...allEntries
                    .where((e) => alert.entryIds.contains(e.id))
                    .map(
                      (e) => Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: SelectableText(
                          '${e.source} · linha ${e.row}\n${e.description} | ${e.amount.toStringAsFixed(2)} ${e.currency} | ${e.period}\n${e.company} / ${e.account} / ${e.category}',
                        ),
                      ),
                    ),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Observação da revisão',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'Pendente'),
            child: Text('Pendente'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'Descartado'),
            child: Text('Descartar alerta'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'Confirmado'),
            child: Text('Confirmar inconsistência'),
          ),
        ],
      ),
    );
    if (status != null && mounted) {
      setState(
        () => decisions[alert.id] = ReviewDecision(status, controller.text),
      );
      await persist();
    }
    await Future<void>.delayed(Duration(milliseconds: 250));
    controller.dispose();
  }

  Future<void> removeDocument(ReportDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remover relatório?'),
        content: Text('${doc.name}\nO arquivo original não será alterado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        documents.remove(doc);
        selected.remove(doc.id);
        company = account = category = period = null;
        dataPage = comparisonPage = 0;
      });
      await persist();
    }
  }

  Map<String, dynamic> workspaceJson() => controller.data.toJson();
  Future<void> backupData() async {
    setState(() => busy = true);
    try {
      final data = encodeBackup(controller.data, preferences);
      final saved = await saveReportFile(
        title: 'Salvar backup FinVexa',
        name:
            'FinVexa-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json',
        extension: 'json',
        bytes: data,
      );
      if (saved && mounted) {
        notify(
          'Backup exportado com relatórios, revisões, histórico e preferências.',
        );
      }
    } catch (_) {
      if (mounted) notify('Não foi possível exportar o backup.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restoreBackup() async {
    setState(() => busy = true);
    try {
      final files = await pickReportFiles(['json']);
      if (files == null) return;
      final bytes = files.files.single.bytes;
      if (bytes == null || bytes.length > 100 * 1024 * 1024) {
        throw FormatException('Backup indisponível ou maior que 100 MB.');
      }
      final backup = decodeBackup(bytes);
      final docs = backup.workspace.documents;
      final records = backup.workspace.history;
      final defaults = backup.preferences;
      final w = backup.rawWorkspace;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Restaurar este backup?'),
          content: Text(
            '${docs.length} relatórios e ${records.length} comparações salvas.\n\nOs dados e preferências atuais serão substituídos. Exporte um backup antes de continuar se quiser preservá-los.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Substituir e restaurar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final preferences = PreferencesScope.read(context);
      await controller.restoreBackup(
        w,
        () => preferences.update(defaults.toJson()),
      );
      if (!mounted) return;
      setState(() {
        settingsGeneration++;
        controller.replace(backup.workspace);
        sourceStart = sourceEnd = null;
        company = account = category = period = baseline = null;
        currency = defaults.currency;
        mode = defaults.grouping;
        lineChart = defaults.chart == 'line';
        title.text = defaults.exportTitle;
        includeCharts = defaults.exportCharts;
        includeTable = defaults.exportTable;
        includeEntries = defaults.exportEntries;
        includeAudit = defaults.exportAudit;
        includeHistory = defaults.exportHistory;
        dataPage = comparisonPage = 0;
      });
      notify('Backup restaurado.');
    } catch (e) {
      if (mounted) {
        notify(
          e is FormatException ? e.message.toString() : 'Backup inválido ou não foi possível restaurar. Os arquivos originais foram preservados.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Limpar histórico?'),
        content: Text(
          'Todas as comparações salvas serão removidas. Relatórios e revisões serão preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Limpar histórico'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => history.clear());
      await persist();
    }
  }

  Future<void> clearFinancialData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Apagar dados financeiros?'),
        content: Text(
          'Relatórios importados, revisões e histórico serão removidos deste dispositivo. Esta ação não pode ser desfeita sem um backup.\n\nAs preferências e os arquivos originais serão preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text('Apagar dados'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        documents.clear();
        selected.clear();
        decisions.clear();
        history.clear();
        company = account = category = period = baseline = null;
        dataPage = comparisonPage = 0;
      });
      if (await persist()) {
        await controller.removeLegacyReports();
      }
    }
  }

  void help() => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Importação e comparação'),
      content: SingleChildScrollView(
        child: SelectableText(
          'Importe PDF com texto, XLS/XLSX, CSV/TSV, OFX ou JSON. Cada tabela passa por conferência e mapeamento de colunas. Limite: 20 MB por arquivo.\n\nCSV recomendado:\ndescricao;valor;periodo;empresa;conta;categoria;moeda\nReceita líquida;150000,00;2025-01;Empresa A;Geral;Receita;BRL\n\nDatas: DD/MM/AAAA, AAAA-MM-DD, AAAA-MM, AAAA-T1 ou AAAA. Colunas de períodos são convertidas em linhas quando reconhecidas.\n\nJSON: lista de objetos com os mesmos campos, ou {"name":"DRE","period":"2025","values":{"Receita":100}}.\n\nPDF: extração heurística de linhas com descrição seguida de valores. Confira todas as linhas. PDFs digitalizados precisam de OCR externo.\n\nOFX: débitos são sugeridos como despesas e créditos como receitas; revise transferências e estornos.\n\nNão há conversão cambial. Selecione uma moeda por análise. Valores são somados como importados, sem inverter sinais. Não misture saldos acumulados com movimentos do período.\n\nAuditoria usa regras e aponta possibilidades, não conclusões contábeis. Confirmar ou descartar um alerta não modifica os valores.\n\nOs dados ficam no armazenamento local, sem sincronização. Limpar os dados do aplicativo remove o histórico.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text('Fechar')),
      ],
    ),
  );
  Widget panel(Widget child) => Card(
    margin: EdgeInsets.only(bottom: 18),
    child: Padding(padding: EdgeInsets.all(20), child: child),
  );
  Widget heading(String text, [String? subtitle]) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        text,
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      if (subtitle != null) ...[
        SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      SizedBox(height: 20),
    ],
  );
  Widget choice(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    bool all = true,
  }) {
    final values = options.toSet().toList()..sort();
    if (value != null && !values.contains(value)) values.add(value);
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value-${values.join()}'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          if (all) DropdownMenuItem(value: null, child: Text('Todos')),
          ...values.map(
            (v) => DropdownMenuItem(
              value: v,
              child: Text(v, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: busy
            ? null
            : (v) {
                setState(() {
                  dataPage = comparisonPage = 0;
                });
                onChanged(v);
              },
      ),
    );
  }

  Widget filters({bool concise = false}) {
    final count = [
      company,
      account,
      category,
      period,
    ].where((v) => v != null).length;
    return Card(
      margin: EdgeInsets.only(bottom: concise ? 16 : 24),
      child: ExpansionTile(
        dense: concise,
        minTileHeight: concise ? 48 : null,
        tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 3),
        childrenPadding: EdgeInsets.fromLTRB(20, 4, 20, 20),
        shape: Border(),
        collapsedShape: Border(),
        leading: Icon(Icons.tune_rounded, size: 19),
        title: Text(
          'Filtros da análise',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: concise
            ? null
            : Text(
                '$mode · $currency · ${selected.length} arquivos${count > 0 ? ' · $count filtros ativos' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
        children: [
          if (sourceStart != null && sourceEnd != null)
            InputChip(
              label: Text(
                '${monthLabel(sourceStart!)} a ${monthLabel(sourceEnd!)}',
              ),
              onDeleted: () => setState(() => sourceStart = sourceEnd = null),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              choice(
                'Empresa',
                company,
                allEntries.map((e) => e.company).toList(),
                (v) => setState(() => company = v),
              ),
              choice(
                'Conta',
                account,
                allEntries.map((e) => e.account).toList(),
                (v) => setState(() => account = v),
              ),
              choice('Categoria', category, [
                ...categories,
                ...allEntries.map((e) => e.category),
              ], (v) => setState(() => category = v)),
              choice(
                'Período',
                period,
                allEntries.map((e) => e.period).toList(),
                (v) => setState(() => period = v),
              ),
              choice(
                'Moeda',
                currency,
                ['BRL', ...allEntries.map((e) => e.currency)],
                (v) => setState(() => currency = v!),
                all: false,
              ),
              choice(
                'Comparar por',
                mode,
                ['Documento', 'Mês', 'Trimestre', 'Ano', 'Empresa'],
                (v) => setState(() {
                  mode = v!;
                  baseline = null;
                }),
                all: false,
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  company = account = category = period = null;
                }),
                icon: Icon(Icons.filter_alt_off_outlined, size: 16),
                label: Text('Limpar filtros'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const pageNames = [
    'Visão geral',
    'Relatórios',
    'Comparação',
    'Auditoria',
    'Exportar',
    'Configurações',
    'Fontes',
    'Criar relatório',
  ];
  static const pageIcons = [
    Icons.space_dashboard_outlined,
    Icons.folder_open_outlined,
    Icons.compare_arrows_rounded,
    Icons.fact_check_outlined,
    Icons.ios_share_rounded,
    Icons.settings_outlined,
    Icons.cloud_download_outlined,
    Icons.post_add_outlined,
  ];
  void navigate(int value) => setState(() {
    tab = value;
    dataPage = comparisonPage = 0;
  });
  Future<void> quickSearch() async {
    final query = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, refresh) => AlertDialog(
          title: TextField(
            autofocus: true,
            controller: query,
            decoration: InputDecoration(
              hintText: 'Buscar páginas ou relatórios',
              prefixIcon: Icon(Icons.search),
              border: InputBorder.none,
            ),
            onChanged: (_) => refresh(() {}),
          ),
          content: SizedBox(
            width: 560,
            height: 360,
            child: ListView(
              children: [
                for (var i = 0; i < pageNames.length; i++)
                  if (normalized(pageNames[i]).contains(normalized(query.text)))
                    ListTile(
                      leading: Icon(pageIcons[i]),
                      title: Text(pageNames[i]),
                      onTap: () {
                        Navigator.pop(c);
                        navigate(i);
                      },
                    ),
                for (final doc in documents.where(
                  (d) => normalized(d.name).contains(normalized(query.text)),
                ))
                  ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text(doc.name),
                    subtitle: Text('${doc.entries.length} lançamentos'),
                    onTap: () {
                      Navigator.pop(c);
                      setState(() {
                        tab = 1;
                        search = doc.name;
                        searchController.text = doc.name;
                        dataPage = 0;
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('Fechar'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(Duration(milliseconds: 200));
    query.dispose();
  }

  Widget navigationItem(int index, bool expanded, bool drawer) {
    final scheme = Theme.of(context).colorScheme;
    final active = tab == index;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 14 : 10,
        vertical: 3,
      ),
      child: Tooltip(
        message: expanded ? '' : pageNames[index],
        child: Material(
          color: active
              ? scheme.primary.withValues(alpha: .14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: ValueKey('navigation-$index'),
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (drawer) Navigator.pop(context);
              navigate(index);
            },
            child: SizedBox(
              height: 46,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 10),
                child: Row(
                  mainAxisAlignment: expanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Icon(
                      pageIcons[index],
                      size: 20,
                      color: active ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    if (expanded) ...[
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          pageNames[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: active
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (index == 1 && documents.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${documents.length}',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget sideNavigation(bool expanded, {bool drawer = false}) {
    final scheme = Theme.of(context).colorScheme;
    final brand = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 24 : 18,
        vertical: 28,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/branding/finvexa.png',
              width: 36,
              height: 36,
            ),
          ),
          if (expanded) ...[
            SizedBox(width: 12),
            Text(
              'FinVexa',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -.8,
              ),
            ),
          ],
        ],
      ),
    );
    final workspace = Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              Icons.business_outlined,
              size: 19,
              color: scheme.onSurfaceVariant,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preferences.company,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Espaço de trabalho local',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      width: expanded ? 240 : 76,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            brand,
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (expanded) ...[
                      workspace,
                      Padding(
                        padding: EdgeInsets.fromLTRB(26, 0, 20, 10),
                        child: Text(
                          'PRINCIPAL',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.4,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    for (final index in const [0, 1, 2, 3, 7, 6, 4])
                      navigationItem(index, expanded, drawer),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Divider(),
            ),
            navigationItem(5, expanded, drawer),
            Padding(
              padding: EdgeInsets.all(expanded ? 24 : 16),
              child: expanded
                  ? Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Color(0xff21a67a),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dados neste dispositivo',
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: help,
                          tooltip: 'Ajuda',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.help_outline, size: 17),
                        ),
                      ],
                    )
                  : IconButton(
                      onPressed: help,
                      tooltip: 'Ajuda',
                      icon: Icon(Icons.help_outline, size: 20),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget topbar(bool desktop) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 76,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 32 : 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (!desktop)
            Builder(
              builder: (c) => IconButton(
                onPressed: () => Scaffold.of(c).openDrawer(),
                tooltip: 'Abrir navegação',
                icon: Icon(Icons.menu),
              ),
            ),
          if (desktop) ...[
            Text(
              'Workspace',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.chevron_right,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          Expanded(
            child: Text(
              pageNames[tab],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (desktop)
            SizedBox(
              width: 240,
              child: OutlinedButton(
                onPressed: quickSearch,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 17,
                      color: scheme.onSurfaceVariant,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Buscar no FinVexa',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      'Ctrl K',
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!desktop)
            IconButton(
              onPressed: quickSearch,
              tooltip: 'Buscar',
              icon: Icon(Icons.search, size: 20),
            ),
          SizedBox(width: desktop ? 18 : 2),
          IconButton(
            tooltip: 'Alternar tema',
            onPressed: () => PreferencesScope.read(context).update({
              'theme': Theme.of(context).brightness == Brightness.dark
                  ? 'light'
                  : 'dark',
            }),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PreferencesScope.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final desktop = box.maxWidth >= 850;
        final expanded = box.maxWidth >= 1200 && !preferences.collapsedSidebar;
        final a = analysis;
        final content = ListView(
          key: ValueKey('page-$tab'),
          padding: EdgeInsets.all(desktop ? 32 : 16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (storageError != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          storageError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (tab < 5 &&
                        (tab != 0 ||
                            documents.isEmpty ||
                            a.series.isEmpty)) ...[
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 20,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GESTÃO FINANCEIRA',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.4,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                '${documents.length} relatórios no seu espaço de trabalho',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => navigate(7),
                                icon: const Icon(
                                  Icons.post_add_outlined,
                                  size: 18,
                                ),
                                label: const Text('Criar relatório'),
                              ),
                              FilledButton.icon(
                                onPressed: busy ? null : importFiles,
                                icon: const Icon(
                                  Icons.file_upload_outlined,
                                  size: 18,
                                ),
                                label: const Text('Importar relatórios'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 26),
                    ],
                    if (tab == 5)
                      SettingsView(
                        key: ValueKey('settings-$settingsGeneration'),
                        documentCount: documents.length,
                        entryCount: allEntries.length,
                        historyCount: history.length,
                        storageBytes: utf8
                            .encode(jsonEncode(workspaceJson()))
                            .length,
                        onBackup: backupData,
                        onRestore: restoreBackup,
                        onClearHistory: clearHistory,
                        onClearData: clearFinancialData,
                      )
                    else if (tab == 6)
                      SourcesView(
                        sources: reportSources,
                        onSave: saveSources,
                        onAnalyze: downloadAndAnalyze,
                        progress: downloadProgress,
                        onStop: () => setState(() => stopDownloads = true),
                        stopping: stopDownloads,
                        busy: busy,
                      )
                    else if (tab == 7)
                      MonthlyReportView(
                        company: preferences.company,
                        currency: preferences.currency,
                      )
                    else if (documents.isEmpty)
                      emptyState()
                    else ...[
                      if (tab != 0 || a.series.isEmpty) filters(),
                      if (tab == 0) overview(a),
                      if (tab == 1) documentsView(a),
                      if (tab == 2) comparisonView(a),
                      if (tab == 3) auditView(a),
                      if (tab == 4) exportView(a),
                    ],
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Processamento local · Seus arquivos originais são preservados',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        final shell = Scaffold(
          drawer: desktop
              ? null
              : Drawer(width: 240, child: sideNavigation(true, drawer: true)),
          bottomNavigationBar: desktop || tab >= 5
              ? null
              : NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: navigate,
                  destinations: [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      label: 'Painel',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.folder_open_outlined),
                      label: 'Arquivos',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.compare_arrows),
                      label: 'Comparar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.fact_check_outlined),
                      label: 'Auditoria',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.ios_share),
                      label: 'Exportar',
                    ),
                  ],
                ),
          body: Row(
            children: [
              if (desktop) sideNavigation(expanded),
              Expanded(
                child: Column(
                  children: [
                    topbar(desktop),
                    if (busy) LinearProgressIndicator(minHeight: 2),
                    Expanded(child: content),
                  ],
                ),
              ),
            ],
          ),
        );
        return CallbackShortcuts(
          bindings: {
            SingleActivator(LogicalKeyboardKey.keyK, control: true):
                quickSearch,
            SingleActivator(LogicalKeyboardKey.keyK, meta: true): quickSearch,
          },
          child: Focus(autofocus: true, child: shell),
        );
      },
    );
  }

  Widget emptyState() => panel(
    Padding(
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.insert_chart_outlined_rounded,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Sua análise começa com os dados',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.5),
              ),
              SizedBox(height: 12),
              Text(
                'Importe seus relatórios para acompanhar indicadores, comparar resultados e investigar diferenças em um só lugar.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: ['PDF', 'Excel', 'CSV', 'OFX', 'JSON']
                    .map(
                      (s) => Chip(
                        label: Text(s, style: TextStyle(fontSize: 11)),
                        padding: EdgeInsets.symmetric(horizontal: 6),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: busy ? null : demo,
                icon: Icon(Icons.auto_graph, size: 18),
                label: Text('Explorar com dados de exemplo'),
              ),
              SizedBox(height: 18),
              TextButton(
                onPressed: help,
                child: Text('Ver orientações de importação'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget overview(Analysis a) => FinancialDashboard(
    listedCompanies: {
      for (final source in reportSources)
        if (source.ticker.isNotEmpty) source.company: source.ticker,
    },
    analysis: a,
    onImport: importFiles,
    filterControl: filters(concise: true),
    busy: busy,
    alerts: alertsFor(a),
    decisions: decisions,
    initialLineChart: lineChart,
    compact: preferences.compact,
    onAudit: () => navigate(3),
    onCompare: (value) => setState(() {
      baseline = value;
      tab = 2;
      comparisonPage = 0;
    }),
    onDocument: (doc) => setState(() {
      tab = 1;
      search = doc.name;
      searchController.text = doc.name;
      dataPage = 0;
    }),
  );
  Widget documentsView(Analysis a) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'Relatórios importados',
        'Marque os arquivos que participam da análise. Os filtros valem também para a exportação.',
      ),
      panel(
        Column(
          children: [
            for (final doc in documents)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  value: selected.contains(doc.id),
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          v! ? selected.add(doc.id) : selected.remove(doc.id);
                          dataPage = comparisonPage = 0;
                        }),
                ),
                title: Text(doc.name),
                subtitle: Text(
                  '${doc.entries.length} lançamentos · ${doc.entries.map((e) => e.currency).toSet().join(', ')}',
                ),
                trailing: IconButton(
                  tooltip: 'Remover relatório',
                  onPressed: busy ? null : () => removeDocument(doc),
                  icon: Icon(Icons.delete_outline),
                ),
              ),
          ],
        ),
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lançamentos do recorte',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 14),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar descrição ou origem',
              ),
              onChanged: (v) => setState(() {
                search = v;
                dataPage = 0;
              }),
            ),
            SizedBox(height: 12),
            entriesTable(
              a.entries
                  .where(
                    (e) =>
                        normalized('${e.description} ${e.source}')
                            .contains(normalized(search)),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    ],
  );
  Widget entriesTable(List<LedgerEntry> entries) {
    final pages = max(1, (entries.length / rowsPerPage).ceil());
    final page = min(dataPage, pages - 1);
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text('Descrição')),
              DataColumn(label: Text('Valor')),
              DataColumn(label: Text('Período')),
              DataColumn(label: Text('Empresa / conta')),
              DataColumn(label: Text('Categoria')),
              DataColumn(label: Text('Origem')),
            ],
            rows: entries
                .skip(page * rowsPerPage)
                .take(rowsPerPage)
                .map(
                  (e) => DataRow(
                    cells: [
                      DataCell(
                        SizedBox(width: 200, child: Text(e.description)),
                      ),
                      DataCell(
                        Text('${e.currency} ${e.amount.toStringAsFixed(2)}'),
                      ),
                      DataCell(Text(e.period)),
                      DataCell(Text('${e.company}\n${e.account}')),
                      DataCell(Text(e.category)),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text('${e.source} · linha ${e.row}'),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
        pagination(page, pages, (v) => setState(() => dataPage = v)),
      ],
    );
  }

  Widget pagination(int page, int pages, ValueChanged<int> changed) => Row(
    children: [
      IconButton(
        onPressed: page > 0 ? () => changed(page - 1) : null,
        icon: Icon(Icons.chevron_left),
      ),
      Text('${page + 1} / $pages'),
      IconButton(
        onPressed: page + 1 < pages ? () => changed(page + 1) : null,
        icon: Icon(Icons.chevron_right),
      ),
    ],
  );
  String comparisonQuery = '';
  String comparisonStatus = 'Todos';
  bool rankComparison = false;

  void inspectIndicator(
    String key,
    String label,
    List<FinancialSeries> series,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 660,
          height: 420,
          child: ListView.builder(
            itemCount: series.length,
            itemBuilder: (context, index) {
              final group = series[index];
              final entries = group.entries
                  .where((entry) => normalized(entry.description) == key)
                  .toList();
              final total = group.values[key];
              return ExpansionTile(
                initiallyExpanded: index == 0,
                title: Text(group.label),
                subtitle: Text(
                  total == null
                      ? 'Sem lançamentos para este indicador'
                      : '${entries.length} lançamentos · $currency ${total.toStringAsFixed(2)}',
                ),
                children: [
                  for (final entry in entries)
                    ListTile(
                      title: Text(entry.description),
                      subtitle: Text(
                        '${entry.period} · ${entry.company} / ${entry.account}\n'
                        '${entry.source} · linha ${entry.row}',
                      ),
                      trailing: Text(entry.amount.toStringAsFixed(2)),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget comparisonView(Analysis a) {
    final series = a.series;
    if (series.length < 2) {
      return panel(
        Text(
          'Selecione pelo menos duas séries no recorte para comparar. Altere o agrupamento ou importe mais arquivos.',
        ),
      );
    }
    final base = series.firstWhere((s) => s.label == effectiveBase(series));
    final targets = series.where((s) => s != base).toList();
    final baseValues = base.values;
    final targetValues = targets.map((s) => s.values).toList();
    final magnitude = <String, double>{};
    final indicators = a.indicatorNames.entries.where((indicator) {
      if (!normalized(indicator.value).contains(normalized(comparisonQuery))) {
        return false;
      }
      final previous = baseValues[indicator.key];
      var missing = false;
      var largest = 0.0;
      for (final values in targetValues) {
        final current = values[indicator.key];
        final delta = difference(previous, current);
        missing |= (previous == null) != (current == null);
        largest = max(largest, delta?.abs() ?? 0);
      }
      magnitude[indicator.key] = largest;
      return switch (comparisonStatus) {
        'Alterados' => largest >= .005,
        'Com ausências' => missing,
        _ => true,
      };
    }).toList();
    if (rankComparison) {
      indicators.sort((a, b) {
        final order = magnitude[b.key]!.compareTo(magnitude[a.key]!);
        return order == 0 ? a.value.compareTo(b.value) : order;
      });
    }
    final pages = max(1, (indicators.length / rowsPerPage).ceil());
    final page = min(comparisonPage, pages - 1);
    String amount(double? n) => n == null ? 'Ausente' : n.toStringAsFixed(2);
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(
            'Comparação entre períodos',
            '${series.length} séries · Valores em $currency · Diferenças em relação à base',
          ),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              choice(
                'Série base',
                base.label,
                series.map((s) => s.label).toList(),
                (v) => setState(() => baseline = v),
                all: false,
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : saveComparison,
                icon: Icon(Icons.bookmark_add_outlined),
                label: Text('Salvar comparação'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextFormField(
                  initialValue: comparisonQuery,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Buscar indicador',
                  ),
                  onChanged: (value) => setState(() {
                    comparisonQuery = value;
                    comparisonPage = 0;
                  }),
                ),
              ),
              choice(
                'Exibir',
                comparisonStatus,
                ['Todos', 'Alterados', 'Com ausências'],
                (value) => setState(() => comparisonStatus = value!),
                all: false,
              ),
              FilterChip(
                label: const Text('Maiores diferenças primeiro'),
                selected: rankComparison,
                onSelected: (value) => setState(() {
                  rankComparison = value;
                  comparisonPage = 0;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            indicators.isEmpty
                ? 'Nenhum indicador corresponde aos filtros.'
                : '${indicators.length} indicadores · Selecione um nome para ver os lançamentos.',
          ),
          SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              columns: [
                DataColumn(label: Text('Indicador')),
                DataColumn(label: Text('${base.label}\nBASE')),
                for (final s in targets)
                  DataColumn(
                    label: Text('${s.label}\nValor | diferença | variação'),
                  ),
              ],
              rows: indicators.skip(page * rowsPerPage).take(rowsPerPage).map((
                indicator,
              ) {
                final b = baseValues[indicator.key];
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Text(
                          indicator.value,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      onTap: () => inspectIndicator(
                        indicator.key,
                        indicator.value,
                        [base, ...targets],
                      ),
                    ),
                    DataCell(Text(amount(b))),
                    for (final values in targetValues)
                      DataCell(
                        Builder(
                          builder: (_) {
                            final value = values[indicator.key];
                            final delta = difference(b, value);
                            final percent = variation(b, value);
                            return Text(
                              '${amount(value)}\nΔ ${delta == null ? 'N/D' : delta.toStringAsFixed(2)} · ${percent == null ? 'N/D' : '${percent.toStringAsFixed(1)}%'}',
                              style: TextStyle(
                                color: value == null || b == null
                                    ? Colors.deepOrange
                                    : delta != 0
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
          pagination(page, pages, (v) => setState(() => comparisonPage = v)),
          Text(
            'N/D: indicador ausente ou base zero. Variação sobre o valor absoluto da base. Descrições são padronizadas por acentos e capitalização; parcelas e totais não são reconciliados automaticamente.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget auditView(Analysis a) {
    final currentAlerts = alertsFor(a);
    final visible = currentAlerts
        .where(
          (a) =>
              auditStatus == 'Todos' ||
              (decisions[a.id]?.status ?? 'Pendente') == auditStatus,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'Auditoria e inconsistências',
          'Revise cada alerta e documente sua conclusão. Os valores originais são preservados.',
        ),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${currentAlerts.length} alertas · ${currentAlerts.where((a) => !decisions.containsKey(a.id) || decisions[a.id]?.status == 'Pendente').length} pendentes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 14),
              choice(
                'Estado da revisão',
                auditStatus,
                ['Todos', 'Pendente', 'Confirmado', 'Descartado'],
                (v) => setState(() => auditStatus = v!),
                all: false,
              ),
              SizedBox(height: 14),
              if (visible.isEmpty)
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Nenhum alerta neste recorte. Isso não garante ausência de erros.',
                  ),
                ),
              for (final alert in visible)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  isThreeLine: true,
                  leading: Icon(
                    Icons.policy_outlined,
                    color: Colors.deepOrange,
                  ),
                  title: Text(
                    '${alert.kind} · ${decisions[alert.id]?.status ?? 'Pendente'}',
                  ),
                  subtitle: Text(
                    '${alert.message}${decisions[alert.id]?.note.isNotEmpty == true ? '\nRevisão: ${decisions[alert.id]!.note}' : ''}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Revisar alerta',
                    onPressed: busy ? null : () => reviewAlert(alert),
                    icon: Icon(Icons.rate_review_outlined),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget exportView(Analysis a) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'Relatórios personalizados',
        'As exportações incluem todos os registros do recorte selecionado, além das páginas visíveis nas tabelas.',
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: title,
              decoration: InputDecoration(labelText: 'Título do relatório'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: notes,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Observações e conclusões',
              ),
            ),
            SizedBox(height: 14),
            for (final option in [
              (
                'Gráficos e indicadores',
                includeCharts,
                (bool v) => setState(() => includeCharts = v),
              ),
              (
                'Tabelas comparativas',
                includeTable,
                (bool v) => setState(() => includeTable = v),
              ),
              (
                'Todos os lançamentos do recorte',
                includeEntries,
                (bool v) => setState(() => includeEntries = v),
              ),
              (
                'Auditoria e revisões',
                includeAudit,
                (bool v) => setState(() => includeAudit = v),
              ),
              (
                'Histórico de comparações',
                includeHistory,
                (bool v) => setState(() => includeHistory = v),
              ),
            ])
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option.$1),
                value: option.$2,
                onChanged: (v) => option.$3(v!),
              ),
            SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: busy || a.series.length < 2
                      ? null
                      : () => export('pdf'),
                  icon: Icon(Icons.picture_as_pdf_outlined),
                  label: Text('Exportar PDF completo'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || a.series.length < 2
                      ? null
                      : () => export('xlsx'),
                  icon: Icon(Icons.table_chart_outlined),
                  label: Text('Exportar Excel'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || a.series.length < 2
                      ? null
                      : () => export('csv'),
                  icon: Icon(Icons.description_outlined),
                  label: Text('Exportar CSV'),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'PDF e Excel incluem gráficos. CSV contém seções de dados e não suporta gráficos. Sem conversão cambial; filtros e método de cálculo acompanham o relatório.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Histórico de comparações',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 14),
            if (history.isEmpty)
              Text(
                'Salve uma comparação ou exporte um relatório para registrar o histórico.',
              ),
            for (final h in history)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history),
                title: Text(h.title),
                onTap: () => inspectHistory(h),
                subtitle: Text(
                  '${h.date.replaceFirst('T', ' ')}\n${h.mode} · ${h.filters}\n${h.notes}',
                ),
                isThreeLine: true,
              ),
          ],
        ),
      ),
    ],
  );
}
