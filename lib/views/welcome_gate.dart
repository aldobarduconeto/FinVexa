import 'package:flutter/material.dart';

import '../services/preferences_storage.dart';

class WelcomeGate extends StatefulWidget {
  const WelcomeGate({super.key, required this.child});
  final Widget child;

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  final _storage = PreferencesStorage();
  bool? _completed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var completed = false;
    try {
      completed = await _storage.welcomeCompleted();
    } catch (_) {
      // The welcome screen remains accessible if local storage is unavailable.
    }
    if (mounted) setState(() => _completed = completed);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    var saved = false;
    try {
      saved = await _storage.completeWelcome();
    } catch (_) {
      // Allow access to the application even if the preference could not be saved.
    }
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar a conclusão. A apresentação pode aparecer novamente.',
          ),
        ),
      );
    }
    setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_completed == true) return widget.child;
    return Scaffold(
      body: SafeArea(
        child: _completed == null
            ? const Center(child: CircularProgressIndicator())
            : _WelcomeContent(onStart: _saving ? null : _finish),
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({required this.onStart});
  final VoidCallback? onStart;

  static const _cardPadding = 18.0;
  static const _iconSize = 24.0;
  static const _iconGap = 12.0;
  static const _textGap = 5.0;

  static const features = [
    (
      Icons.file_open_outlined,
      'Importação e conferência',
      'Importe PDF com texto, Excel, CSV, TSV, OFX e JSON. Confira colunas, corrija valores e confirme os lançamentos.',
    ),
    (
      Icons.post_add_outlined,
      'Criar relatório',
      'Escolha uma demonstração contábil, um relatório gerencial ou um modelo personalizado. Exporte em PDF, Excel, CSV, TSV ou JSON.',
    ),
    (
      Icons.cloud_download_outlined,
      'Fontes de relatórios',
      'Cadastre links diretos e baixe relatórios por empresa. Escolha um recorte de 1 mês a 10 anos e informe o ticker da B3 quando aplicável.',
    ),
    (
      Icons.insights_outlined,
      'Dashboard financeiro',
      'Explore receitas, despesas, lucro, margem, caixa e patrimônio em gráficos de evolução e variação. Filtre por empresa, conta, categoria, período e moeda.',
    ),
    (
      Icons.compare_arrows,
      'Comparação e histórico',
      'Compare séries por período, documento ou empresa. Busque indicadores, ordene desvios, confira os lançamentos de origem e salve comparações.',
    ),
    (
      Icons.calculate_outlined,
      'Indicadores contábeis e microeconômicos',
      'Consulte 36 cálculos, incluindo EBITDA, ROI, liquidez, endividamento, ponto de equilíbrio e elasticidade, com fórmula e rubricas de origem.',
    ),
    (
      Icons.fact_check_outlined,
      'Auditoria e revisão',
      'Investigue duplicidades, divergências, classificações inconsistentes e valores atípicos. Confirme ou descarte alertas e registre suas observações.',
    ),
    (
      Icons.ios_share_outlined,
      'Relatórios e exportação',
      'Exporte em PDF, Excel ou CSV. Selecione as seções, inclua observações e mantenha o histórico das análises.',
    ),
    (
      Icons.settings_outlined,
      'Preferências e backup',
      'Personalize tema, importação, auditoria e exportação. Gerencie relatórios e revisões no dispositivo, com backup e restauração.',
    ),
  ];

  double _cardHeight(BuildContext context, double width) {
    final theme = Theme.of(context);
    final defaultStyle = DefaultTextStyle.of(context).style;
    final textWidth = (width - 2 * _cardPadding - _iconSize - _iconGap).clamp(
      0.0,
      double.infinity,
    );
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );

    double measure(String value, TextStyle? style) {
      painter.text = TextSpan(text: value, style: defaultStyle.merge(style));
      painter.layout(maxWidth: textWidth);
      return painter.height;
    }

    var contentHeight = _iconSize;
    for (final (_, title, description) in features) {
      final height =
          measure(title, theme.textTheme.titleMedium) +
          _textGap +
          measure(description, theme.textTheme.bodySmall);
      if (height > contentHeight) contentHeight = height;
    }
    painter.dispose();
    return (contentHeight + 2 * _cardPadding).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= 700 ? 36.0 : 18.0;
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1050),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: EdgeInsets.all(padding),
                          decoration: BoxDecoration(
                            color: const Color(0xff101b32),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/branding/finvexa.png',
                                  width: 56,
                                  height: 56,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Boas-vindas ao FinVexa',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Importe relatórios, compare resultados e confira a origem dos números.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xffcbd5e6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'O que você pode fazer',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, box) {
                            final width = box.maxWidth >= 620
                                ? (box.maxWidth - 14) / 2
                                : box.maxWidth;
                            final height = _cardHeight(context, width);
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                for (final (icon, title, description)
                                    in features)
                                  SizedBox(
                                    width: width,
                                    height: height,
                                    child: Card(
                                      margin: EdgeInsets.zero,
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                          _cardPadding,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              icon,
                                              size: _iconSize,
                                              color: colors.primary,
                                            ),
                                            const SizedBox(width: _iconGap),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    title,
                                                    style: theme
                                                        .textTheme
                                                        .titleMedium,
                                                  ),
                                                  const SizedBox(
                                                    height: _textGap,
                                                  ),
                                                  Text(
                                                    description,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Começar a usar'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
