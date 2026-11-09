import 'package:finvexa/models/analytics.dart';

typedef AccountingInput = ({
  String label,
  LedgerEntry? entry,
  List<String> names,
});

class AccountingIndicators {
  AccountingIndicators(List<LedgerEntry> entries) : _entries = entries;
  final List<LedgerEntry> _entries;
  late final Map<String, List<LedgerEntry>> _byDescription = _indexEntries();

  Map<String, List<LedgerEntry>> _indexEntries() {
    final index = <String, List<LedgerEntry>>{};
    for (final entry in _entries) {
      index.putIfAbsent(normalized(entry.description), () => []).add(entry);
    }
    return index;
  }

  AccountingInput input(String label, List<String> names) {
    final matches = names.toSet().expand(
      (name) => _byDescription[name] ?? const [],
    );
    return (
      label: label,
      entry: matches.length == 1 ? matches.first : null,
      names: names,
    );
  }

  late final earnings = [
    input('Lucro líquido', [
      'lucro liquido',
      'lucro liquido do periodo',
      'resultado liquido do periodo',
    ]),
    input('Tributos sobre o lucro (despesa positiva, benefício negativo)', [
      'ajuste de tributos sobre o lucro',
      'despesa liquida de irpj e csll',
    ]),
    input('Despesa financeira líquida (despesa positiva, receita negativa)', [
      'despesa financeira liquida',
      'despesas financeiras liquidas',
    ]),
  ];

  late final depreciation = input(
    'Depreciação, amortização e exaustão (despesa positiva)',
    [
      'depreciacao amortizacao e exaustao',
      'depreciacao, amortizacao e exaustao',
      'depreciacao e amortizacao',
    ],
  );
  late final revenue = input('Receita líquida', [
    'receita liquida',
    'receita liquida de vendas',
  ]);
  late final investment = [
    input('Retorno líquido do investimento', [
      'retorno liquido do investimento',
      'ganho liquido do investimento',
    ]),
    input('Custo do investimento', [
      'custo do investimento',
      'investimento inicial',
    ]),
  ];

  double? _sum(List<AccountingInput> inputs) {
    if (inputs.any((input) => input.entry == null)) return null;
    return inputs.fold<double>(0, (sum, input) => sum + input.entry!.amount);
  }

  double? get ebit => _sum(earnings);
  double? get ebitda {
    if ((depreciation.entry?.amount ?? -1) < 0) return null;
    return _sum([...earnings, depreciation]);
  }

  double? get ebitdaMargin => _ratio(ebitda, revenue.entry?.amount);
  double? get roi =>
      _ratio(investment.first.entry?.amount, investment.last.entry?.amount);

  double? _ratio(double? numerator, double? denominator) {
    if (numerator == null || denominator == null || denominator <= 0) {
      return null;
    }
    return numerator / denominator * 100;
  }
}
