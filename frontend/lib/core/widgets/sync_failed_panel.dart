import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../design/design.dart';
import '../sync/sync_cubit.dart';

/// Détail des éléments dont l'envoi a échoué : réessai global ou élément par
/// élément. L'en-tête reste visible, la liste se déplie. Invisible sans échec.
class SyncFailedPanel extends StatefulWidget {
  const SyncFailedPanel({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

  @override
  State<SyncFailedPanel> createState() => _SyncFailedPanelState();
}

class _SyncFailedPanelState extends State<SyncFailedPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncState>(
      buildWhen: (prev, next) =>
          prev.failedCount != next.failedCount ||
          prev.failedItems != next.failedItems ||
          prev.isOnline != next.isOnline ||
          prev.isSyncing != next.isSyncing,
      builder: (context, state) {
        if (state.failedCount == 0) return const SizedBox.shrink();
        final k = context.k;
        final cubit = context.read<SyncCubit>();
        final canRetry = state.isOnline && !state.isSyncing;
        final n = state.failedCount;

        return Padding(
          padding: widget.margin,
          child: Container(
            decoration: BoxDecoration(
              color: k.surface,
              borderRadius: KRadius.cardAll,
              border: Border.all(color: k.danger.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  expanded: _expanded,
                  label: _expanded ? 'Masquer le détail des envois échoués' : 'Voir le détail des envois échoués',
                  child: InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: KRadius.cardAll,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.sm, KSpace.xs, KSpace.sm),
                      child: Row(
                        children: [
                          Icon(Icons.sync_problem_rounded, size: 22, color: k.danger),
                          const SizedBox(width: KSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n == 1 ? '1 élément non envoyé' : '$n éléments non envoyés',
                                  style: context.text.titleSmall?.copyWith(color: k.dangerInk),
                                ),
                                Text(
                                  state.isOnline
                                      ? 'Ils restent enregistrés sur l’appareil.'
                                      : 'Hors ligne : réessai possible au retour du réseau.',
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: canRetry ? cubit.retryAll : null,
                            style: TextButton.styleFrom(foregroundColor: k.dangerInk, minimumSize: const Size(44, 40)),
                            child: state.isSyncing
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: k.danger),
                                  )
                                : const Text('Tout réessayer'),
                          ),
                          Icon(
                            _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: k.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  duration: KMotion.of(context, KMotion.base),
                  crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Column(
                    children: [
                      Divider(height: 1, color: k.line),
                      for (final item in state.failedItems)
                        _FailedItemRow(
                          item: item,
                          canRetry: canRetry,
                          onRetry: () => cubit.retryItem(item.localId),
                        ),
                      const SizedBox(height: KSpace.xs),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FailedItemRow extends StatelessWidget {
  const _FailedItemRow({required this.item, required this.canRetry, required this.onRetry});

  final FailedSyncItem item;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.xs, KSpace.xxs, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                Text(item.subtitle, style: context.text.bodySmall),
                if (item.error != null && item.error!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.error!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: k.dangerInk),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: canRetry ? onRetry : null,
            icon: const Icon(Icons.refresh_rounded),
            color: k.danger,
            tooltip: 'Réessayer cet envoi',
          ),
        ],
      ),
    );
  }
}
