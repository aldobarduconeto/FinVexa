import 'package:flutter/foundation.dart';

import '../models/analytics.dart';
import '../models/finance.dart';
import '../models/monthly_report.dart';
import '../services/monthly_report_service.dart';
import '../services/report_files.dart';

class MonthlyReportController {
  MonthlyReportController({
    required this.company,
    required this.period,
    required this.currency,
  });

  String company, period, currency;
  final fields = <String, String>{};

  Future<Uint8List> generate({
    required MonthlyReportFormat format,
    required String title,
    required Map<String, String> categoriesByField,
    required Iterable<({String name, String value, String category})> custom,
  }) {
    double amount(String description, String value) {
      try {
        return parseAmount(value);
      } on FormatException {
        throw FormatException('Valor inválido em "$description".');
      }
    }

    return encodeMonthlyReport(
      MonthlyReport(
        title: title,
        company: company,
        period: period,
        currency: currency,
        lines: [
          for (final field in fields.entries)
            if (field.value.trim().isNotEmpty)
              MonthlyReportLine(
                field.key,
                amount(field.key, field.value),
                categoriesByField[field.key]!,
              ),
          for (final row in custom)
            if (row.name.trim().isNotEmpty || row.value.trim().isNotEmpty)
              MonthlyReportLine(
                row.name,
                amount(row.name, row.value),
                row.category,
              ),
        ],
      ),
      format: format,
    );
  }

  Future<bool> save(
    Uint8List bytes,
    MonthlyReportFormat format,
    String templateId,
  ) => saveReportFile(
    title: 'Salvar relatório mensal',
    name: 'FinVexa-$templateId-${normalizePeriod(period)}.${format.name}',
    extension: format.name,
    bytes: bytes,
  );
}
