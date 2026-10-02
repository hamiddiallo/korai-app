import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/utils/consultation_format.dart';
import '../../../../core/utils/patient_age.dart';
import '../../domain/patient.dart';
import '../nurse_actions.dart';
import '../nurse_workspace.dart';

/// Onglet « Patients » : recherche et liste des dossiers.
class NursePatientsTab extends StatefulWidget {
  const NursePatientsTab({super.key, required this.workspace, required this.actions, required this.searchFocus});

  final NurseWorkspace workspace;
  final NurseActions actions;
  final FocusNode searchFocus;

  @override
  State<NursePatientsTab> createState() => _NursePatientsTabState();
}

class _NursePatientsTabState extends State<NursePatientsTab> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Patient p) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return p.fullName.toLowerCase().contains(q) ||
        '${p.lastName} ${p.firstName}'.toLowerCase().contains(q) ||
        (p.phone ?? '').replaceAll(' ', '').contains(q.replaceAll(' ', ''));
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.workspace;
    return Column(
      children: [
        KScreenHeader(
          eyebrow: 'Vos',
          title: 'Patients',
          trailing: [
            FilledButton.icon(
              onPressed: () => widget.actions.startConsultation(),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 14)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouveau'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.sm),
          child: TextField(
            controller: _search,
            focusNode: widget.searchFocus,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: 'Nom, prénom ou téléphone',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: w,
            builder: (context, _) {
              if (!w.loadedOnce && w.loading) return const KSkeletonList();
              if (!w.loadedOnce && w.error != null) return KErrorView(error: w.error!, onRetry: w.refresh);

              final pending = w.pendingValidation.where(_matches).toList();
              final patients = w.patientsByRecency.where(_matches).toList();

              if (w.patients.isEmpty) {
                return KEmptyView(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Aucun patient pour l’instant',
                  message: 'Le dossier d’un patient est créé à sa première consultation.',
                  actionLabel: 'Nouvelle consultation',
                  onAction: () => widget.actions.startConsultation(),
                );
              }
              if (pending.isEmpty && patients.isEmpty) {
                return KEmptyView(
                  icon: Icons.search_off_rounded,
                  title: 'Aucun patient ne correspond à « $_query »',
                  message: 'Vérifiez l’orthographe ou le numéro, ou créez un nouveau dossier.',
                  actionLabel: 'Nouveau patient',
                  onAction: () => widget.actions.startConsultation(),
                );
              }

              return RefreshIndicator(
                onRefresh: w.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, 120),
                  children: [
                    if (pending.isNotEmpty) ...[
                      Text('À valider', style: context.text.titleMedium),
                      const SizedBox(height: KSpace.xs),
                      for (final p in pending) ...[
                        _PatientRow(
                          patient: p,
                          meta: 'A créé son compte',
                          trailing: const KPill(
                              label: 'À valider', icon: Icons.fact_check_outlined, tone: KTone.warning, dense: true),
                          onTap: () => widget.actions.reviewPendingPatient(p),
                        ),
                        const SizedBox(height: KSpace.xs),
                      ],
                      const SizedBox(height: KSpace.md),
                      Text('Dossiers', style: context.text.titleMedium),
                      const SizedBox(height: KSpace.xs),
                      if (patients.isEmpty)
                        const KEmptyView(
                          icon: Icons.folder_shared_outlined,
                          title: 'Aucun dossier dans votre établissement',
                          message:
                              'Les dossiers créés par vous ou vos collègues du même établissement apparaîtront ici.',
                          compact: true,
                        ),
                    ],
                    for (final p in patients) ...[
                      Builder(builder: (context) {
                        final cases = w.casesFor(p.id);
                        final parts = [
                          if (PatientAge.years(p.birthDate) != null) PatientAge.label(p.birthDate),
                          if (KLabels.sexOrNull(p.sex) != null) KLabels.sexOrNull(p.sex)!,
                          '${cases.length} consultation${cases.length > 1 ? 's' : ''}',
                        ];
                        return _PatientRow(
                          patient: p,
                          meta: parts.join(' · '),
                          last: cases.isEmpty
                              ? null
                              : 'Dernière : ${ConsultationFormat.formatDate(cases.first.createdAt)}',
                          onTap: () => widget.actions.openPatient(p),
                        );
                      }),
                      const SizedBox(height: KSpace.xs),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.meta, required this.onTap, this.last, this.trailing});

  final Patient patient;
  final String meta;
  final String? last;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(KSpace.sm),
      child: Row(
        children: [
          KInitialsAvatar(name: patient.fullName, size: 46, heroTag: trailing == null ? 'patient-${patient.id}' : null),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.fullName, style: context.text.titleSmall),
                Text(meta, style: context.text.bodySmall),
                if (last != null) Text(last!, style: context.text.bodySmall),
              ],
            ),
          ),
          trailing ?? Icon(Icons.chevron_right_rounded, color: context.k.inkMuted),
        ],
      ),
    );
  }
}
