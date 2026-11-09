enum MonthlyReportFormat {
  json('JSON'),
  xlsx('Excel (.xlsx)'),
  csv('CSV'),
  tsv('TSV'),
  pdf('PDF');

  const MonthlyReportFormat(this.label);
  final String label;
}

class MonthlyReportLine {
  const MonthlyReportLine(this.description, this.amount, this.category);

  final String description, category;
  final double amount;
}

class MonthlyReport {
  MonthlyReport({
    this.title = 'Relatório mensal',
    required this.company,
    required this.period,
    required this.currency,
    required Iterable<MonthlyReportLine> lines,
  }) : lines = List.unmodifiable(lines);

  final String title, company, period, currency;
  final List<MonthlyReportLine> lines;
}
