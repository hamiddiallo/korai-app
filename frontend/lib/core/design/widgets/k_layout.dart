import 'package:flutter/material.dart';

import '../../domain/korai_enums.dart';
import '../korai_tokens.dart';
import '../labels.dart';

/// Titre d'écran sur deux niveaux : « Vos / Consultations ».
class KScreenHeader extends StatelessWidget {
  const KScreenHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing = const [],
    this.padding = const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.md, KSpace.gutter, KSpace.sm),
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final List<Widget> trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null)
                    Text(eyebrow!, style: context.text.bodyMedium?.copyWith(color: k.inkMuted)),
                  Text(title, style: context.text.headlineMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: context.text.bodyMedium?.copyWith(color: k.inkMuted)),
                  ],
                ],
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// Titre de section avec action optionnelle (« À traiter · Tout voir »).
class KSectionHeader extends StatelessWidget {
  const KSectionHeader({super.key, required this.title, this.actionLabel, this.onAction, this.count});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              count == null ? title : '$title · $count',
              style: context.text.titleLarge,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Carte de base : surface blanche, rayon 16, trait fin, toucher optionnel.
class KCard extends StatelessWidget {
  const KCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(KSpace.md),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Material(
      color: color ?? k.surface,
      shape: RoundedRectangleBorder(
        borderRadius: KRadius.cardAll,
        side: BorderSide(color: borderColor ?? k.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Avatar à initiales (pas de photo de patient : confidentialité).
class KInitialsAvatar extends StatelessWidget {
  const KInitialsAvatar({super.key, required this.name, this.size = 40, this.heroTag});

  final String name;
  final double size;
  final Object? heroTag;

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final avatar = ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: k.lagoon, shape: BoxShape.circle),
        child: Text(
          initialsOf(name),
          style: TextStyle(
            fontFamily: KFonts.body,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
            color: k.onLagoon,
          ),
        ),
      ),
    );
    if (heroTag == null) return avatar;
    return Hero(tag: heroTag!, child: avatar);
  }
}

/// Bloc de date « 26 JUIN ».
class KDateBlock extends StatelessWidget {
  const KDateBlock({super.key, required this.date, this.muted = false});

  final DateTime? date;
  final bool muted;

  static const _months = [
    'janv', 'févr', 'mars', 'avr', 'mai', 'juin',
    'juil', 'août', 'sept', 'oct', 'nov', 'déc',
  ];

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final d = date?.toLocal();
    final bg = muted ? k.surfaceAlt : k.hero;
    final fg = muted ? k.ink : k.onHero;
    final sub = muted ? k.inkMuted : k.onHeroMuted;
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            d == null ? '–' : '${d.day}',
            style: TextStyle(fontFamily: KFonts.display, fontWeight: FontWeight.w700, fontSize: 19, height: 1, color: fg),
          ),
          const SizedBox(height: 3),
          Text(
            d == null ? '' : _months[d.month - 1].toUpperCase(),
            style: TextStyle(fontFamily: KFonts.body, fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.6, color: sub),
          ),
        ],
      ),
    );
  }
}

/// « ○ droite » : oreille concernée, symbole de l'audiogramme.
class KEarTag extends StatelessWidget {
  const KEarTag({super.key, required this.side, this.long = false});

  final EarSide side;
  final bool long;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: side.label,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${KLabels.earMark(side)} ',
                style: const TextStyle(fontFamily: KFonts.mono, fontWeight: FontWeight.w700),
              ),
              TextSpan(text: long ? side.label : KLabels.earShort(side)),
            ],
          ),
          style: context.text.bodySmall,
        ),
      ),
    );
  }
}

/// Ligne « libellé : valeur » des récapitulatifs et fiches.
class KInfoRow extends StatelessWidget {
  const KInfoRow({super.key, required this.label, required this.value, this.valueColor, this.labelWidth = 118});

  final String label;
  final String value;
  final Color? valueColor;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: context.text.bodyMedium?.copyWith(color: k.inkMuted)),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Text(
              value,
              style: context.text.bodyMedium?.copyWith(
                color: valueColor ?? k.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloc d'auteur : ce que propose l'IA (filet aqua) ou ce qu'a validé un
/// spécialiste (filet encre). Le soignant sait toujours qui parle.
class KAuthorBlock extends StatelessWidget {
  const KAuthorBlock.ai({super.key, required this.child, this.title = 'Proposition de l’IA', this.trailing})
      : isAi = true;

  const KAuthorBlock.specialist({super.key, required this.child, this.title = 'Avis du spécialiste', this.trailing})
      : isAi = false;

  final bool isAi;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final rule = isAi ? k.aqua : k.ink;
    final head = isAi ? k.aquaInk : k.ink;
    return Container(
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(4),
          right: Radius.circular(KRadius.card),
        ),
        border: Border(left: BorderSide(color: rule, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.sm, KSpace.md, KSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isAi ? Icons.auto_awesome_rounded : Icons.verified_rounded, size: 16, color: head),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(color: head, letterSpacing: 0.7),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: KSpace.xs),
          child,
        ],
      ),
    );
  }
}
