import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../sync/sync_cubit.dart';

/// Panneau détaillé des éléments dont la synchronisation a échoué de façon
/// définitive. L'en-tête (compteur + « Tout réessayer ») reste visible ; les
/// détails (liste avec réessai individuel) sont repliables. Invisible tant
/// qu'il n'y a aucun échec.
class SyncFailedPanel extends StatefulWidget {
  const SyncFailedPanel({super.key});

  @override
  State<SyncFailedPanel> createState() => _SyncFailedPanelState();
}

class _SyncFailedPanelState extends State<SyncFailedPanel> {
  static const _red = Color(0xFFEF4444);
  static const _redDark = Color(0xFFB91C1C);

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncState>(
      buildWhen: (prev, next) =>
          prev.failedCount != next.failedCount ||
          prev.isOnline != next.isOnline ||
          prev.isSyncing != next.isSyncing,
      builder: (context, state) {
        if (state.failedCount == 0) return const SizedBox.shrink();

        final cubit = context.read<SyncCubit>();
        final canRetry = state.isOnline && !state.isSyncing;
        final n = state.failedCount;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _red.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête repliable + action « Tout réessayer »
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.sync_problem_rounded,
                          size: 20, color: _redDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$n ${n == 1 ? 'élément non synchronisé' : 'éléments non synchronisés'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: _redDark,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: canRetry ? cubit.retryAll : null,
                        icon: state.isSyncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _redDark),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Tout réessayer'),
                        style: TextButton.styleFrom(
                          foregroundColor: _redDark,
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ),
                      // Chevron afficher/masquer les détails
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: _redDark,
                      ),
                    ],
                  ),
                ),
              ),

              // Détails repliables
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!state.isOnline)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: Text(
                          'Hors ligne — le réessai sera possible au retour du réseau.',
                          style: TextStyle(fontSize: 11.5, color: _redDark),
                        ),
                      ),
                    const Divider(height: 1, color: Color(0x33EF4444)),
                    ...state.failedItems.map(
                      (item) => _FailedItemRow(
                        item: item,
                        canRetry: canRetry,
                        onRetry: () => cubit.retryItem(item.localId),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FailedItemRow extends StatelessWidget {
  const _FailedItemRow({
    required this.item,
    required this.canRetry,
    required this.onRetry,
  });

  final FailedSyncItem item;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                ),
                if (item.error != null && item.error!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.error!,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: canRetry ? onRetry : null,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: _SyncFailedPanelState._redDark,
            tooltip: 'Réessayer',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
