import 'analytics.dart';

const fieldAliases = <String, List<String>>{
  'description': [
    'indicador',
    'descricao',
    'description',
    'historico',
    'lancamento',
    'nome',
    'conta contabil',
    'rubrica',
  ],
  'amount': ['valor', 'amount', 'value', 'saldo', 'total', 'montante'],
  'period': ['periodo', 'data', 'date', 'competencia', 'mes', 'ano'],
  'company': ['empresa', 'company', 'razao social'],
  'account': ['conta', 'account', 'banco'],
  'category': ['categoria', 'category', 'tipo', 'classificacao'],
  'currency': ['moeda', 'currency'],
};

class ImportTable {
  final String source;
  final List<String> headers;
  final List<List<dynamic>> rows;
  final List<int> sourceRows;
  final String? warning;
  ImportTable(
    this.source,
    this.headers,
    this.rows, {
    this.warning,
    List<int>? sourceRows,
  }) : sourceRows = sourceRows ?? List.generate(rows.length, (i) => i + 2);
  Map<String, int> autoMapping() => {
    for (final field in fieldAliases.keys)
      field: headers.indexWhere(
        (h) => fieldAliases[field]!.contains(normalized(h)),
      ),
  };
}

class ImportResult {
  final List<LedgerEntry> entries;
  final List<String> errors;
  ImportResult(this.entries, this.errors);
}
