import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../design/design.dart';
import '../sync/sync_cubit.dart';

/// Pastille d'état de l'envoi des données.
///
/// Invisible quand tout est envoyé et en ligne. Sinon, l'onde dit l'essentiel :
/// plate en pointillés hors ligne, en mouvement pendant l'envoi.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

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
          duration: KMotion.of(context, KMotion.base),
          curve: KMotion.enter,
          alignment: Alignment.topCenter,
          child: config == null
              ? const SizedBox(width: double.infinity)
              : Padding(padding: margin, child: _BannerContent(config: config, state: state)),
        );
      },
    );
  }
}

class _BannerConfig {
  const _BannerConfig({
    required this.tone,
    required this.label,
    this.wave,
    this.icon,
    this.action,
  });

  final KTone tone;
  final String label;
  final KSyncWaveState? wave;
  final IconData? icon;
  final String? action;

  static _BannerConfig? from(SyncState state) {
    if (state.isOnline && !state.isSyncing && state.pendingCount == 0 && state.failedCount == 0) {
      return null;
    }
    if (state.isSyncing) {
      return const _BannerConfig(
        tone: KTone.brand,
        wave: KSyncWaveState.syncing,
        label: 'Envoi des données en cours…',
      );
    }
    if (!state.isOnline) {
      final n = state.pendingCount;
      return _BannerConfig(
        tone: KTone.neutral,
        wave: KSyncWaveState.offline,
        label: n > 0
            ? 'Hors ligne · $n ${n == 1 ? 'élément enregistré' : 'éléments enregistrés'} sur l’appareil'
            : 'Hors ligne · vos saisies restent sur l’appareil',
      );
    }
    if (state.failedCount > 0) {
      final n = state.failedCount;
      return _BannerConfig(
        tone: KTone.danger,
        icon: Icons.sync_problem_rounded,
        label: n == 1 ? '1 envoi a échoué' : '$n envois ont échoué',
        action: 'Réessayer',
      );
    }
    if (state.pendingCount > 0) {
      final n = state.pendingCount;
      return _BannerConfig(
        tone: KTone.info,
        icon: Icons.cloud_upload_outlined,
        label: n == 1 ? '1 élément en attente d’envoi' : '$n éléments en attente d’envoi',
        action: 'Envoyer',
      );
    }
    return null;
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({required this.config, required this.state});

  final _BannerConfig config;
  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SyncCubit>();
    final c = context.k.tone(config.tone);
    final canRetry = state.isOnline && !state.isSyncing;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        decoration: BoxDecoration(color: c.bg, borderRadius: KRadius.pillAll),
        child: Row(
          children: [
            if (config.wave != null)
              KSyncWave(state: config.wave!, color: c.accent)
            else
              Icon(config.icon, size: 18, color: c.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                config.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(color: c.fg),
              ),
            ),
            if (config.action != null)
              TextButton(
                onPressed: canRetry ? cubit.retryAll : null,
                style: TextButton.styleFrom(
                  foregroundColor: c.fg,
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(config.action!),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
