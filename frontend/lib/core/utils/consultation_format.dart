class ConsultationFormat {
  static String statusLabel(String status) {
    return switch (status) {
      'DRAFT' => 'Brouillon',
      'PENDING_AI' => 'IA en cours',
      'AI_COMPLETED' => 'Diagnostic IA terminé',
      'PENDING_SPECIALIST_REVIEW' => 'En attente ORL',
      'SPECIALIST_COMPLETED' => 'Avis spécialiste reçu',
      _ => status,
    };
  }

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
}
