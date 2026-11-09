import 'preferences_scope.dart';

import 'package:flutter/material.dart';

import 'package:finvexa/models/preferences.dart';

class SettingsView extends StatefulWidget {
  final int documentCount, entryCount, historyCount, storageBytes;
  final Future<void> Function() onBackup,
      onRestore,
      onClearHistory,
      onClearData;
  const SettingsView({
    super.key,
    required this.documentCount,
    required this.entryCount,
    required this.historyCount,
    required this.storageBytes,
    required this.onBackup,
    required this.onRestore,
    required this.onClearHistory,
    required this.onClearData,
  });
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  int section = 0;
  bool working = false;
  final form = GlobalKey<FormState>();
  late TextEditingController company, responsible, email, reportTitle;
  static const labels = [
    'Aparência',
    'Espaço de trabalho',
    'Importação',
    'Análise e auditoria',
    'Exportação',
    'Dados e privacidade',
    'Sobre o FinVexa',
  ];
  static const icons = [
    Icons.palette_outlined,
    Icons.business_outlined,
    Icons.file_open_outlined,
    Icons.tune,
    Icons.ios_share,
    Icons.shield_outlined,
    Icons.info_outline,
  ];
  @override
  void initState() {
    super.initState();
    final p = PreferencesScope.read(context).value;
    company = TextEditingController(text: p.company);
    responsible = TextEditingController(text: p.responsible);
    email = TextEditingController(text: p.email);
    reportTitle = TextEditingController(text: p.exportTitle);
  }

  @override
  void dispose() {
    company.dispose();
    responsible.dispose();
    email.dispose();
    reportTitle.dispose();
    super.dispose();
  }

  Future<bool> update(Map<String, dynamic> patch) async {
    final ok = await PreferencesScope.read(context).update(patch);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar as preferências.'),
        ),
      );
    }
    return ok;
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() => working = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget card(String title, String subtitle, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: double.infinity),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    ),
  );
  Widget field(Widget child) => SizedBox(width: 320, child: child);
  Widget dropdown<T>(
    String label,
    T value,
    Map<T, String> values,
    void Function(T) changed,
  ) => field(
    DropdownButtonFormField<T>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: working
          ? null
          : (v) {
              if (v != null) changed(v);
            },
    ),
  );
  Widget toggle(String title, String subtitle, bool value, String key) =>
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        value: value,
        onChanged: working ? null : (v) => update({key: v}),
      );
  @override
  Widget build(BuildContext context) {
    final controller = PreferencesScope.of(context);
    final p = controller.value;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1000;
        final menu = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(
            labels.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                selected: section == i,
                selectedTileColor: Theme.of(context).colorScheme.primary
                    .withValues(alpha: .09),
                leading: Icon(icons[i], size: 20),
                title: Text(
                  labels[i],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => setState(() => section = i),
              ),
            ),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurações',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.6),
            ),
            const SizedBox(height: 8),
            Text(
              'Seu ambiente de análise, do seu jeito.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 28),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 220, child: menu),
                  const SizedBox(width: 28),
                  Expanded(child: content(p)),
                ],
              )
            else ...[
              DropdownButtonFormField<int>(
                initialValue: section,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoria de configurações',
                ),
                items: List.generate(
                  labels.length,
                  (i) => DropdownMenuItem(value: i, child: Text(labels[i])),
                ),
                onChanged: (v) => setState(() => section = v!),
              ),
              const SizedBox(height: 20),
              content(p),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preferências salvas neste dispositivo. Campos de texto usam o botão Salvar.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget content(AppPreferences p) {
    switch (section) {
      case 0:
        return appearance(p);
      case 1:
        return workspace(p);
      case 2:
        return card(
          'Importação de relatórios',
          'Padrões aplicados às próximas importações. A conferência de dados permanece obrigatória.',
          [
            Wrap(
              spacing: 16,
              runSpacing: 18,
              children: [
                dropdown('Separador decimal padrão', p.decimal, {
                  'auto': 'Automático',
                  'virgula': 'Vírgula · 1.234,56',
                  'ponto': 'Ponto · 1,234.56',
                }, (v) => update({'decimal': v})),
                dropdown('Limite por arquivo', p.importLimitMb, {
                  5: '5 MB',
                  10: '10 MB',
                  20: '20 MB',
                }, (v) => update({'importLimitMb': v})),
              ],
            ),
            const SizedBox(height: 20),
            toggle(
              'Sugerir categorias automaticamente',
              'Usa palavras-chave; confira as sugestões antes de confirmar.',
              p.suggestCategories,
              'suggestCategories',
            ),
            const SizedBox(height: 16),
            info(
              'PDF com texto, Excel, CSV, OFX e JSON. PDFs digitalizados precisam de OCR externo. Empresa e moeda padrão são definidas em Espaço de trabalho.',
            ),
          ],
        );
      case 3:
        return Column(
          children: [
            card(
              'Preferências de análise',
              'Agrupamento e gráfico padrão são aplicados às próximas sessões.',
              [
                Wrap(
                  spacing: 16,
                  runSpacing: 18,
                  children: [
                    dropdown('Agrupamento inicial', p.grouping, {
                      for (final v in [
                        'Documento',
                        'Mês',
                        'Trimestre',
                        'Ano',
                        'Empresa',
                      ])
                        v: v,
                    }, (v) => update({'grouping': v})),
                    dropdown('Gráfico inicial', p.chart, {
                      'bar': 'Barras',
                      'line': 'Linha',
                    }, (v) => update({'chart': v})),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            card(
              'Regras de auditoria',
              'Mudanças nas regras atualizam os alertas do recorte atual. Revisões existentes são preservadas.',
              [
                toggle(
                  'Possíveis duplicidades',
                  'Compara empresa, conta, período, descrição, moeda e valor.',
                  p.auditDuplicates,
                  'auditDuplicates',
                ),
                toggle(
                  'Divergências entre documentos',
                  'Identifica valores diferentes para a mesma referência financeira.',
                  p.auditDivergence,
                  'auditDivergence',
                ),
                toggle(
                  'Classificações inconsistentes',
                  'Detecta categorias ausentes ou diferentes para a mesma descrição.',
                  p.auditClassification,
                  'auditClassification',
                ),
                toggle(
                  'Valores atípicos',
                  'Sinaliza magnitudes acima do limite relativo à mediana.',
                  p.auditOutliers,
                  'auditOutliers',
                ),
                const SizedBox(height: 16),
                dropdown('Limite de valor atípico', p.outlierMultiplier, {
                  2.0: '2 × a mediana',
                  3.0: '3 × a mediana',
                  5.0: '5 × a mediana',
                  10.0: '10 × a mediana',
                }, (v) => update({'outlierMultiplier': v})),
                const SizedBox(height: 16),
                info(
                  'Valores atípicos exigem pelo menos quatro ocorrências comparáveis. Alertas são indicações para conferência; nenhuma regra modifica lançamentos.',
                ),
              ],
            ),
          ],
        );
      case 4:
        return card(
          'Conteúdo padrão dos relatórios',
          'Aplicado às próximas sessões. Você ainda pode personalizar cada exportação na tela Exportar.',
          [
            Form(
              key: form,
              child: TextFormField(
                controller: reportTitle,
                decoration: const InputDecoration(
                  labelText: 'Título padrão do relatório',
                ),
                maxLength: 120,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe um título.' : null,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: working
                  ? null
                  : () async {
                      if (form.currentState!.validate()) {
                        final saved = await update({
                          'exportTitle': reportTitle.text.trim(),
                        });
                        if (saved && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Título padrão salvo.'),
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Salvar título'),
            ),
            const SizedBox(height: 20),
            toggle(
              'Gráficos e indicadores',
              'Inclui gráficos em PDF/Excel e indicadores tabulares em CSV.',
              p.exportCharts,
              'exportCharts',
            ),
            toggle(
              'Tabela comparativa',
              'Valores, diferenças e variações em relação à base.',
              p.exportTable,
              'exportTable',
            ),
            toggle(
              'Lançamentos completos',
              'Todos os registros do recorte, com campos de origem.',
              p.exportEntries,
              'exportEntries',
            ),
            toggle(
              'Auditoria e revisões',
              'Alertas, estado de revisão e observações.',
              p.exportAudit,
              'exportAudit',
            ),
            toggle(
              'Histórico de comparações',
              'Inclui resultados das análises salvas.',
              p.exportHistory,
              'exportHistory',
            ),
          ],
        );
      case 5:
        return data(p);
      case 6:
        return card(
          'FinVexa',
          'Análise financeira com clareza e rastreabilidade.',
          [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/branding/finvexa.png',
                    width: 64,
                    height: 64,
                  ),
                ),
                const SizedBox(width: 18),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FinVexa Desktop',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('Versão 1.0.0 · build 1'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            info(
              'Processamento local de PDF com texto, Excel, CSV, OFX e JSON. Comparações, auditoria, gráficos e relatórios exportáveis.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Método de comparação',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const SelectableText(
              'Diferença = comparado − base\nVariação = diferença / |base| × 100\nAusência ou base zero = N/D\nNão há conversão cambial.',
            ),
            const SizedBox(height: 20),
            Text(
              'Fontes Noto Sans sob SIL Open Font License. Preferências e dados pertencem a este dispositivo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget appearance(AppPreferences p) => Column(
    children: [
      card(
        'Aparência',
        'Escolha uma interface confortável para o seu ambiente de trabalho.',
        [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              themeCard('light', 'Claro', Icons.light_mode_outlined, p),
              themeCard('dark', 'Escuro', Icons.dark_mode_outlined, p),
              themeCard('system', 'Sistema', Icons.desktop_windows_outlined, p),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Cor de destaque',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in [
                ('blue', 'Azul', const Color(0xff3478f6)),
                ('teal', 'Verde', const Color(0xff0f8a78)),
                ('indigo', 'Índigo', const Color(0xff7161d8)),
              ])
                ChoiceChip(
                  label: Text(item.$2),
                  avatar: CircleAvatar(backgroundColor: item.$3, radius: 7),
                  selected: p.accent == item.$1,
                  onSelected: (_) => update({'accent': item.$1}),
                ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 18),
      card(
        'Organização da interface',
        'Ajuste a densidade e o espaço disponível para seus dados.',
        [
          toggle(
            'Layout compacto',
            'Reduz espaçamento de controles e altura das linhas das tabelas.',
            p.compact,
            'compact',
          ),
          toggle(
            'Barra lateral recolhida',
            'Mostra apenas ícones no desktop, com identificação ao passar o mouse.',
            p.collapsedSidebar,
            'collapsedSidebar',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 18,
            children: [
              dropdown('Linhas por página', p.pageSize, {
                10: '10 linhas',
                20: '20 linhas',
                50: '50 linhas',
                100: '100 linhas',
              }, (v) => update({'pageSize': v})),
              dropdown('Tela inicial', p.startPage, {
                0: 'Dashboard',
                1: 'Relatórios',
                2: 'Comparação',
                3: 'Auditoria',
                4: 'Exportar',
                5: 'Configurações',
              }, (v) => update({'startPage': v})),
            ],
          ),
        ],
      ),
    ],
  );
  Widget themeCard(
    String value,
    String label,
    IconData icon,
    AppPreferences p,
  ) {
    final dark = value == 'dark';
    final selected = p.theme == value;
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 176,
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          key: ValueKey('theme-$value'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => update({'theme': value}),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 82,
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xff121722)
                        : const Color(0xffeef1f7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(9),
                  child: Row(
                    children: [
                      Container(
                        width: 25,
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xff252d3d) : Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              height: 10,
                              color: color.withValues(alpha: .4),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Container(
                                color: dark
                                    ? const Color(0xff252d3d)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(icon, size: 17),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label)),
                    if (selected)
                      Icon(Icons.check_circle, size: 17, color: color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget workspace(AppPreferences p) => card(
    'Espaço de trabalho',
    'Identificação local e padrões para novas importações. Não cria conta nem envia mensagens.',
    [
      Form(
        key: form,
        child: Wrap(
          spacing: 16,
          runSpacing: 18,
          children: [
            field(
              TextFormField(
                controller: company,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Empresa padrão'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe a empresa.' : null,
              ),
            ),
            field(
              TextFormField(
                controller: responsible,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Responsável'),
              ),
            ),
            field(
              TextFormField(
                controller: email,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'E-mail de referência (opcional)',
                ),
                validator: (v) =>
                    v != null &&
                        v.isNotEmpty &&
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v.trim())
                    ? 'Informe um e-mail válido.'
                    : null,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      dropdown('Moeda padrão', p.currency, {
        'BRL': 'BRL · Real brasileiro',
        'USD': 'USD · Dólar americano',
        'EUR': 'EUR · Euro',
      }, (v) => update({'currency': v})),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: working
            ? null
            : () async {
                if (form.currentState!.validate()) {
                  final ok = await PreferencesScope.read(context).update({
                    'company': company.text.trim(),
                    'responsible': responsible.text.trim(),
                    'email': email.text.trim(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Espaço de trabalho salvo.'
                              : 'Não foi possível salvar.',
                        ),
                      ),
                    );
                  }
                }
              },
        icon: const Icon(Icons.check, size: 17),
        label: const Text('Salvar preferências'),
      ),
      const SizedBox(height: 18),
      info(
        'A moeda padrão não converte valores existentes. O responsável e o e-mail são incluídos no arquivo de backup como identificação do espaço de trabalho.',
      ),
    ],
  );
  Widget info(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 17,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
  Widget data(AppPreferences p) => Column(
    children: [
      card(
        'Armazenamento local',
        'Gerencie seus relatórios, revisões e preferências.',
        [
          Wrap(
            spacing: 28,
            runSpacing: 18,
            children: [
              stat('${widget.documentCount}', 'Relatórios'),
              stat('${widget.entryCount}', 'Lançamentos'),
              stat('${widget.historyCount}', 'Comparações salvas'),
              stat(
                '${(widget.storageBytes / 1024).toStringAsFixed(1)} KB',
                'Dados estruturados',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: working ? null : () => run(widget.onBackup),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Exportar backup'),
              ),
              OutlinedButton.icon(
                onPressed: working ? null : () => run(widget.onRestore),
                icon: const Icon(Icons.restore),
                label: const Text('Restaurar backup'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          info(
            'O backup JSON contém dados financeiros, revisões, histórico e preferências. Guarde-o em um local seguro. Restaurar um backup substitui o conteúdo atual somente após sua confirmação.',
          ),
        ],
      ),
      const SizedBox(height: 18),
      card('Privacidade', 'Seus arquivos são processados neste dispositivo.', [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline),
          title: Text('Sem envio de relatórios para servidores'),
          subtitle: Text(
            'Não há login, sincronização em nuvem ou backup automático.',
          ),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.folder_outlined),
          title: Text('Arquivos originais preservados'),
          subtitle: Text(
            'Remover dados do FinVexa não apaga os documentos de origem.',
          ),
        ),
      ]),
      const SizedBox(height: 18),
      card(
        'Restaurar e limpar',
        'Estas ações pedem confirmação e afetam apenas o armazenamento local do FinVexa.',
        [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                onPressed: working
                    ? null
                    : () => run(() async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Restaurar preferências?'),
                            content: const Text(
                              'Temas e padrões voltarão aos valores iniciais. Relatórios, revisões e histórico serão preservados.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Restaurar preferências'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) {
                          final ok = await PreferencesScope.read(context)
                              .reset();
                          if (ok) {
                            company.text = 'Minha empresa';
                            responsible.clear();
                            email.clear();
                            reportTitle.text = 'Relatório comparativo FinVexa';
                          }
                        }
                      }),
                child: const Text('Restaurar preferências'),
              ),
              OutlinedButton(
                onPressed: working || widget.historyCount == 0
                    ? null
                    : () => run(widget.onClearHistory),
                child: const Text('Limpar histórico'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed:
                    working ||
                        widget.documentCount == 0 && widget.historyCount == 0
                    ? null
                    : () => run(widget.onClearData),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Apagar dados financeiros'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  Widget stat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 3),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
