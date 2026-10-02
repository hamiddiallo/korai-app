import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../core/utils/patient_age.dart';
import '../../../../core/widgets/sync_failed_panel.dart';
import '../../../../core/widgets/sync_status_banner.dart';
import '../../domain/patient.dart';
import '../nurse_actions.dart';
import '../nurse_workspace.dart';
import '../widgets/consultation_card.dart';

/// Accueil « Aujourd'hui » du soignant : ce qui attend une action d'abord.
class NurseTodayTab extends StatelessWidget {
  const NurseTodayTab({
    super.key,
    required this.workspace,
    required this.actions,
    required this.userName,
    required this.onNotificationTap,
    required this.pinnedNotificationHeader,
  });

  final NurseWorkspace workspace;
  final NurseActions actions;
  final String userName;
  final NotificationTapCallback onNotificationTap;
  final WidgetBuilder pinnedNotificationHeader;

  String get _firstName {
    final parts = userName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'Bienvenue' : parts.first;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: workspace,
      builder: (context, _) {
        final queue = workspace.todayQueue;
        final pending = workspace.pendingValidation;
        final recent = workspace.patientsByRecency.take(10).toList();
        return RefreshIndicator(
          onRefresh: workspace.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.md, KSpace.gutter, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bonjour,', style: context.text.bodyLarge?.copyWith(color: context.k.inkMuted)),
                          Text(_firstName, style: context.text.headlineLarge),
                        ],
                      ),
                    ),
                  ),
                  NotificationBell(
                    filled: true,
                    onTapNotification: onNotificationTap,
                    pinnedHeader: pinnedNotificationHeader,
                  ),
                  const SizedBox(width: KSpace.xs),
                  Tooltip(
                    message: 'Mon profil',
                    child: Semantics(
                      button: true,
                      label: 'Mon profil',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: actions.openProfile,
                        child: KInitialsAvatar(name: userName, size: 46),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KSpace.md),
              const SyncStatusBanner(margin: EdgeInsets.only(bottom: KSpace.sm)),
              const SyncFailedPanel(margin: EdgeInsets.only(bottom: KSpace.sm)),
              _HeroCard(
                onSearch: () => actions.goToTab(NurseTab.patients, focusSearch: true),
                onNewPatient: () => actions.startConsultation(),
              ),
              const SizedBox(height: KSpace.lg),
              if (!workspace.loadedOnce && workspace.loading)
                const KSkeletonList(count: 3, padding: EdgeInsets.zero)
              else if (!workspace.loadedOnce && workspace.error != null)
                KErrorView(error: workspace.error!, onRetry: workspace.refresh, compact: true)
              else ...[
                if (workspace.error != null) ...[
                  KBanner(
                    tone: KTone.warning,
                    title: 'Données peut-être incomplètes',
                    message: friendlyError(workspace.error!),
                    actionLabel: 'Réessayer',
                    onAction: workspace.refresh,
                  ),
                  const SizedBox(height: KSpace.md),
                ],
                KSectionHeader(
                  title: 'À traiter',
                  count: queue.isEmpty ? null : queue.length,
                  actionLabel: queue.isEmpty ? null : 'Tout voir',
                  onAction: () => actions.goToTab(NurseTab.history),
                ),
                const SizedBox(height: KSpace.xs),
                if (queue.isEmpty)
                  KCard(
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: context.k.success, size: 28),
                        const SizedBox(width: KSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rien à traiter pour l’instant', style: context.text.titleSmall),
                              Text(
                                'Les analyses à relancer et les avis de spécialistes apparaîtront ici.',
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final c in queue.take(5)) ...[
                    ConsultationCard(
                      consultation: c,
                      patientName: workspace.patientNameFor(c),
                      onTap: () => actions.openConsultation(c),
                    ),
                    const SizedBox(height: KSpace.xs),
                  ],
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: KSpace.lg),
                  KSectionHeader(title: 'Comptes patients à valider', count: pending.length),
                  const SizedBox(height: KSpace.xs),
                  for (final p in pending) ...[
                    _PendingPatientCard(patient: p, onTap: () => actions.reviewPendingPatient(p)),
                    const SizedBox(height: KSpace.xs),
                  ],
                ],
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: KSpace.lg),
                  KSectionHeader(
                    title: 'Patients récents',
                    actionLabel: 'Tout voir',
                    onAction: () => actions.goToTab(NurseTab.patients),
                  ),
                  const SizedBox(height: KSpace.xs),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recent.length,
                      separatorBuilder: (_, __) => const SizedBox(width: KSpace.sm),
                      itemBuilder: (_, i) => _RecentPatient(patient: recent[i], onTap: () => actions.openPatient(recent[i])),
                    ),
                  ),
                ],
                const SizedBox(height: KSpace.lg),
                const _ClinicalTip(),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onSearch, required this.onNewPatient});

  final VoidCallback onSearch;
  final VoidCallback onNewPatient;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(color: k.hero, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nouvelle consultation', style: context.text.headlineSmall?.copyWith(color: k.onHero)),
          const SizedBox(height: 2),
          Text('Retrouvez le patient ou créez son dossier.', style: context.text.bodyMedium?.copyWith(color: k.onHeroMuted)),
          const SizedBox(height: KSpace.md),
          Semantics(
            button: true,
            label: 'Rechercher un patient',
            child: Material(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: KRadius.controlAll,
              child: InkWell(
                borderRadius: KRadius.controlAll,
                onTap: onSearch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: k.onHeroMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Rechercher un patient (nom, téléphone)',
                          style: context.text.bodyMedium?.copyWith(color: k.onHeroMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: KSpace.sm),
          FilledButton.icon(
            onPressed: onNewPatient,
            style: FilledButton.styleFrom(backgroundColor: k.onHero, foregroundColor: k.hero),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Nouveau patient'),
          ),
        ],
      ),
    );
  }
}

class _PendingPatientCard extends StatelessWidget {
  const _PendingPatientCard({required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(KSpace.sm),
      child: Row(
        children: [
          KInitialsAvatar(name: patient.fullName),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.fullName, style: context.text.titleSmall),
                Text('A créé son compte · ${patient.phone ?? 'sans téléphone'}', style: context.text.bodySmall),
              ],
            ),
          ),
          const KPill(label: 'À valider', icon: Icons.fact_check_outlined, tone: KTone.warning, dense: true),
        ],
      ),
    );
  }
}

class _RecentPatient extends StatelessWidget {
  const _RecentPatient({required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Dossier de ${patient.fullName}',
      child: InkWell(
        borderRadius: KRadius.cardAll,
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              KInitialsAvatar(name: patient.fullName, size: 52, heroTag: 'patient-${patient.id}'),
              const SizedBox(height: 6),
              Text(
                patient.firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium,
              ),
              Text(
                PatientAge.years(patient.birthDate) == null ? '' : PatientAge.label(patient.birthDate),
                style: context.text.labelSmall?.copyWith(color: context.k.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rappel clinique du jour (remplace les cartes de présentation de l'app).
class _ClinicalTip extends StatelessWidget {
  const _ClinicalTip();

  static const _tips = [
    'Recherchez le signe du tragus avant la photo : une douleur à la pression oriente vers une otite externe.',
    'Une photo nette et bien éclairée du tympan améliore l’analyse : stabilisez l’otoscope et évitez le flou.',
    'Fièvre, douleur derrière l’oreille et pavillon décollé : pensez à la mastoïdite et demandez un avis rapidement.',
    'Otite douloureuse qui traîne chez une personne âgée diabétique : c’est un signe d’alerte, demandez un avis.',
  ];

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final tip = _tips[DateTime.now().day % _tips.length];
    return Container(
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(color: k.lagoon, borderRadius: KRadius.cardAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: k.onLagoon),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rappel clinique', style: context.text.titleSmall?.copyWith(color: k.onLagoon)),
                const SizedBox(height: 2),
                Text(tip, style: context.text.bodyMedium?.copyWith(color: k.onLagoon)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
