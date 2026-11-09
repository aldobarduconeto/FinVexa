import 'package:finvexa/models/analytics.dart';
import 'package:finvexa/models/export_snapshot.dart';

class DashboardChange {
  final String key, label;
  final double? base, focus;
  DashboardChange(this.key, this.label, this.base, this.focus);
  double? get delta => difference(base, focus);
  double? get percent => variation(base, focus);
  bool get missing => base == null || focus == null;
  bool get changed => missing || delta!.abs() >= .005;
}

List<DashboardChange> dashboardChanges(
  FinancialSeries base,
  FinancialSeries focus,
  Map<String, String> labels,
) {
  final previous = base.values, current = focus.values;
  final changes = {...previous.keys, ...current.keys}
      .map(
        (key) => DashboardChange(
          key,
          labels[key] ?? key,
          previous[key],
          current[key],
        ),
      )
      .toList();
  changes.sort((a, b) {
    if (a.missing != b.missing) return a.missing ? -1 : 1;
    final amount = (b.delta?.abs() ?? 0).compareTo(a.delta?.abs() ?? 0);
    return amount == 0 ? a.label.compareTo(b.label) : amount;
  });
  return changes;
}

String dashboardLabel(String label) {
  const months = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(label);
  if (match != null) {
    final month = int.parse(match[2]!);
    if (month >= 1 && month <= 12) return '${months[month - 1]} ${match[1]}';
  }
  final quarter = RegExp(r'^(\d{4})-T([1-4])$').firstMatch(label);
  if (quarter != null) return '${quarter[2]}º tri. ${quarter[1]}';
  return label;
}
