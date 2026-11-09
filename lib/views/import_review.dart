import 'package:flutter/material.dart';

import 'package:finvexa/models/analytics.dart';
import 'package:finvexa/services/importers.dart';
import 'package:finvexa/models/preferences.dart';

class ImportReview extends StatefulWidget {
  final ImportTable table;
  final String documentId;
  final AppPreferences defaults;
  final String? initialCompany, initialPeriod;
  const ImportReview({
    super.key,
    required this.table,
    required this.documentId,
    this.defaults = const AppPreferences(),
    this.initialCompany,
    this.initialPeriod,
  });
  @override
  State<ImportReview> createState() => _ImportReviewState();
}

class _ImportReviewState extends State<ImportReview> {
  late Map<String, int> mapping;
  final company = TextEditingController(text: 'Minha empresa');
  final period = TextEditingController();
  String currency = 'BRL', decimal = 'auto';
  bool skipInvalid = false;
  int page = 0;
  @override
  void initState() {
    super.initState();
    company.text = widget.initialCompany ?? widget.defaults.company;
    period.text = widget.initialPeriod ?? '';
    currency = widget.defaults.currency;
    decimal = widget.defaults.decimal;
    mapping = widget.table.autoMapping();
    if (mapping['category'] == -1) {
      final column = widget.table.headers.length;
      widget.table.headers.add('categoria');
      for (final row in widget.table.rows) {
        while (row.length < column) {
          row.add('');
        }
        final descriptionColumn = mapping['description'] ?? -1;
        row.add(
          descriptionColumn >= 0 && descriptionColumn < row.length
              ? widget.defaults.suggestCategories
                    ? inferCategory('${row[descriptionColumn]}')
                    : 'Outros'
              : 'Outros',
        );
      }
      mapping['category'] = column;
    }
  }

  @override
  void dispose() {
    company.dispose();
    period.dispose();
    super.dispose();
  }

  ImportResult get result => mapTable(
    widget.table,
    mapping,
    documentId: widget.documentId,
    company: company.text,
    period: period.text,
    currency: currency,
    decimal: decimal,
    suggestCategories: widget.defaults.suggestCategories,
  );
  Future<void> edit(int index) async {
    final row = widget.table.rows[index];
    final controllers = List.generate(
      widget.table.headers.length,
      (i) =>
          TextEditingController(text: i < row.length ? '${row[i] ?? ''}' : ''),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Editar linha ${widget.table.sourceRows[index]}'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                controllers.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[i],
                    decoration: InputDecoration(
                      labelText: widget.table.headers[i],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(
        () =>
            widget.table.rows[index] = controllers.map((c) => c.text).toList(),
      );
    }
    // Dialog fields release their controllers after the route animation.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final c in controllers) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = result;
    const labels = {
      'description': 'Descrição / indicador *',
      'amount': 'Valor *',
      'period': 'Período / data',
      'company': 'Empresa',
      'account': 'Conta',
      'category': 'Categoria',
      'currency': 'Moeda',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Conferir importação')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.table.source,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.table.rows.length} linhas encontradas. Confira o mapeamento, os valores e as categorias sugeridas.',
          ),
          if (widget.table.warning != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                widget.table.warning!,
                style: const TextStyle(color: Colors.deepOrange),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: labels.entries
                .map(
                  (field) => SizedBox(
                    width: 265,
                    child: DropdownButtonFormField<int>(
                      initialValue: mapping[field.key],
                      isExpanded: true,
                      decoration: InputDecoration(labelText: field.value),
                      items: [
                        const DropdownMenuItem(
                          value: -1,
                          child: Text('Usar padrão / inferir'),
                        ),
                        ...List.generate(
                          widget.table.headers.length,
                          (i) => DropdownMenuItem(
                            value: i,
                            child: Text(
                              '${i + 1}. ${widget.table.headers[i]}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => mapping[field.key] = v ?? -1),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: 265,
                child: TextField(
                  controller: company,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Empresa padrão',
                  ),
                ),
              ),
              SizedBox(
                width: 265,
                child: TextField(
                  controller: period,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Período padrão',
                    hintText: '2025-01 ou 2025',
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: currency,
                  decoration: const InputDecoration(labelText: 'Moeda padrão'),
                  items: ['BRL', 'USD', 'EUR']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setState(() => currency = v!),
                ),
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: decimal,
                  decoration: const InputDecoration(
                    labelText: 'Separador decimal',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Automático')),
                    DropdownMenuItem(
                      value: 'virgula',
                      child: Text(
                        'Vírgula (1.234,56)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'ponto',
                      child: Text(
                        'Ponto (1,234.56)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => decimal = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${preview.entries.length} válidos · ${preview.errors.length} erros',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (preview.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...preview.errors
                .take(8)
                .map((e) => Text(e, style: const TextStyle(color: Colors.red))),
            if (preview.errors.length > 8)
              Text(
                'E mais ${preview.errors.length - 8} erros. Corrija as linhas ou descarte explicitamente.',
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Descartar as linhas inválidas desta importação',
              ),
              value: skipInvalid,
              onChanged: (v) => setState(() => skipInvalid = v!),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Prévia dos dados originais · toque no lápis para corrigir',
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Linha')),
                ...widget.table.headers.map((h) => DataColumn(label: Text(h))),
                const DataColumn(label: Text('Editar')),
              ],
              rows: List.generate(widget.table.rows.length, (i) => i)
                  .skip(page * 20)
                  .take(20)
                  .map(
                    (index) => DataRow(
                      cells: [
                        DataCell(Text('${widget.table.sourceRows[index]}')),
                        ...List.generate(
                          widget.table.headers.length,
                          (c) => DataCell(
                            SizedBox(
                              width: 160,
                              child: Text(
                                c < widget.table.rows[index].length
                                    ? '${widget.table.rows[index][c] ?? ''}'
                                    : '',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            tooltip: 'Editar linha',
                            onPressed: () => edit(index),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: page > 0 ? () => setState(() => page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Página ${page + 1}'),
              IconButton(
                onPressed: (page + 1) * 20 < widget.table.rows.length
                    ? () => setState(() => page++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Categorias ausentes são sugeridas por palavras-chave. Revise em Auditoria. Não há conversão entre moedas. Valores e categorias confirmados serão usados nos cálculos.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed:
                preview.entries.isNotEmpty &&
                    (preview.errors.isEmpty || skipInvalid)
                ? () => Navigator.pop(
                    context,
                    ReportDocument(
                      widget.documentId,
                      widget.table.source,
                      preview.entries,
                    ),
                  )
                : null,
            icon: const Icon(Icons.check),
            label: Text('Confirmar ${preview.entries.length} lançamentos'),
          ),
        ],
      ),
    );
  }
}
