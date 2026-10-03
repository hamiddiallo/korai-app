import 'package:flutter/material.dart';

import '../design/design.dart';
import '../domain/korai_enums.dart';

/// Choix de l'oreille examinée, avec le symbole de l'audiogramme :
/// ○ oreille droite, × oreille gauche, ○× les deux.
class EarSideSelector extends StatelessWidget {
  const EarSideSelector({super.key, required this.value, required this.onChanged, this.allowBoth = false});

  final EarSide value;
  final ValueChanged<EarSide> onChanged;

  /// « Les deux » proposé : consultation du soignant, une photo par tympan.
  final bool allowBoth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(allowBoth ? 'Oreille(s) examinée(s)' : 'Oreille examinée', style: context.text.titleSmall),
        const SizedBox(height: KSpace.xs),
        Row(
          children: [
            Expanded(child: _EarTile(side: EarSide.right, selected: value == EarSide.right, onTap: onChanged)),
            const SizedBox(width: KSpace.sm),
            Expanded(child: _EarTile(side: EarSide.left, selected: value == EarSide.left, onTap: onChanged)),
            if (allowBoth) ...[
              const SizedBox(width: KSpace.sm),
              Expanded(child: _EarTile(side: EarSide.both, selected: value == EarSide.both, onTap: onChanged)),
            ],
          ],
        ),
        if (!allowBoth && value == EarSide.both)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Choisissez l’oreille photographiée.',
              style: context.text.bodySmall?.copyWith(color: context.k.warningInk),
            ),
          ),
      ],
    );
  }
}

class _EarTile extends StatelessWidget {
  const _EarTile({required this.side, required this.selected, required this.onTap});

  final EarSide side;
  final bool selected;
  final ValueChanged<EarSide> onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      button: true,
      selected: selected,
      label: side.label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? k.lagoon : k.surface,
          shape: RoundedRectangleBorder(
            borderRadius: KRadius.controlAll,
            side: BorderSide(color: selected ? k.brand : k.line, width: selected ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: KRadius.controlAll,
            onTap: () => onTap(side),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              // Trois choix sur un petit écran ou avec un grand texte : le contenu se réduit au
              // lieu de déborder ou d'être coupé.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      KLabels.earMark(side),
                      style: TextStyle(
                        fontFamily: KFonts.mono,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: selected ? k.brand : k.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      switch (side) {
                        EarSide.right => 'Droite',
                        EarSide.left => 'Gauche',
                        EarSide.both => 'Les deux',
                      },
                      style: context.text.labelLarge?.copyWith(color: selected ? k.onLagoon : k.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
