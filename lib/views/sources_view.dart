import 'package:flutter/material.dart';

import 'package:finvexa/models/report_sources.dart';

class SourcesView extends StatefulWidget {
  const SourcesView({
    super.key,
    required this.sources,
    required this.onSave,
    required this.onAnalyze,
    required this.busy,
    this.progress,
    required this.onStop,
    required this.stopping,
  });
  final List<ReportSource> sources;
  final Future<void> Function(List<ReportSource>) onSave;
  final Future<void> Function(ReportSource, DateTime, DateTime) onAnalyze;
  final bool busy, stopping;
  final String? progress;
  final VoidCallback onStop;

  @override
  State<SourcesView> createState() => _SourcesViewState();
}

class _SourcesViewState extends State<SourcesView> {
  int selected = 0;
  int months = 12;
  DateTime end = DateTime.now();

  Future<void> edit([int? index]) async {
    final original = index == null ? null : widget.sources[index];
    var company = original?.company ?? '';
    var address = original?.address ?? '';
    var extension = original?.extension ?? 'pdf';
    var ticker = original?.ticker ?? '';
    final key = GlobalKey<FormState>();
    final result = await showDialog<ReportSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index == null ? 'Adicionar fonte' : 'Editar fonte'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: company,
                    onChanged: (value) => company = value,
                    decoration: const InputDecoration(labelText: 'Empresa'),
                    validator: (value) =>
                        value!.trim().isEmpty ? 'Informe a empresa.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: ticker,
                    decoration: const InputDecoration(
                      labelText: 'Ticker na B3 (opcional)',
                    ),
                    onChanged: (value) => ticker = value.trim().toUpperCase(),
                    validator: (_) =>
                        ticker.isEmpty ||
                            RegExp(r'^[A-Z]{4}[0-9]{1,2}$').hasMatch(ticker)
                        ? null
                        : 'Informe um ticker como PETR4.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: address,
                    onChanged: (value) => address = value,
                    decoration: const InputDecoration(
                      labelText: 'Endereço HTTPS do relatório',
                    ),
                    validator: (value) {
                      try {
                        ReportSource(
                          '',
                          value!.trim(),
                          extension,
                        ).reports(end, end).first;
                        return null;
                      } on FormatException catch (error) {
                        return error.message.toString();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Use {ano} para arquivos anuais e {ano} com {mes} para arquivos mensais. Um link sem marcadores baixa um único arquivo consolidado.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: extension,
                    decoration: const InputDecoration(
                      labelText: 'Formato do arquivo',
                    ),
                    items: [
                      for (final item in reportExtensions)
                        DropdownMenuItem(
                          value: item,
                          child: Text(item.toUpperCase()),
                        ),
                    ],
                    onChanged: (value) => extension = value!,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(
                  context,
                  ReportSource(
                    company.trim(),
                    address.trim(),
                    extension,
                    ticker: ticker,
                  ),
                );
              }
            },
            child: const Text('Salvar fonte'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    final updated = [...widget.sources];
    if (index == null) {
      updated.add(result);
      setState(() => selected = updated.length - 1);
    } else {
      updated[index] = result;
    }
    await widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final sources = widget.sources;
    final index = selected < sources.length ? selected : 0;
    final source = sources.isEmpty ? null : sources[index];
    final first = DateTime(end.year, end.month - months + 1);
    final last = DateTime(end.year, end.month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fontes de relatórios',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Cadastre links diretos para baixar, conferir e analisar os relatórios de uma empresa.',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: widget.busy ? null : () => edit(),
          icon: const Icon(Icons.add_link),
          label: const Text('Adicionar fonte'),
        ),
        if (source != null) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: ValueKey((index, sources.length)),
            initialValue: index,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Empresa e fonte'),
            items: [
              for (var i = 0; i < sources.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${sources[i].company} · ${sources[i].uriFor(end).host}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: widget.busy
                ? null
                : (value) => setState(() => selected = value!),
          ),
          Wrap(
            spacing: 8,
            children: [
              if (widget.progress case final progress?) ...[
                Text(progress),
                TextButton(
                  onPressed: widget.stopping ? null : widget.onStop,
                  child: Text(
                    widget.stopping
                        ? 'Interrompendo…'
                        : 'Interromper downloads',
                  ),
                ),
              ],
              TextButton(
                onPressed: widget.busy ? null : () => edit(index),
                child: const Text('Editar fonte'),
              ),
              TextButton(
                onPressed: widget.busy
                    ? null
                    : () async {
                        final updated = [...sources]..removeAt(index);
                        setState(() => selected = 0);
                        await widget.onSave(updated);
                      },
                child: const Text('Remover fonte'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<int>(
                  initialValue: months,
                  decoration: const InputDecoration(labelText: 'Duração'),
                  items: [
                    for (var i = 1; i <= 120; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          i == 1
                              ? '1 mês'
                              : i % 12 == 0
                              ? '${i ~/ 12} ano(s)'
                              : '$i meses',
                        ),
                      ),
                  ],
                  onChanged: widget.busy
                      ? null
                      : (value) => setState(() => months = value!),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.busy
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: end,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (mounted && picked != null) {
                          setState(() => end = picked);
                        }
                      },
                icon: const Icon(Icons.calendar_month),
                label: Text('Mês final · ${monthLabel(last)}'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Recorte de ${monthLabel(first)} a ${monthLabel(last)}. Relatórios anuais e trimestrais mantêm sua granularidade original.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.busy
                ? null
                : () => widget.onAnalyze(source, first, last),
            icon: const Icon(Icons.download),
            label: const Text('Baixar e analisar'),
          ),
        ],
      ],
    );
  }
}
