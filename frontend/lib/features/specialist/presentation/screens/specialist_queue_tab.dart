import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/korai_enums.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../core/utils/consultation_format.dart';
import '../../data/specialist_repository.dart';
import '../specialist_inbox.dart';
import '../widgets/inbox_card.dart';

enum _UrgencyFilter { all, high, medium, low }

/// File d'expertise : chiffres du jour, filtre par urgence, demandes triées
/// de la plus urgente à la moins urgente.
class SpecialistQueueTab extends StatefulWidget {
  const SpecialistQueueTab({
    super.key,
    required this.inbox,
    required this.userName,
    required this.onOpen,
    required this.onNotificationTap,
  });

  final SpecialistInbox inbox;
  final String userName;
  final void Function(ExpertiseInboxItem item) onOpen;
  final NotificationTapCallback onNotificationTap;

  @override
  State<SpecialistQueueTab> createState() => _SpecialistQueueTabState();
}

class _SpecialistQueueTabState extends State<SpecialistQueueTab> {
  _UrgencyFilter _filter = _UrgencyFilter.all;

  String get _doctorName {
    final parts = widget.userName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'Docteur' : 'Dr ${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    final inbox = widget.inbox;
    return ListenableBuilder(
      listenable: inbox,
      builder: (context, _) {
        final queue = inbox.queue;
        List<ExpertiseInboxItem> by(UrgencyLevel? u) => queue.where((i) => i.urgency == u).toList();
        final list = switch (_filter) {
          _UrgencyFilter.all => queue,
          _UrgencyFilter.high => by(UrgencyLevel.high),
          _UrgencyFilter.medium => by(UrgencyLevel.medium),
          _UrgencyFilter.low => queue.where((i) => i.urgency == UrgencyLevel.low || i.urgency == null).toList(),
        };
        final colleagues = inbox.items.where(inbox.isTakenByColleague).length;

        return RefreshIndicator(
          onRefresh: inbox.refresh,
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
                          Text('Expertise ORL', style: context.text.bodyLarge?.copyWith(color: context.k.inkMuted)),
                          Text(_doctorName, style: context.text.headlineLarge),
                        ],
                      ),
                    ),
                  ),
                  NotificationBell(filled: true, onTapNotification: widget.onNotificationTap),
                ],
              ),
              const SizedBox(height: KSpace.md),
              if (!inbox.loadedOnce && inbox.loading)
                const KSkeletonList(count: 3, itemHeight: 120, padding: EdgeInsets.zero)
              else if (!inbox.loadedOnce && inbox.error != null)
                KErrorView(
                  title: 'La file n’a pas pu être chargée',
                  error: inbox.error!,
                  onRetry: inbox.refresh,
                )
              else ...[
                if (inbox.error != null) ...[
                  KBanner(
                    tone: KTone.warning,
                    title: 'File peut-être incomplète',
                    message: friendlyError(inbox.error!),
                    actionLabel: 'Réessayer',
                    onAction: inbox.refresh,
                  ),
                  const SizedBox(height: KSpace.md),
                ],
                _Stats(
                  urgent: inbox.urgentCount,
                  toTake: inbox.toTakeCount,
                  averageWaiting: inbox.averageWaiting,
                ),
                const SizedBox(height: KSpace.lg),
                KSectionHeader(title: 'Demandes d’avis', count: queue.isEmpty ? null : queue.length),
                const SizedBox(height: KSpace.xs),
                if (queue.isNotEmpty) ...[
                  KSegmented<_UrgencyFilter>(
                    segments: [
                      const KSegment(value: _UrgencyFilter.all, label: 'Toutes'),
                      KSegment(value: _UrgencyFilter.high, label: 'Élevée', count: by(UrgencyLevel.high).length),
                      KSegment(value: _UrgencyFilter.medium, label: 'Modérée', count: by(UrgencyLevel.medium).length),
                      const KSegment(value: _UrgencyFilter.low, label: 'Faible'),
                    ],
                    value: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                  const SizedBox(height: KSpace.sm),
                ],
                if (queue.isEmpty)
                  KEmptyView(
                    icon: Icons.inbox_outlined,
                    title: 'Aucune demande d’avis',
                    message: colleagues > 0
                        ? 'Les $colleagues dossier${colleagues > 1 ? 's' : ''} en cours sont déjà pris en charge par vos confrères.'
                        : 'Les demandes des soignants apparaîtront ici, les plus urgentes en premier.',
                    actionLabel: 'Actualiser',
                    onAction: inbox.refresh,
                    compact: true,
                  )
                else if (list.isEmpty)
                  const KEmptyView(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Aucune demande à ce niveau d’urgence',
                    message: 'Choisissez « Toutes » pour revoir l’ensemble de la file.',
                    compact: true,
                  )
                else
                  for (final item in list) ...[
                    InboxCard(
                      item: item,
                      isMine: inbox.isMine(item),
                      takenByColleague: inbox.isTakenByColleague(item),
                      onTap: () => widget.onOpen(item),
                    ),
                    const SizedBox(height: KSpace.sm),
                  ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.urgent, required this.toTake, required this.averageWaiting});

  final int urgent;
  final int toTake;
  final Duration? averageWaiting;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Row(
      children: [
        Expanded(
          child: _Stat(
            value: '$urgent',
            label: urgent > 1 ? 'urgentes' : 'urgente',
            icon: Icons.priority_high_rounded,
            color: urgent > 0 ? k.danger : null,
          ),
        ),
        const SizedBox(width: KSpace.xs),
        Expanded(child: _Stat(value: '$toTake', label: 'à prendre', icon: Icons.inbox_outlined)),
        const SizedBox(width: KSpace.xs),
        Expanded(
          child: _Stat(
            value: ConsultationFormat.formatWaiting(averageWaiting),
            label: 'attente moy.',
            icon: Icons.schedule_rounded,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon, this.color});

  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      label: '$value $label',
      child: ExcludeSemantics(
        child: KCard(
          padding: const EdgeInsets.all(KSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color ?? k.inkMuted),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineSmall?.copyWith(color: color, fontFamily: KFonts.mono),
              ),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Mes dossiers » : ce que j'ai pris en charge et dont l'avis reste à envoyer.
class SpecialistMineTab extends StatelessWidget {
  const SpecialistMineTab({super.key, required this.inbox, required this.onOpen, required this.onGoToQueue});

  final SpecialistInbox inbox;
  final void Function(ExpertiseInboxItem item) onOpen;
  final VoidCallback onGoToQueue;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: inbox,
      builder: (context, _) {
        final mine = inbox.mine;
        Widget body;
        if (!inbox.loadedOnce && inbox.loading) {
          body = const KSkeletonList(count: 2, itemHeight: 120);
        } else if (!inbox.loadedOnce && inbox.error != null) {
          body =
              KErrorView(title: 'Vos dossiers n’ont pas pu être chargés', error: inbox.error!, onRetry: inbox.refresh);
        } else if (mine.isEmpty) {
          body = ListView(
            children: [
              const SizedBox(height: KSpace.xl),
              KEmptyView(
                icon: Icons.assignment_ind_outlined,
                title: 'Aucun dossier en cours',
                message: 'Les dossiers que vous prenez en charge restent ici jusqu’à l’envoi de votre avis.',
                actionLabel: 'Voir la file',
                onAction: onGoToQueue,
              ),
            ],
          );
        } else {
          body = ListView.separated(
            padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, 120),
            itemCount: mine.length,
            separatorBuilder: (_, __) => const SizedBox(height: KSpace.sm),
            itemBuilder: (_, i) => InboxCard(
              item: mine[i],
              isMine: true,
              takenByColleague: false,
              onTap: () => onOpen(mine[i]),
            ),
          );
        }
        return Column(
          children: [
            KScreenHeader(
              eyebrow: 'Pris en charge',
              title: 'Mes dossiers',
              subtitle: mine.isEmpty ? null : 'Avis à rédiger : ${mine.length}',
            ),
            Expanded(child: RefreshIndicator(onRefresh: inbox.refresh, child: body)),
          ],
        );
      },
    );
  }
}
