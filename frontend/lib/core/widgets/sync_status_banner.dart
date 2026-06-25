import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../sync/sync_cubit.dart';

/// Bandeau discret d'état de synchronisation.
///
/// Se rend invisible quand tout est synchronisé et en ligne.
/// Affiche sinon un indicateur coloré adapté au contexte :
///   - Hors ligne (ambre)
///   - Éléments en échec (rouge)
///   - Synchronisation en cours (teal)
///   - Éléments en attente (bleu-gris)
///
/// Le bouton « Réessayer maintenant » appelle [SyncCubit.synchronizeNow].
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncState>(
      buildWhen: (prev, next) =>
          prev.isOnline != next.isOnline ||
          prev.isSyncing != next.isSyncing ||
          prev.pendingCount != next.pendingCount ||
          prev.failedCount != next.failedCount ||
          prev.lastSyncedAt != next.lastSyncedAt,
      builder: (context, state) {
        final config = _BannerConfig.from(state);

        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: config == null
              ? const SizedBox.shrink()
              : _BannerContent(config: config, state: state),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Configuration du bandeau selon l'état
// ---------------------------------------------------------------------------

class _BannerConfig {
  const _BannerConfig({
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
    required this.label,
    this.showSpinner = false,
  });

  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;
  final String label;
  final bool showSpinner;

  /// Retourne null quand tout est OK (bandeau invisible).
  static _BannerConfig? from(SyncState state) {
    // Tout va bien : rien à afficher
    if (state.isOnline &&
        !state.isSyncing &&
        state.pendingCount == 0 &&
        state.failedCount == 0) {
      return null;
    }

    // Synchronisation en cours
    if (state.isSyncing) {
      return const _BannerConfig(
        backgroundColor: Color(0xFFE6F4F1),
        borderColor: Color(0xFF006D77),
        icon: Icons.sync,
        label: 'Synchronisation en cours…',
        showSpinner: true,
      );
    }

    // Hors ligne
    if (!state.isOnline) {
      final count = state.pendingCount;
      final suffix = count > 0 ? ' ($count en attente)' : '';
      return _BannerConfig(
        backgroundColor: const Color(0xFFFEF3C7),
        borderColor: const Color(0xFFF59E0B),
        icon: Icons.wifi_off_rounded,
        label: 'Hors ligne – synchronisation en attente$suffix',
      );
    }

    // Éléments en échec permanent
    if (state.failedCount > 0) {
      final n = state.failedCount;
      return _BannerConfig(
        backgroundColor: const Color(0xFFFEE2E2),
        borderColor: const Color(0xFFEF4444),
        icon: Icons.sync_problem_rounded,
        label: '$n ${n == 1 ? 'élément a' : 'éléments ont'} échoué'
            '${_syncedSuffix(state)}',
      );
    }

    // En ligne mais des éléments en attente (ex: juste reconnecté)
    if (state.pendingCount > 0) {
      final n = state.pendingCount;
      return _BannerConfig(
        backgroundColor: const Color(0xFFEFF6FF),
        borderColor: const Color(0xFF60A5FA),
        icon: Icons.cloud_upload_outlined,
        label: '$n ${n == 1 ? 'élément en' : 'éléments en'} attente d\'envoi'
            '${_syncedSuffix(state)}',
      );
    }

    return null;
  }

  /// Suffixe « · synchro HH:MM » rappelant la dernière synchro réussie.
  static String _syncedSuffix(SyncState state) {
    final at = state.lastSyncedAt;
    if (at == null) return '';
    final local = at.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return ' · synchro $hh:$mm';
  }
}

// ---------------------------------------------------------------------------
// Contenu visuel du bandeau
// ---------------------------------------------------------------------------

class _BannerContent extends StatelessWidget {
  const _BannerContent({
    required this.config,
    required this.state,
  });

  final _BannerConfig config;
  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SyncCubit>();
    final canRetry = state.isOnline && !state.isSyncing;

    // Pas d'AnimatedSwitcher ici : ses clés (ValueKey sur le libellé) peuvent
    // se répéter et provoquer un crash « Duplicate keys » pendant une
    // transition. L'AnimatedSize parent suffit pour l'apparition/disparition.
    return Container(
      key: ValueKey(config.label),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: config.borderColor.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icône / spinner
          config.showSpinner
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: config.borderColor,
                  ),
                )
              : Icon(config.icon, size: 16, color: config.borderColor),

          const SizedBox(width: 8),

          // Message
          Expanded(
            child: Text(
              config.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: config.borderColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Bouton Réessayer (masqué pendant la sync ou si pas de retry utile)
          if (!config.showSpinner &&
              (state.failedCount > 0 || state.pendingCount > 0)) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: canRetry ? cubit.retryAll : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: canRetry
                      ? config.borderColor
                      : config.borderColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Réessayer',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: canRetry
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
