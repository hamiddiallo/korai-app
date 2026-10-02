import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../nurse_actions.dart';
import '../nurse_workspace.dart';
import '../widgets/consultation_card.dart';

enum _Filter { toHandle, waiting, done }

/// Onglet « Historique » : trié par ce qu'il reste à faire.
class NurseHistoryTab extends StatefulWidget {
  const NurseHistoryTab({super.key, required this.workspace, required this.actions});

  final NurseWorkspace workspace;
  final NurseActions actions;

  @override
  State<NurseHistoryTab> createState() => _NurseHistoryTabState();
}

class _NurseHistoryTabState extends State<NurseHistoryTab> {
  _Filter _filter = _Filter.toHandle;

  @override
  Widget build(BuildContext context) {
    final w = widget.workspace;
    return ListenableBuilder(
      listenable: w,
      builder: (context, _) {
        final toHandle = w.cases.where(NurseWorkspace.needsAction).toList();
        final waiting = w.cases.where(NurseWorkspace.isWaiting).toList();
        final done = w.cases.where(NurseWorkspace.isDone).toList();
        final list = switch (_filter) {
          _Filter.toHandle => toHandle,
          _Filter.waiting => waiting,
          _Filter.done => done,
        };

        Widget body;
        if (!w.loadedOnce && w.loading) {
          body = const KSkeletonList();
        } else if (!w.loadedOnce && w.error != null) {
          body = KErrorView(error: w.error!, onRetry: w.refresh);
        } else if (list.isEmpty) {
          body = ListView(
            children: [
              const SizedBox(height: KSpace.xl),
              KEmptyView(
                icon: switch (_filter) {
                  _Filter.toHandle => Icons.task_alt_rounded,
                  _Filter.waiting => Icons.hourglass_empty_rounded,
                  _Filter.done => Icons.event_available_outlined,
                },
                title: switch (_filter) {
                  _Filter.toHandle => 'Rien à traiter',
                  _Filter.waiting => 'Aucune consultation en attente',
                  _Filter.done => 'Aucune consultation terminée',
                },
                message: switch (_filter) {
                  _Filter.toHandle => 'Les analyses à relancer et les brouillons apparaîtront ici.',
                  _Filter.waiting => 'Les analyses en cours et les avis demandés apparaîtront ici.',
                  _Filter.done => 'Les consultations analysées ou validées par un spécialiste apparaîtront ici.',
                },
                actionLabel: _filter == _Filter.done ? 'Nouvelle consultation' : null,
                onAction: _filter == _Filter.done ? () => widget.actions.startConsultation() : null,
              ),
            ],
          );
        } else {
          body = ListView.separated(
            padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, 120),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: KSpace.xs),
            itemBuilder: (_, i) => ConsultationCard(
              consultation: list[i],
              patientName: w.patientNameFor(list[i]),
              onTap: () => widget.actions.openConsultation(list[i]),
            ),
          );
        }

        return Column(
          children: [
            const KScreenHeader(eyebrow: 'Historique', title: 'Vos consultations'),
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.sm),
              child: KSegmented<_Filter>(
                segments: [
                  KSegment(value: _Filter.toHandle, label: 'À traiter', count: toHandle.length),
                  KSegment(value: _Filter.waiting, label: 'En attente', count: waiting.length),
                  const KSegment(value: _Filter.done, label: 'Terminées'),
                ],
                value: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
            Expanded(child: RefreshIndicator(onRefresh: w.refresh, child: body)),
          ],
        );
      },
    );
  }
}
