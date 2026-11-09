import 'package:flutter/material.dart';

class AppPreferences {
  final String theme,
      accent,
      company,
      responsible,
      email,
      currency,
      decimal,
      grouping,
      chart,
      exportTitle;
  final bool compact,
      collapsedSidebar,
      suggestCategories,
      auditDuplicates,
      auditClassification,
      auditDivergence,
      auditOutliers,
      exportCharts,
      exportTable,
      exportEntries,
      exportAudit,
      exportHistory;
  final int pageSize, importLimitMb, startPage;
  final double outlierMultiplier;
  const AppPreferences({
    this.theme = 'system',
    this.accent = 'blue',
    this.company = 'Minha empresa',
    this.responsible = '',
    this.email = '',
    this.currency = 'BRL',
    this.decimal = 'auto',
    this.grouping = 'Mês',
    this.chart = 'bar',
    this.exportTitle = 'Relatório comparativo FinVexa',
    this.compact = false,
    this.collapsedSidebar = false,
    this.suggestCategories = true,
    this.auditDuplicates = true,
    this.auditClassification = true,
    this.auditDivergence = true,
    this.auditOutliers = true,
    this.exportCharts = true,
    this.exportTable = true,
    this.exportEntries = true,
    this.exportAudit = true,
    this.exportHistory = true,
    this.pageSize = 20,
    this.importLimitMb = 20,
    this.startPage = 0,
    this.outlierMultiplier = 3,
  });
  ThemeMode get themeMode => theme == 'dark'
      ? ThemeMode.dark
      : theme == 'light'
      ? ThemeMode.light
      : ThemeMode.system;
  Color get accentColor => accent == 'teal'
      ? const Color(0xff0f8a78)
      : accent == 'indigo'
      ? const Color(0xff7161d8)
      : const Color(0xff3478f6);
  Map<String, dynamic> toJson() => {
    'theme': theme,
    'accent': accent,
    'company': company,
    'responsible': responsible,
    'email': email,
    'currency': currency,
    'decimal': decimal,
    'grouping': grouping,
    'chart': chart,
    'exportTitle': exportTitle,
    'compact': compact,
    'collapsedSidebar': collapsedSidebar,
    'suggestCategories': suggestCategories,
    'auditDuplicates': auditDuplicates,
    'auditClassification': auditClassification,
    'auditDivergence': auditDivergence,
    'auditOutliers': auditOutliers,
    'exportCharts': exportCharts,
    'exportTable': exportTable,
    'exportEntries': exportEntries,
    'exportAudit': exportAudit,
    'exportHistory': exportHistory,
    'pageSize': pageSize,
    'importLimitMb': importLimitMb,
    'startPage': startPage,
    'outlierMultiplier': outlierMultiplier,
  };
  factory AppPreferences.fromJson(Map<String, dynamic> j) {
    String option(String key, List<String> values, String fallback) =>
        values.contains(j[key]) ? j[key] as String : fallback;
    String text(String key, String fallback) =>
        j[key] is String ? (j[key] as String).trim() : fallback;
    bool flag(String key, bool fallback) =>
        j[key] is bool ? j[key] as bool : fallback;
    return AppPreferences(
      theme: option('theme', ['light', 'dark', 'system'], 'system'),
      accent: option('accent', ['blue', 'teal', 'indigo'], 'blue'),
      company: text('company', 'Minha empresa').isEmpty
          ? 'Minha empresa'
          : text('company', 'Minha empresa'),
      responsible: text('responsible', ''),
      email: text('email', ''),
      currency: option('currency', ['BRL', 'USD', 'EUR'], 'BRL'),
      decimal: option('decimal', ['auto', 'virgula', 'ponto'], 'auto'),
      grouping: option('grouping', [
        'Documento',
        'Mês',
        'Trimestre',
        'Ano',
        'Empresa',
      ], 'Mês'),
      chart: option('chart', ['bar', 'line'], 'bar'),
      exportTitle: text('exportTitle', 'Relatório comparativo FinVexa'),
      compact: flag('compact', false),
      collapsedSidebar: flag('collapsedSidebar', false),
      suggestCategories: flag('suggestCategories', true),
      auditDuplicates: flag('auditDuplicates', true),
      auditClassification: flag('auditClassification', true),
      auditDivergence: flag('auditDivergence', true),
      auditOutliers: flag('auditOutliers', true),
      exportCharts: flag('exportCharts', true),
      exportTable: flag('exportTable', true),
      exportEntries: flag('exportEntries', true),
      exportAudit: flag('exportAudit', true),
      exportHistory: flag('exportHistory', true),
      pageSize: [10, 20, 50, 100].contains(j['pageSize'])
          ? j['pageSize'] as int
          : 20,
      importLimitMb: [5, 10, 20].contains(j['importLimitMb'])
          ? j['importLimitMb'] as int
          : 20,
      startPage: [0, 1, 2, 3, 4, 5].contains(j['startPage'])
          ? j['startPage'] as int
          : 0,
      outlierMultiplier: [2.0, 3.0, 5.0, 10.0].contains(j['outlierMultiplier'])
          ? (j['outlierMultiplier'] as num).toDouble()
          : 3,
    );
  }
  AppPreferences changed(Map<String, dynamic> patch) =>
      AppPreferences.fromJson({...toJson(), ...patch});
}
