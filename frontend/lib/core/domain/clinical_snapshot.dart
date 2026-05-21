import '../../features/nurse/domain/clinical_reference_item.dart';

/// Construit les snapshots ID + libellé pour persistance backend.
class ClinicalSnapshot {
  static List<String> ids(Set<String> selected) => selected.toList();

  static List<String> labels(List<ClinicalReferenceItem> items, Set<String> selected) {
    return items.where((item) => selected.contains(item.id)).map((item) => item.label).toList();
  }
}
