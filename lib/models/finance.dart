String money(num n) {
  final parts = n.abs().toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return '${n < 0 ? '-' : ''}R\$ $whole,${parts[1]}';
}

double parseAmount(dynamic value) {
  if (value is num && value.isFinite) return value.toDouble();
  var s = value
      .toString()
      .trim()
      .replaceAll('R\$', '')
      .replaceAll(RegExp(r'\s'), '');
  final negative = s.startsWith('(') && s.endsWith(')');
  if (negative) s = s.substring(1, s.length - 1);
  if (s.contains(',')) s = s.replaceAll('.', '').replaceAll(',', '.');
  final number = double.tryParse(s);
  if (number == null || !number.isFinite) {
    throw FormatException('Valor inválido: $value');
  }
  return negative ? -number : number;
}

class FinancialReport {
  final String name;
  final String period;
  final Map<String, double> values;
  FinancialReport(this.name, this.period, this.values);
  Map<String, dynamic> toJson() => {
    'name': name,
    'period': period,
    'values': values,
  };
  factory FinancialReport.fromJson(Map<String, dynamic> data) =>
      FinancialReport(
        data['name'] as String,
        data['period'] as String,
        (data['values'] as Map).map(
          (k, v) => MapEntry(k.toString(), parseAmount(v)),
        ),
      );
}

String normalizeCurrency(String value) {
  final s = value.trim().toUpperCase();
  if (s == 'R\$' || s == 'REAL' || s == 'REAIS' || s == 'BRL') return 'BRL';
  if (s == 'US\$' || s == 'USD') return 'USD';
  if (s == '€' || s == 'EUR') return 'EUR';
  if (RegExp(r'^[A-Z]{3}$').hasMatch(s)) return s;
  throw FormatException('Moeda não reconhecida: $value');
}
