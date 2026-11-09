import 'package:finvexa/services/accounting_indicators.dart';
import 'package:finvexa/models/analytics.dart';

typedef FinancialMetric = ({
  String group,
  String name,
  String formula,
  double? value,
  String unit,
  List<AccountingInput> inputs,
});

List<FinancialMetric> financialCatalog(AccountingIndicators data) {
  final metrics = <FinancialMetric>[];
  var group = 'Resultado e rentabilidade';
  AccountingInput input(String label, [List<String> aliases = const []]) =>
      data.input(label, [normalized(label), ...aliases]);

  void add(
    String name,
    String formula,
    List<AccountingInput> inputs,
    double? Function(List<double>) calculate, {
    String unit = 'money',
  }) {
    final values = inputs
        .map((item) => item.entry?.amount)
        .whereType<double>()
        .toList();
    final result =
        values.length == inputs.length && values.every((v) => v.isFinite)
        ? calculate(values)
        : null;
    metrics.add((
      group: group,
      name: name,
      formula: formula,
      inputs: inputs,
      value: result?.isFinite == true ? result : null,
      unit: unit,
    ));
  }

  double? ratio(double numerator, double denominator, [double scale = 1]) =>
      denominator > 0 ? numerator / denominator * scale : null;
  double sum(List<double> values) => values.reduce((a, b) => a + b);

  final revenue = data.revenue;
  final income = data.earnings.first;
  final gross = input('Lucro bruto', ['resultado bruto']);
  final assetsAverage = input('Ativo total médio');
  final equityAverage = input('Patrimônio líquido médio');
  final ebitdaInputs = [...data.earnings, data.depreciation];

  add(
    'EBIT / LAJIR',
    'Lucro líquido + tributos sobre o lucro + despesa financeira líquida',
    data.earnings,
    sum,
  );
  add(
    'EBITDA / LAJIDA',
    'EBIT + depreciação, amortização e exaustão',
    ebitdaInputs,
    (_) => data.ebitda,
  );
  add(
    'Margem EBITDA',
    'EBITDA ÷ receita líquida × 100',
    [...ebitdaInputs, revenue],
    (_) => data.ebitdaMargin,
    unit: '%',
  );
  add(
    'ROI',
    'Retorno líquido do investimento ÷ custo do investimento × 100',
    data.investment,
    (_) => data.roi,
    unit: '%',
  );
  add(
    'Margem bruta',
    'Lucro bruto ÷ receita líquida × 100',
    [gross, revenue],
    (v) => ratio(v[0], v[1], 100),
    unit: '%',
  );
  add(
    'Margem líquida',
    'Lucro líquido ÷ receita líquida × 100',
    [income, revenue],
    (v) => ratio(v[0], v[1], 100),
    unit: '%',
  );
  add(
    'ROA',
    'Lucro líquido ÷ ativo total médio × 100',
    [income, assetsAverage],
    (v) => ratio(v[0], v[1], 100),
    unit: '%',
  );
  add(
    'ROE',
    'Lucro líquido ÷ patrimônio líquido médio × 100',
    [income, equityAverage],
    (v) => ratio(v[0], v[1], 100),
    unit: '%',
  );
  add(
    'Giro do ativo',
    'Receita líquida ÷ ativo total médio',
    [revenue, assetsAverage],
    (v) => ratio(v[0], v[1]),
    unit: '×',
  );
  add(
    'LPA simples',
    'Lucro atribuível aos acionistas ordinários ÷ média ponderada de ações ordinárias',
    [
      input('Lucro atribuível aos acionistas ordinários'),
      input('Média ponderada de ações ordinárias'),
    ],
    (v) => ratio(v[0], v[1]),
    unit: 'money',
  );

  group = 'Liquidez e endividamento';
  final current = input('Ativo circulante');
  final liabilities = input('Passivo circulante');
  final longLiabilities = input('Passivo não circulante');
  final inventory = input('Estoques');
  final cash = input('Caixa e equivalentes de caixa');
  final equity = input('Patrimônio líquido');
  final assets = input('Ativo total');
  final debt = input('Dívida bruta', ['divida financeira bruta']);
  add('Capital de giro líquido', 'Ativo circulante − passivo circulante', [
    current,
    liabilities,
  ], (v) => v[0] - v[1]);
  add(
    'Liquidez corrente',
    'Ativo circulante ÷ passivo circulante',
    [current, liabilities],
    (v) => ratio(v[0], v[1]),
    unit: '×',
  );
  add(
    'Liquidez seca',
    '(Ativo circulante − estoques) ÷ passivo circulante',
    [current, inventory, liabilities],
    (v) => ratio(v[0] - v[1], v[2]),
    unit: '×',
  );
  add(
    'Liquidez imediata',
    'Caixa e equivalentes ÷ passivo circulante',
    [cash, liabilities],
    (v) => ratio(v[0], v[1]),
    unit: '×',
  );
  add(
    'Liquidez geral',
    '(Ativo circulante + realizável a longo prazo) ÷ (passivo circulante + passivo não circulante)',
    [current, input('Realizável a longo prazo'), liabilities, longLiabilities],
    (v) => ratio(v[0] + v[1], v[2] + v[3]),
    unit: '×',
  );
  add(
    'Endividamento geral',
    '(Passivo circulante + passivo não circulante) ÷ ativo total × 100',
    [liabilities, longLiabilities, assets],
    (v) => ratio(v[0] + v[1], v[2], 100),
    unit: '%',
  );
  add(
    'Capital de terceiros sobre patrimônio',
    '(Passivo circulante + passivo não circulante) ÷ patrimônio líquido',
    [liabilities, longLiabilities, equity],
    (v) => ratio(v[0] + v[1], v[2]),
    unit: '×',
  );
  add(
    'Composição do endividamento',
    'Passivo circulante ÷ passivo exigível total × 100',
    [liabilities, longLiabilities],
    (v) => ratio(v[0], v[0] + v[1], 100),
    unit: '%',
  );
  add('Dívida líquida', 'Dívida bruta − caixa e equivalentes', [
    debt,
    cash,
  ], (v) => v[0] - v[1]);
  add(
    'Dívida líquida / EBITDA do período',
    '(Dívida bruta − caixa e equivalentes) ÷ EBITDA do período',
    [debt, cash, ...ebitdaInputs],
    (v) => ratio(v[0] - v[1], data.ebitda ?? 0),
    unit: '×',
  );

  group = 'Giro e fluxo de caixa';
  final cogs = input('Custo dos produtos vendidos', [
    'custo das mercadorias vendidas',
    'cpv',
    'cmv',
  ]);
  add(
    'Giro de estoques',
    'Custo das vendas em magnitude ÷ estoque médio',
    [cogs, input('Estoque médio')],
    (v) => ratio(v[0].abs(), v[1]),
    unit: '×',
  );
  final flow = input('Fluxo de caixa operacional', [
    'caixa liquido das atividades operacionais',
  ]);
  add(
    'Fluxo de caixa livre simplificado',
    'Fluxo de caixa operacional − desembolsos de CAPEX',
    [flow, input('CAPEX desembolsado')],
    (v) => v[1] >= 0 ? v[0] - v[1] : null,
  );
  add(
    'Margem de caixa operacional',
    'Fluxo de caixa operacional ÷ receita líquida × 100',
    [flow, revenue],
    (v) => ratio(v[0], v[1], 100),
    unit: '%',
  );

  group = 'Microeconomia e custos';
  final fixed = input('Custos e despesas fixas', ['custos fixos totais']);
  final variable = input('Custos e despesas variáveis', [
    'custos variaveis totais',
  ]);
  final quantity = input('Quantidade vendida', ['unidades vendidas']);
  final price = input('Preço unitário');
  final unitCost = input('Custo variável unitário');
  final totalCost = input('Custo total');
  add('Receita total modelada', 'Preço unitário × quantidade vendida', [
    price,
    quantity,
  ], (v) => v.every((n) => n >= 0) ? v[0] * v[1] : null);
  add('Custo total modelado', 'Custos fixos + custos variáveis', [
    fixed,
    variable,
  ], (v) => v.every((n) => n >= 0) ? sum(v) : null);
  add(
    'Resultado econômico simplificado',
    'Receita líquida − custo total − custo de oportunidade',
    [revenue, totalCost, input('Custo de oportunidade')],
    (v) => v[1] >= 0 && v[2] >= 0 ? v[0] - v[1] - v[2] : null,
  );
  add('Custo médio por unidade vendida', 'Custo total ÷ quantidade vendida', [
    totalCost,
    quantity,
  ], (v) => v[0] >= 0 ? ratio(v[0], v[1]) : null);
  add(
    'Margem de contribuição',
    'Receita líquida − custos e despesas variáveis',
    [revenue, variable],
    (v) => v[1] >= 0 ? v[0] - v[1] : null,
  );
  add(
    'Margem de contribuição percentual',
    '(Receita líquida − custos variáveis) ÷ receita líquida × 100',
    [revenue, variable],
    (v) => v[1] >= 0 ? ratio(v[0] - v[1], v[0], 100) : null,
    unit: '%',
  );
  add('Contribuição unitária', 'Preço unitário − custo variável unitário', [
    price,
    unitCost,
  ], (v) => v.every((n) => n >= 0) ? v[0] - v[1] : null);
  add(
    'Ponto de equilíbrio em unidades',
    'Custos fixos ÷ contribuição unitária, arredondado para cima',
    [fixed, price, unitCost],
    (v) {
      if (v.any((n) => n < 0)) return null;
      return ratio(v[0], v[1] - v[2])?.ceilToDouble();
    },
    unit: 'un.',
  );
  add(
    'Ponto de equilíbrio em receita',
    'Custos fixos ÷ margem de contribuição em fração',
    [fixed, revenue, variable],
    (v) => v.every((n) => n >= 0) && v[1] > v[2]
        ? ratio(v[0], (v[1] - v[2]) / v[1])
        : null,
  );
  add(
    'Markup sobre custo',
    '(Preço unitário ÷ custo unitário − 1) × 100',
    [price, input('Custo unitário')],
    (v) => v[0] >= 0 && v[1] > 0 ? (v[0] / v[1] - 1) * 100 : null,
    unit: '%',
  );
  add(
    'Custo marginal entre volumes',
    'Variação do custo total ÷ variação da quantidade produzida',
    [
      input('Variação do custo total'),
      input('Variação da quantidade produzida'),
    ],
    (v) => v[1] == 0 ? null : v[0] / v[1],
  );
  add(
    'Receita marginal entre volumes',
    'Variação da receita total ÷ variação da quantidade vendida',
    [
      input('Variação da receita total'),
      input('Variação da quantidade vendida'),
    ],
    (v) => v[1] == 0 ? null : v[0] / v[1],
  );
  add(
    'Elasticidade-preço observada',
    'Variação relativa da quantidade ÷ variação relativa do preço pelo método do ponto médio',
    [
      input('Preço inicial'),
      input('Preço final'),
      input('Quantidade demandada inicial'),
      input('Quantidade demandada final'),
    ],
    (v) {
      if (v[0] <= 0 ||
          v[1] <= 0 ||
          v[2] < 0 ||
          v[3] < 0 ||
          v[0] == v[1] ||
          v[2] + v[3] == 0) {
        return null;
      }
      return ((v[3] - v[2]) / (v[2] + v[3])) / ((v[1] - v[0]) / (v[0] + v[1]));
    },
    unit: '×',
  );
  return metrics;
}
