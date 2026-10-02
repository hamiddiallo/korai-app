import '../design/labels.dart';
import '../domain/korai_enums.dart';

class ConsultationFormat {
  static String statusLabel(String status) => KLabels.consultationStatus(status);

  static String earSideLabel(EarSide earSide) => earSide.label;

  static String formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'Date inconnue';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return 'Date inconnue';

    final local = parsed.toLocal();
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day $month ${local.year} · $hour:$minute';
  }

  static String formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Date inconnue';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return 'Date inconnue';

    final local = parsed.toLocal();
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    return '$day $month ${local.year}';
  }

  /// Durée d'attente lisible : « 12 min », « 3 h », « 2 j ».
  static String formatWaiting(Duration? d) {
    if (d == null || d.isNegative) return '–';
    if (d.inMinutes < 1) return '< 1 min';
    if (d.inHours < 1) return '${d.inMinutes} min';
    if (d.inDays < 1) return '${d.inHours} h';
    return '${d.inDays} j';
  }
}
