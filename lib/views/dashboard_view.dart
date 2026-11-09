import 'package:finvexa/services/financial_catalog.dart';
import 'package:finvexa/services/accounting_indicators.dart';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:finvexa/models/analytics.dart';
import 'package:finvexa/models/export_snapshot.dart';
import 'package:finvexa/models/finance.dart';
import 'package:finvexa/models/dashboard_data.dart';

class FinancialDashboard extends StatefulWidget {
  final Analysis analysis;
  final Map<String, String> listedCompanies;
  final List<AuditAlert> alerts;
  final Map<String, ReviewDecision> decisions;
  final bool initialLineChart, compact;
  final VoidCallback onAudit, onImport;
  final Widget filterControl;
  final bool busy;
  final void Function(String) onCompare;
  final void Function(ReportDocument) onDocument;
  const FinancialDashboard({
    super.key,
    required this.analysis,
    this.listedCompanies = const {},
    required this.alerts,
    required this.decisions,
    required this.onAudit,
    required this.onImport,
    required this.filterControl,
    this.busy = false,
    required this.onCompare,
    required this.onDocument,
    this.initialLineChart = false,
    this.compact = false,
  });
  @override
  State<FinancialDashboard> createState() => _FinancialDashboardState();
}

class _FinancialDashboardState extends State<FinancialDashboard> {
  String? focusLabel, baseLabel;
  late bool lineChart;
  bool showMargins = false;
  final visibleMetrics = <String>{'Receita', 'Despesa', 'Lucro'};
  late List<FinancialSeries> series;
  late FinancialSeries focus;
  FinancialSeries? base;
  ColorScheme get scheme => Theme.of(context).colorScheme;
  String get currency => widget.analysis.filter.currency;
  @override
  void initState() {
    super.initState();
    lineChart = widget.initialLineChart;
  }

  String amount(double value) =>
      money(value).replaceFirst('R\$', currency == 'BRL' ? 'R\$' : currency);
  String decimal(double value, {int digits = 1}) =>
      value.toStringAsFixed(digits).replaceAll('.', ',');
  String signed(double value, {String suffix = '%'}) =>
      '${value > 0 ? '+' : ''}${decimal(value)}$suffix';
  Color metricColor(String category) => category == 'Receita'
      ? scheme.primary
      : category == 'Despesa'
      ? const Color(0xffd79543)
      : category == 'Lucro'
      ? const Color(0xff9a7fdb)
      : category == 'Caixa'
      ? const Color(0xff31a794)
      : const Color(0xff7a96ba);
  Widget section(String title, String subtitle, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: LayoutBuilder(
      builder: (context, box) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 11),
            ),
          ],
        );
        if (action != null && box.maxWidth < 500) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: action),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            if (action != null) ...[const SizedBox(width: 12), action],
          ],
        );
      },
    ),
  );
  Widget panel(Widget child) => Card(
    child: Padding(
      padding: EdgeInsets.all(widget.compact ? 18 : 24),
      child: child,
    ),
  );
  Widget badge(String text, {IconData? icon, Color? color}) {
    final tint = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tint),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }

  Widget selector(
    String label,
    String? value,
    List<FinancialSeries> options,
    ValueChanged<String?> changed,
  ) => SizedBox(
    width: 260,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value-${options.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          label == 'Série em foco'
              ? Icons.calendar_month_outlined
              : Icons.compare_arrows,
          size: 18,
        ),
        hintText: options.isEmpty ? 'Sem outra série disponível' : null,
      ),
      items: options
          .map(
            (s) => DropdownMenuItem(
              value: s.label,
              child: Tooltip(
                message: s.label,
                child: Text(
                  dashboardLabel(s.label),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
          .toList(),
      onChanged: options.isEmpty ? null : changed,
    ),
  );
  @override
  Widget build(BuildContext context) {
    series = widget.analysis.series;
    if (series.isEmpty) {
      return panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.filter_alt_off_outlined),
            const SizedBox(height: 12),
            const Text('Nenhum dado no recorte atual'),
            const SizedBox(height: 6),
            Text(
              'Ajuste os filtros ou selecione mais relatórios.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    focus = series.firstWhere(
      (s) => s.label == focusLabel,
      orElse: () => series.last,
    );
    final alternatives = series.where((s) => s.label != focus.label).toList();
    final index = series.indexOf(focus);
    base = alternatives.isEmpty
        ? null
        : alternatives.firstWhere(
            (s) => s.label == baseLabel,
            orElse: () => index > 0 ? series[index - 1] : alternatives.first,
          );
    final changes = base == null
        ? <DashboardChange>[]
        : dashboardChanges(base!, focus, widget.analysis.indicatorNames);
    final available = [
      focus.metric('Receita'),
      focus.metric('Despesa'),
      focus.profit,
      focus.margin,
      focus.metric('Caixa'),
      focus.metric('Patrimônio'),
    ].where((v) => v != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header(),
        const SizedBox(height: 20),
        widget.filterControl,
        Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            selector(
              'Série em foco',
              focus.label,
              series,
              (v) => setState(() => focusLabel = v),
            ),
            selector(
              'Comparar com',
              base?.label,
              alternatives,
              (v) => setState(() => baseLabel = v),
            ),
            badge(
              '${focus.entries.length} lançamentos',
              icon: Icons.receipt_long_outlined,
              color: scheme.onSurfaceVariant,
            ),
            badge(
              'Agrupamento: ${widget.analysis.mode}',
              icon: Icons.layers_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, box) {
            final count = box.maxWidth >= 1000
                ? 4
                : box.maxWidth >= 560
                ? 2
                : 1;
            final width = (box.maxWidth - (count - 1) * 16) / count;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final metric in [
                  'Receita',
                  'Despesa',
                  'Lucro',
                  'Margem líquida',
                ])
                  SizedBox(width: width, child: kpi(metric)),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 1000
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: performanceChart()),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: reviewCard(available)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    performanceChart(),
                    const SizedBox(height: 20),
                    reviewCard(available),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, box) {
            final cards = [
              positionCard(
                'Caixa',
                Icons.account_balance_wallet_outlined,
                'Valores classificados como caixa no arquivo.',
              ),
              positionCard(
                'Patrimônio',
                Icons.account_balance_outlined,
                'Valores patrimoniais classificados no arquivo.',
              ),
            ];
            return box.maxWidth >= 660
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 20),
                      Expanded(child: cards[1]),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [cards[0], const SizedBox(height: 16), cards[1]],
                  );
          },
        ),
        const SizedBox(height: 24),
        if (accountingPanel() case final Widget indicators) ...[
          indicators,
          const SizedBox(height: 24),
        ],
        indicatorBars(changes),
        const SizedBox(height: 24),
        comparisonHighlights(changes),
        const SizedBox(height: 24),
        sources(),
        const SizedBox(height: 14),
        Text(
          'Valores preservam os sinais e a classificação da importação. Totais e subtotais não são reconciliados automaticamente. Variação não indica, por si só, melhora ou piora.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  Widget header() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [scheme.primary.withValues(alpha: .12), scheme.surface],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: scheme.outlineVariant),
    ),
    child: Padding(
      padding: EdgeInsets.all(widget.compact ? 20 : 28),
      child: LayoutBuilder(
        builder: (context, box) {
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              badge('PAINEL FINANCEIRO', icon: Icons.space_dashboard_outlined),
              const SizedBox(height: 12),
              Text(
                'Visão financeira',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Acompanhe indicadores, compare períodos e revise divergências.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
          final actions = Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              badge(currency, icon: Icons.payments_outlined),
              FilledButton.icon(
                onPressed: widget.busy ? null : widget.onImport,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Importar relatórios'),
              ),
            ],
          );
          return box.maxWidth >= 700
              ? Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 16),
                    actions,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 16), actions],
                );
        },
      ),
    ),
  );
  Widget kpi(String metric) {
    final margin = metric == 'Margem líquida';
    final value = margin ? focus.margin : focus.metric(metric);
    final previous = margin ? base?.margin : base?.metric(metric);
    final delta = margin
        ? difference(previous, value)
        : variation(previous, value);
    final color = metricColor(margin ? 'Lucro' : metric);
    final icons = {
      'Receita': Icons.trending_up_rounded,
      'Despesa': Icons.payments_outlined,
      'Lucro': Icons.insights_outlined,
      'Margem líquida': Icons.donut_large_outlined,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: color.withValues(alpha: .65), width: 3),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(widget.compact ? 18 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metric,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icons[metric], size: 18, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 38,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value == null
                        ? 'Não informado'
                        : margin
                        ? '${decimal(value)}%'
                        : amount(value),
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.8,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Tooltip(
                    message: margin
                        ? 'Diferença em pontos percentuais entre as margens.'
                        : 'Variação sobre o valor absoluto da base. Aumento não implica melhora.',
                    child: badge(
                      delta == null
                          ? 'Variação N/D'
                          : signed(delta, suffix: margin ? ' p.p.' : '%'),
                      icon: delta == null
                          ? Icons.remove
                          : delta > 0
                          ? Icons.north_east
                          : delta < 0
                          ? Icons.south_east
                          : Icons.horizontal_rule,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 32,
                child: Text(
                  base == null
                      ? 'Importe outra série para comparar.'
                      : previous == null
                      ? 'Sem valor correspondente na base.'
                      : 'Base: ${margin ? '${decimal(previous)}%' : amount(previous)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 11),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 26,
                child:
                    widget.analysis.mode == 'Empresa' ||
                        widget.analysis.mode == 'Documento'
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          margin
                              ? 'Lucro informado ÷ |receita|'
                              : 'Valor informado na série em foco',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 10),
                        ),
                      )
                    : CustomPaint(
                        size: const Size(double.infinity, 26),
                        painter: MetricSparkline(
                          series
                              .map((s) => margin ? s.margin : s.metric(metric))
                              .toList(),
                          series.indexOf(focus),
                          color,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget positionCard(String metric, IconData icon, String hint) {
    final value = focus.metric(metric), previous = base?.metric(metric);
    final change = variation(previous, value);
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: metricColor(metric).withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: metricColor(metric)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Série em foco',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              badge(
                change == null ? 'N/D' : signed(change),
                color: metricColor(metric),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value == null ? 'Não informado' : amount(value),
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${previous == null ? 'Base sem valor informado' : 'Base: ${amount(previous)}'} · $hint',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget reviewCard(int available) {
    final pending = widget.alerts
        .where(
          (a) => (widget.decisions[a.id]?.status ?? 'Pendente') == 'Pendente',
        )
        .length;
    final confirmed = widget.alerts
        .where((a) => widget.decisions[a.id]?.status == 'Confirmado')
        .length;
    final missing = <String>[
      for (final metric in [
        'Receita',
        'Despesa',
        'Lucro',
        'Caixa',
        'Patrimônio',
      ])
        if (focus.metric(metric) == null) metric,
      if (focus.margin == null) 'Margem líquida',
    ];
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section(
            'Conferência dos dados',
            'Disponibilidade e alertas do recorte.',
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$available',
                style: TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  letterSpacing: -1,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 7, left: 6),
                  child: Text(
                    'de 6 indicadores disponíveis',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: available / 6,
              minHeight: 5,
              color: scheme.primary,
              backgroundColor: scheme.primary.withValues(alpha: .1),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            missing.isEmpty
                ? 'Todos os indicadores do painel estão disponíveis.'
                : 'Sem informação: ${missing.join(', ')}.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 11),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),
          auditCount(
            'Alertas pendentes',
            pending,
            Icons.pending_actions_outlined,
          ),
          const SizedBox(height: 14),
          auditCount(
            'Inconsistências confirmadas',
            confirmed,
            Icons.fact_check_outlined,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onAudit,
              icon: const Icon(Icons.arrow_forward, size: 15),
              label: const Text('Revisar auditoria'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Disponibilidade de indicadores não garante consistência contábil. Nenhum valor é alterado pela auditoria.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget auditCount(String label, int count, IconData icon) => Row(
    children: [
      Icon(icon, size: 17, color: scheme.onSurfaceVariant),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ),
      Text(
        '$count',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ],
  );
  Widget performanceChart() {
    final selected = [
      'Receita',
      'Despesa',
      'Lucro',
    ].where(visibleMetrics.contains).toList();
    final values = [
      for (final s in series)
        for (final metric in selected)
          if (s.metric(metric) != null) s.metric(metric)!,
    ];
    final low = values.isEmpty ? 0.0 : min(0.0, values.reduce(min));
    final high = values.isEmpty ? 1.0 : max(0.0, values.reduce(max));
    final span = max(1.0, high - low);
    final minY = low < 0 ? low - span * .15 : 0.0;
    final maxY = low == 0 && high == 0 ? 1.0 : high + span * .18;
    final titles = FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 56,
          getTitlesWidget: (value, meta) => Text(
            value.abs() >= 1000000
                ? '${decimal(value / 1000000, digits: 1)} mi'
                : value.abs() >= 1000
                ? '${decimal(value / 1000, digits: 0)} mil'
                : decimal(value, digits: 0),
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 45,
          interval: 1,
          getTitlesWidget: (value, meta) {
            if (value != value.roundToDouble() ||
                value < 0 ||
                value >= series.length) {
              return const SizedBox.shrink();
            }
            final s = series[value.toInt()];
            return Padding(
              padding: const EdgeInsets.only(top: 11),
              child: Tooltip(
                message: s.label,
                child: SizedBox(
                  width: 100,
                  child: Text(
                    dashboardLabel(s.label),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: s == focus
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: s == focus
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final grid = FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => FlLine(
        color: scheme.outlineVariant,
        strokeWidth: 1,
        dashArray: [4, 5],
      ),
    );
    final toggle = SegmentedButton<bool>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontFamily: 'NotoSans'),
        ),
      ),
      segments: const [
        ButtonSegment(
          value: false,
          icon: Icon(Icons.bar_chart, size: 17),
          tooltip: 'Gráfico de barras',
        ),
        ButtonSegment(
          value: true,
          icon: Icon(Icons.show_chart, size: 17),
          tooltip: 'Gráfico de linhas',
        ),
      ],
      selected: {lineChart},
      onSelectionChanged: (v) => setState(() => lineChart = v.first),
    );
    final chart = values.isEmpty
        ? const SizedBox(
            height: 280,
            child: Center(
              child: Text(
                'Nenhum valor disponível para os indicadores selecionados.',
              ),
            ),
          )
        : LayoutBuilder(
            builder: (context, box) {
              final Widget plot;
              if (lineChart) {
                plot = LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: max(1, series.length - 1).toDouble(),
                    minY: minY,
                    maxY: maxY,
                    gridData: grid,
                    titlesData: titles,
                    borderData: FlBorderData(show: false),
                    lineBarsData: lineSegments(selected),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => scheme.surfaceContainerHigh,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (spots) => spots
                            .map(
                              (spot) => LineTooltipItem(
                                '${dashboardLabel(series[spot.x.round()].label)}\n${selected.firstWhere((metric) => metricColor(metric) == spot.bar.color, orElse: () => 'Indicador')}: ${amount(spot.y)}',
                                TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 11,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                );
              } else {
                plot = BarChart(
                  BarChartData(
                    minY: minY,
                    maxY: maxY,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: grid,
                    titlesData: titles,
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(
                      series.length,
                      (i) => BarChartGroupData(
                        x: i,
                        barsSpace: 5,
                        barRods: [
                          for (final metric in selected)
                            if (series[i].metric(metric) != null)
                              BarChartRodData(
                                toY: series[i].metric(metric)!,
                                width: 16,
                                color: metricColor(metric).withValues(
                                  alpha: series[i] == focus ? 1 : .65,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                        ],
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => scheme.surfaceContainerHigh,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final metrics = selected
                              .where((m) => series[group.x].metric(m) != null)
                              .toList();
                          return BarTooltipItem(
                            '${dashboardLabel(series[group.x].label)}\n${metrics[rodIndex]}: ${amount(rod.toY)}',
                            TextStyle(fontSize: 11, color: scheme.onSurface),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: max(box.maxWidth, series.length * 115.0),
                  height: 280,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: plot,
                  ),
                ),
              );
            },
          );
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section(
            widget.analysis.mode == 'Empresa' ||
                    widget.analysis.mode == 'Documento'
                ? 'Resultados por série'
                : 'Evolução dos resultados',
            'Receita, despesa e lucro informados · $currency',
            action: toggle,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in ['Receita', 'Despesa', 'Lucro'])
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  avatar: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: metricColor(metric),
                      shape: BoxShape.circle,
                    ),
                  ),
                  label: Text(metric, style: const TextStyle(fontSize: 10)),
                  selected: visibleMetrics.contains(metric),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      visibleMetrics.add(metric);
                    } else if (visibleMetrics.length > 1) {
                      visibleMetrics.remove(metric);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          chart,
          const SizedBox(height: 12),
          Text(
            'Valores ausentes não viram zero. Os sinais originais são preservados.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  List<LineChartBarData> lineSegments(List<String> metrics) {
    final lines = <LineChartBarData>[];
    for (final metric in metrics) {
      var points = <FlSpot>[];
      void finish() {
        if (points.isNotEmpty) {
          lines.add(
            LineChartBarData(
              spots: points,
              color: metricColor(metric),
              barWidth: 2.5,
              isCurved: false,
              dotData: const FlDotData(show: true),
            ),
          );
          points = [];
        }
      }

      for (var i = 0; i < series.length; i++) {
        final value = series[i].metric(metric);
        if (value == null) {
          finish();
        } else {
          points.add(FlSpot(i.toDouble(), value));
        }
      }
      finish();
    }
    return lines;
  }

  Widget? accountingPanel() {
    final companies = focus.entries.map((entry) => entry.company).toSet();
    if (companies.length != 1) return null;
    final ticker = widget.listedCompanies[companies.single];
    final periods = focus.entries.map((entry) => entry.period).toSet();
    final rows = periods.length == 1
        ? financialCatalog(AccountingIndicators(focus.entries))
        : <FinancialMetric>[];
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section(
            ticker == null
                ? 'Indicadores contábeis e microeconômicos'
                : 'Indicadores contábeis e microeconômicos · $ticker',
            '${companies.single} · ${dashboardLabel(focus.label)}',
          ),
          if (periods.length != 1)
            const Text(
              'Selecione um único período contábil nos filtros para calcular estes indicadores.',
            )
          else ...[
            const Text(
              'Abra um indicador para conferir a composição e a origem dos valores. N/D indica rubrica ausente, ambígua ou valor incompatível.',
            ),
            for (final group in rows.map((row) => row.group).toSet())
              ExpansionTile(
                title: Text(group),
                subtitle: Text(
                  '${rows.where((row) => row.group == group && row.value != null).length} indicadores calculados',
                ),
                children: [
                  for (final row in rows.where((row) => row.group == group))
                    ExpansionTile(
                      title: Text(row.name),
                      subtitle: Text(
                        row.value == null
                            ? 'N/D'
                            : row.unit == 'money'
                            ? amount(row.value!)
                            : '${decimal(row.value!, digits: 2)} ${row.unit}',
                      ),
                      children: [
                        ListTile(title: Text(row.formula)),
                        for (final input in row.inputs)
                          ListTile(
                            title: Text(input.label),
                            subtitle: Text(
                              input.entry == null
                                  ? 'Rubrica ausente ou ambígua. Nomes aceitos: ${input.names.join(', ')}'
                                  : '${input.entry!.source} · linha ${input.entry!.row}',
                            ),
                            trailing: Text(
                              input.entry == null
                                  ? 'N/D'
                                  : decimal(input.entry!.amount, digits: 2),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget indicatorBars(List<DashboardChange> changes) {
    final rows = showMargins
        ? series
              .map(
                (item) =>
                    (label: dashboardLabel(item.label), value: item.margin),
              )
              .toList()
        : changes
              .where((item) => !item.missing && item.changed)
              .take(8)
              .map((item) => (label: item.label, value: item.delta))
              .toList();
    final scale = rows.fold<double>(
      0,
      (largest, row) => max(largest, row.value?.abs() ?? 0),
    );
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section(
            'Indicadores em barras',
            showMargins
                ? 'Margem líquida por série. Ausências aparecem como N/D.'
                : 'Até oito diferenças absolutas entre a série em foco e a base.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Diferenças')),
                ButtonSegment(value: true, label: Text('Margem')),
              ],
              selected: {showMargins},
              onSelectionChanged: (value) =>
                  setState(() => showMargins = value.first),
            ),
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            const Text('Nenhuma diferença calculável neste recorte.')
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                primary: false,
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final value = row.value;
                  final negative = (value ?? 0) < 0;
                  final color = negative ? scheme.tertiary : scheme.primary;
                  final fraction = scale == 0
                      ? 0.0
                      : (value?.abs() ?? 0) / scale;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(row.label)),
                            const SizedBox(width: 12),
                            Text(
                              value == null
                                  ? 'N/D'
                                  : showMargins
                                  ? signed(value)
                                  : '${value > 0 ? '+' : ''}${amount(value)}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            for (final left in [true, false])
                              Expanded(
                                child: Container(
                                  height: 8,
                                  color: scheme.surfaceContainerHighest,
                                  alignment: left
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: left == negative
                                        ? fraction
                                        : 0,
                                    child: SizedBox(
                                      height: 8,
                                      child: ColoredBox(color: color),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'O centro representa zero. Valores negativos ficam à esquerda.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget comparisonHighlights(List<DashboardChange> changes) {
    final highlights = changes.where((c) => c.changed).take(5).toList();
    final changed = changes.where((c) => !c.missing && c.changed).length;
    final missing = changes.where((c) => c.missing).length;
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section(
            'Comparação entre períodos',
            base == null
                ? 'Importe ou selecione outra série para comparar.'
                : '${dashboardLabel(base!.label)} → ${dashboardLabel(focus.label)}',
            action: base == null
                ? null
                : TextButton.icon(
                    onPressed: () => widget.onCompare(base!.label),
                    icon: const Icon(Icons.arrow_forward, size: 15),
                    label: const Text('Ver comparação completa'),
                  ),
          ),
          if (base != null) ...[
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                badge(
                  '$changed indicadores alterados',
                  icon: Icons.compare_arrows,
                  color: scheme.onSurfaceVariant,
                ),
                badge(
                  '$missing sem correspondência',
                  icon: Icons.rule_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (highlights.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Nenhuma diferença identificada entre as séries selecionadas.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: box.maxWidth),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('INDICADOR')),
                        DataColumn(label: Text('BASE')),
                        DataColumn(label: Text('EM FOCO')),
                        DataColumn(label: Text('DIFERENÇA')),
                        DataColumn(label: Text('VARIAÇÃO')),
                      ],
                      rows: highlights
                          .map(
                            (c) => DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 210,
                                    child: Text(
                                      c.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    c.base == null
                                        ? 'Não informado'
                                        : amount(c.base!),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    c.focus == null
                                        ? 'Não informado'
                                        : amount(c.focus!),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    c.delta == null
                                        ? 'Sem correspondência'
                                        : amount(c.delta!),
                                    style: TextStyle(
                                      color: c.missing
                                          ? scheme.onSurfaceVariant
                                          : scheme.onSurface,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    c.percent == null
                                        ? 'N/D'
                                        : signed(c.percent!),
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              'Até 5 destaques: ausências primeiro, depois maiores diferenças absolutas. N/D indica base zero ou valor ausente.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget sources() {
    final docs = widget.analysis.documents
        .where((d) => d.entries.any(widget.analysis.filter.accepts))
        .toList();
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section(
            'Origens da análise',
            '${docs.length} arquivos e ${widget.analysis.entries.length} lançamentos no recorte atual.',
          ),
          LayoutBuilder(
            builder: (context, box) {
              final count = box.maxWidth >= 900
                  ? 3
                  : box.maxWidth >= 560
                  ? 2
                  : 1;
              final width = (box.maxWidth - (count - 1) * 14) / count;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: docs
                    .take(3)
                    .map(
                      (d) => SizedBox(
                        width: width,
                        child: Material(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => widget.onDocument(d),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 20,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${d.entries.where(widget.analysis.filter.accepts).length} lançamentos neste recorte',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.north_east,
                                    size: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MetricSparkline extends CustomPainter {
  final List<double?> values;
  final int focus;
  final Color color;
  MetricSparkline(this.values, this.focus, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final real = values.whereType<double>().toList();
    if (real.isEmpty || values.length < 2) return;
    final low = real.reduce(min), high = real.reduce(max);
    final span = max(1.0, high - low);
    Offset point(int i, double value) => Offset(
      2 + (size.width - 4) * i / (values.length - 1),
      size.height - 4 - (size.height - 8) * (value - low) / span,
    );
    final paint = Paint()
      ..color = color.withValues(alpha: .65)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    var path = Path();
    var started = false;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        if (started) canvas.drawPath(path, paint);
        path = Path();
        started = false;
        continue;
      }
      final p = point(i, value);
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (started) canvas.drawPath(path, paint);
    if (focus >= 0 && focus < values.length && values[focus] != null) {
      canvas.drawCircle(
        point(focus, values[focus]!),
        3,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MetricSparkline old) =>
      old.values != values || old.focus != focus || old.color != color;
}
