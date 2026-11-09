import 'package:flutter/material.dart';

import '../controllers/monthly_report_controller.dart';
import '../models/analytics.dart';
import '../models/monthly_report.dart';
import '../models/report_sources.dart';
import '../models/report_template.dart';

class MonthlyReportView extends StatefulWidget {
  const MonthlyReportView({
    super.key,
    required this.company,
    required this.currency,
  });
  final String company, currency;

  @override
  State<MonthlyReportView> createState() => _MonthlyReportViewState();
}

class _CustomLine {
  String name = '';
  String value = '';
  String category = 'Outros';
}

class _MonthlyReportViewState extends State<MonthlyReportView> {
  late final controller = MonthlyReportController(
    company: widget.company,
    period: monthLabel(DateTime.now()),
    currency: widget.currency,
  );
  final custom = <_CustomLine>[];
  bool saving = false;
  MonthlyReportFormat format = MonthlyReportFormat.json;

  ReportTemplate template = reportTemplates.first;
  final drafts = <String, Map<String, String>>{};
  final customDrafts = <String, List<_CustomLine>>{};
  String customTitle = '';
  Map<String, Map<String, String>> get groups => template.groups;

  void selectTemplate(ReportTemplate value) {
    drafts[template.id] = Map.of(controller.fields);
    customDrafts[template.id] = List.of(custom);
    setState(() {
      template = value;
      controller.fields
        ..clear()
        ..addAll(drafts[value.id] ?? const {});
      custom
        ..clear()
        ..addAll(customDrafts[value.id] ?? const []);
    });
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final bytes = await controller.generate(
        format: format,
        title: template.id == 'personalizado' ? customTitle : template.title,
        categoriesByField: {for (final group in groups.values) ...group},
        custom: custom.map(
          (row) => (name: row.name, value: row.value, category: row.category),
        ),
      );
      if (!mounted) return;
      final saved = await controller.save(bytes, format, template.id);
      if (mounted && saved) {
        notify('Relatório salvo. Você pode abri-lo em Importar relatórios.');
      }
    } catch (error) {
      if (mounted) {
        notify(
          error is FormatException
              ? error.message.toString()
              : 'Não foi possível salvar o relatório.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void notify(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Widget field(
    String label,
    ValueChanged<String> changed, {
    String? initial,
    bool numeric = false,
  }) => SizedBox(
    width: 275,
    child: TextFormField(
      initialValue: initial,
      enabled: !saving,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      onChanged: changed,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
                  child: const Icon(Icons.post_add_outlined),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Criar relatório financeiro',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Escolha um modelo, preencha as rubricas e exporte um arquivo compatível com o FinVexa.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<ReportTemplate>(
          initialValue: template,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tipo de relatório'),
          items: [
            for (final item in reportTemplates)
              DropdownMenuItem(
                value: item,
                child: Text(item.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: saving ? null : (value) => selectTemplate(value!),
        ),
        if (template.id == 'personalizado') ...[
          const SizedBox(height: 12),
          field(
            'Título do relatório',
            (value) => customTitle = value,
            initial: customTitle,
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            field(
              'Empresa',
              (value) => controller.company = value,
              initial: controller.company,
            ),
            field(
              'Período (AAAA, AAAA-MM, AAAA-T1 ou data)',
              (value) => controller.period = value,
              initial: controller.period,
            ),
            field(
              'Moeda (ex.: BRL)',
              (value) => controller.currency = value,
              initial: controller.currency,
            ),
            SizedBox(
              width: 275,
              child: DropdownButtonFormField<MonthlyReportFormat>(
                initialValue: format,
                decoration: const InputDecoration(
                  labelText: 'Formato do arquivo',
                ),
                items: [
                  for (final option in MonthlyReportFormat.values)
                    DropdownMenuItem(value: option, child: Text(option.label)),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() => format = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Campos em branco ficam fora do arquivo. Informe 0 para registrar um valor zero. Use valores na unidade da moeda, sem abreviar em milhares.',
        ),
        const SizedBox(height: 12),
        for (final group in groups.entries)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              key: PageStorageKey((template.id, group.key)),
              maintainState: true,
              initiallyExpanded: group.key == groups.keys.first,
              title: Text(group.key),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                if (group.value.containsKey('Despesa financeira líquida'))
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Para EBITDA, informe despesas tributárias e financeiras com sinal positivo e benefícios ou receitas financeiras líquidas com sinal negativo.',
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final name in group.value.keys)
                        field(
                          name,
                          (value) => controller.fields[name] = value,
                          initial: controller.fields[name],
                          numeric: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Text(
          'Rubricas adicionais',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final row in custom)
          Padding(
            key: ObjectKey(row),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                field(
                  'Nome da rubrica',
                  (value) => row.name = value,
                  initial: row.name,
                ),
                field(
                  'Valor',
                  (value) => row.value = value,
                  initial: row.value,
                  numeric: true,
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: row.category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      for (final category in categories)
                        DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                    ],
                    onChanged: saving ? null : (value) => row.category = value!,
                  ),
                ),
                IconButton(
                  tooltip: 'Remover rubrica',
                  onPressed: saving
                      ? null
                      : () => setState(() => custom.remove(row)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () => setState(() => custom.add(_CustomLine())),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar rubrica'),
            ),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: const Icon(Icons.download_outlined),
              label: Text('Gerar arquivo ${format.label}'),
            ),
          ],
        ),
      ],
    );
  }
}
