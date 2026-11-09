import 'analytics.dart';

class WorkspaceData {
  WorkspaceData({
    List<ReportDocument>? documents,
    Map<String, ReviewDecision>? decisions,
    List<ComparisonRecord>? history,
  }) : documents = documents ?? [],
       decisions = decisions ?? {},
       history = history ?? [];

  final List<ReportDocument> documents;
  final Map<String, ReviewDecision> decisions;
  final List<ComparisonRecord> history;

  factory WorkspaceData.fromJson(Map<String, dynamic> json) => WorkspaceData(
    documents: (json['documents'] as List)
        .map((item) => ReportDocument.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    decisions: (json['decisions'] as Map).map(
      (key, item) => MapEntry(
        key.toString(),
        ReviewDecision.fromJson(Map<String, dynamic>.from(item)),
      ),
    ),
    history: (json['history'] as List)
        .map(
          (item) => ComparisonRecord.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'documents': documents.map((item) => item.toJson()).toList(),
    'decisions': decisions.map((key, value) => MapEntry(key, value.toJson())),
    'history': history.map((item) => item.toJson()).toList(),
  };
}
