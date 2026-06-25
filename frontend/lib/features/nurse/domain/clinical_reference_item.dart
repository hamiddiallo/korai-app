class ClinicalReferenceItem {
  const ClinicalReferenceItem({
    required this.id,
    required this.type,
    required this.label,
    required this.isActive,
    required this.sortOrder,
    this.description,
    this.dangerScore = 0,
  });

  final String id;
  final String type;
  final String label;
  final bool isActive;
  final int sortOrder;
  final String? description;

  /// Score de danger 0–3 (alimente le calcul d'urgence).
  final int dangerScore;

  factory ClinicalReferenceItem.fromJson(Map<String, dynamic> json) {
    return ClinicalReferenceItem(
      id: json['id'].toString(),
      type: json['type'].toString(),
      label: json['label'].toString(),
      description: json['description']?.toString(),
      isActive: json['isActive'] == true,
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      dangerScore: int.tryParse(json['dangerScore']?.toString() ?? '') ?? 0,
    );
  }
}
