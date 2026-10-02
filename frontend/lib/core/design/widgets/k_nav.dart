import 'package:flutter/material.dart';

import '../korai_tokens.dart';

class KNavItem {
  const KNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badge = 0,
    this.isAction = false,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int badge;

  /// Bouton d'action central (ex. « Nouvelle consultation »), pas un onglet.
  final bool isAction;
}

/// Barre de navigation flottante : chaque onglet a une icône ET un libellé,
/// l'onglet actif est une pilule pleine.
class KPillNavBar extends StatelessWidget {
  const KPillNavBar({super.key, required this.items, required this.currentIndex, required this.onTap});

  final List<KNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: k.surface,
            borderRadius: KRadius.pillAll,
            border: Border.all(color: k.line),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF062126).withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                items[i].isAction
                    ? _ActionItem(item: items[i], onTap: () => onTap(i))
                    : Expanded(
                        flex: i == currentIndex ? 6 : 4,
                        child: _NavItem(
                          item: items[i],
                          selected: i == currentIndex,
                          onTap: () => onTap(i),
                        ),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.item, required this.selected, required this.onTap});

  final KNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(selected ? (item.activeIcon ?? item.icon) : item.icon,
            size: 22, color: selected ? k.onBrand : k.inkMuted),
        if (item.badge > 0)
          Positioned(
            right: -7,
            top: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: k.danger,
                borderRadius: KRadius.pillAll,
                border: Border.all(color: selected ? k.brand : k.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                item.badge > 99 ? '99+' : '${item.badge}',
                style: TextStyle(color: Theme.of(context).colorScheme.onError, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
    return Semantics(
      button: true,
      selected: selected,
      label: item.badge > 0 ? '${item.label}, ${item.badge} en attente' : item.label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: KRadius.pillAll,
            onTap: onTap,
            child: AnimatedContainer(
              duration: KMotion.of(context, KMotion.base),
              curve: KMotion.enter,
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? k.brand : Colors.transparent,
                borderRadius: KRadius.pillAll,
              ),
              child: selected
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon,
                        const SizedBox(width: 6),
                        // Réduit légèrement le libellé plutôt que de le tronquer.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              style: context.text.labelMedium?.copyWith(color: k.onBrand, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon,
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            style: context.text.labelSmall?.copyWith(color: k.inkMuted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({required this.item, required this.onTap});

  final KNavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: item.label,
        child: Semantics(
          button: true,
          label: item.label,
          child: ExcludeSemantics(
            child: Material(
              color: k.hero,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(item.icon, color: k.onHero, size: 26),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class KSegment<T> {
  const KSegment({required this.value, required this.label, this.count});

  final T value;
  final String label;
  final int? count;
}

/// Contrôle segmenté avec curseur glissant (À traiter / En attente / Terminées).
class KSegmented<T> extends StatelessWidget {
  const KSegmented({super.key, required this.segments, required this.value, required this.onChanged});

  final List<KSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final index = segments.indexWhere((s) => s.value == value).clamp(0, segments.length - 1);
    final n = segments.length;
    final x = n == 1 ? 0.0 : -1 + 2 * index / (n - 1);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: k.surfaceAlt, borderRadius: KRadius.pillAll),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: Alignment(x, 0),
            duration: KMotion.of(context, KMotion.base),
            curve: KMotion.enter,
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: k.surface,
                  borderRadius: KRadius.pillAll,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF062126).withValues(alpha: 0.10), blurRadius: 6, offset: const Offset(0, 1)),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final s in segments)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: s.value == value,
                    label: s.count == null ? s.label : '${s.label}, ${s.count}',
                    child: ExcludeSemantics(
                      child: InkWell(
                        borderRadius: KRadius.pillAll,
                        onTap: () => onChanged(s.value),
                        child: Center(
                          child: Text(
                            s.count == null ? s.label : '${s.label} · ${s.count}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelMedium?.copyWith(
                              color: s.value == value ? k.ink : k.inkMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
