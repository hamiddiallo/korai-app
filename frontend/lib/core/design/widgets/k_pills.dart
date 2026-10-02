import 'package:flutter/material.dart';

import '../../domain/korai_enums.dart';
import '../korai_tokens.dart';
import '../labels.dart';

/// Pastille de statut : toujours une icône ET un texte (jamais la couleur seule).
class KPill extends StatelessWidget {
  const KPill({
    super.key,
    required this.label,
    this.icon,
    this.tone = KTone.neutral,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final KTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.k.tone(tone);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(color: c.bg, borderRadius: KRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: c.fg),
            SizedBox(width: dense ? 4 : 5),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: (dense ? context.text.labelSmall : context.text.labelMedium)
                  ?.copyWith(color: c.fg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aides autour du niveau d'urgence (LOW / MEDIUM / HIGH).
class KUrgency {
  const KUrgency._();

  static UrgencyLevel? parse(Object? raw) {
    if (raw is UrgencyLevel) return raw;
    final s = raw?.toString().trim().toUpperCase();
    return switch (s) {
      'LOW' || 'FAIBLE' => UrgencyLevel.low,
      'MEDIUM' || 'MODERATE' || 'MODÉRÉE' || 'MODEREE' || 'MODÉRÉ' =>
        UrgencyLevel.medium,
      'HIGH' || 'ÉLEVÉE' || 'ELEVEE' || 'ÉLEVÉ' => UrgencyLevel.high,
      _ => null,
    };
  }

  static String label(UrgencyLevel? level) => switch (level) {
        UrgencyLevel.low => 'Faible',
        UrgencyLevel.medium => 'Modérée',
        UrgencyLevel.high => 'Élevée',
        null => 'Non évaluée',
      };

  static KTone tone(UrgencyLevel? level) => switch (level) {
        UrgencyLevel.low => KTone.success,
        UrgencyLevel.medium => KTone.warning,
        UrgencyLevel.high => KTone.danger,
        null => KTone.neutral,
      };

  static IconData icon(UrgencyLevel? level) => switch (level) {
        UrgencyLevel.low => Icons.keyboard_arrow_down_rounded,
        UrgencyLevel.medium => Icons.warning_amber_rounded,
        UrgencyLevel.high => Icons.keyboard_double_arrow_up_rounded,
        null => Icons.remove_rounded,
      };

  /// Rang de tri : élevée d'abord.
  static int rank(UrgencyLevel? level) => switch (level) {
        UrgencyLevel.high => 0,
        UrgencyLevel.medium => 1,
        UrgencyLevel.low => 2,
        null => 3,
      };

  static Color color(BuildContext context, UrgencyLevel? level) =>
      context.k.tone(tone(level)).accent;
}

/// « ! Modérée » — pastille d'urgence.
class KUrgencyPill extends StatelessWidget {
  const KUrgencyPill({super.key, required this.level, this.prefix, this.dense = false});

  final UrgencyLevel? level;
  final String? prefix;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final label = KUrgency.label(level);
    return Semantics(
      label: 'Urgence ${label.toLowerCase()}',
      child: KPill(
        label: prefix == null ? label : '$prefix ${label.toLowerCase()}',
        icon: KUrgency.icon(level),
        tone: KUrgency.tone(level),
        dense: dense,
      ),
    );
  }
}

/// Pastille de statut de consultation (Analyse à relancer, Avis reçu…).
class KConsultationStatusPill extends StatelessWidget {
  const KConsultationStatusPill({super.key, required this.status, this.dense = false});

  final String? status;
  final bool dense;

  @override
  Widget build(BuildContext context) => KPill(
        label: KLabels.consultationStatus(status),
        icon: KLabels.consultationStatusIcon(status),
        tone: KLabels.consultationStatusTone(status),
        dense: dense,
      );
}
