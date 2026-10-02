import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/ear_side_selector.dart';
import '../../nurse/domain/ai_case.dart';
import '../../nurse/presentation/widgets/ai_proposal_block.dart';
import '../../nurse/presentation/widgets/consultation_steps.dart';
import 'patient_consultation_view_model.dart';
import 'patient_form.dart';

/// Pré-consultation du patient en quatre étapes, en plein écran : ses
/// informations, ses symptômes, ses antécédents, puis l'envoi.
class PatientPreconsultationPage extends StatefulWidget {
  const PatientPreconsultationPage({super.key, required this.viewModel, required this.form});

  final PatientConsultationViewModel viewModel;
  final PatientFormControllers form;

  static const steps = ['Vos informations', 'Vos symptômes', 'Vos antécédents', 'Récapitulatif'];

  @override
  State<PatientPreconsultationPage> createState() => _PatientPreconsultationPageState();
}

class _PatientPreconsultationPageState extends State<PatientPreconsultationPage> {
  final _identityKey = GlobalKey<FormState>();

  PatientConsultationViewModel get vm => widget.viewModel;
  PatientFormControllers get f => widget.form;

  @override
  void initState() {
    super.initState();
    vm.goToStep(0);
  }

  Future<void> _close() async {
    if (vm.isSubmitting) return;
    final leave = vm.currentStep == 0 ||
        await showKConfirm(
          context,
          title: 'Quitter la pré-consultation ?',
          message:
              'Vos réponses sont conservées tant que l’application reste ouverte : vous pourrez reprendre plus tard.',
          confirmLabel: 'Quitter',
          cancelLabel: 'Continuer',
        );
    if (leave && mounted) Navigator.of(context).pop();
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    final step = vm.currentStep;
    if (step == 0 && !(_identityKey.currentState?.validate() ?? false)) {
      KSnack.show(context, 'Complétez les champs signalés en rouge pour continuer.', tone: KTone.warning);
      return;
    }
    if (step == 1 && vm.symptoms.isNotEmpty && vm.selectedSymptomIds.isEmpty) {
      KSnack.show(context, 'Sélectionnez au moins un symptôme pour continuer.', tone: KTone.warning);
      return;
    }
    if (step < PatientPreconsultationPage.steps.length - 1) {
      vm.nextStep();
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    await vm.submitSprint(
      firstName: f.firstName.text.trim(),
      lastName: f.lastName.text.trim(),
      phone: f.phone.text.trim(),
      address: f.address.text.trim(),
      age: f.age.text.trim(),
      sex: f.sex.value,
      notes: f.notes.text.trim(),
    );
    if (!mounted) return;
    if (vm.errorMessage != null) {
      KSnack.show(context, vm.errorMessage!, tone: KTone.danger);
      return;
    }
    final result = vm.aiCase;
    f.notes.clear();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => KResultScreen(
          kind: KResultKind.success,
          title: 'Pré-consultation envoyée',
          message: 'Présentez-vous à votre soignant : il vérifiera vos informations et validera votre dossier. '
              'Vous serez notifié de la suite.',
          details: _ResultDetails(consultation: result),
          primaryLabel: 'Retour à mon dossier',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PatientConsultationViewModel, PatientConsultationState>(
      bloc: vm,
      builder: (context, _) {
        final step = vm.currentStep;
        final total = PatientPreconsultationPage.steps.length;
        final last = step == total - 1;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _close();
          },
          child: Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _Header(step: step, total: total, onClose: _close),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: KMotion.of(context, KMotion.base),
                      child: ListView(
                        key: ValueKey(step),
                        padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.md, KSpace.gutter, KSpace.xl),
                        children: [
                          if (last && vm.errorMessage != null) ...[
                            KBanner(
                              tone: KTone.danger,
                              title: 'Envoi impossible',
                              message: vm.errorMessage!,
                              actionLabel: 'Réessayer',
                              onAction: vm.isSubmitting ? null : _submit,
                            ),
                            const SizedBox(height: KSpace.md),
                          ],
                          _stepBody(step),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _BottomBar(
              step: step,
              last: last,
              busy: vm.isSubmitting,
              onBack: step == 0 ? null : vm.previousStep,
              onNext: _next,
            ),
          ),
        );
      },
    );
  }

  Widget _stepBody(int step) {
    switch (step) {
      case 0:
        return ValueListenableBuilder<String>(
          valueListenable: f.sex,
          builder: (_, sex, __) => PatientInfoStep(
            formKey: _identityKey,
            firstNameController: f.firstName,
            lastNameController: f.lastName,
            phoneController: f.phone,
            addressController: f.address,
            ageController: f.age,
            sex: sex,
            onSexChanged: (v) => f.sex.value = v,
            title: 'Vos informations',
            hint: 'Vérifiez vos coordonnées : votre soignant les confirmera lors de votre visite.',
          ),
        );
      case 1:
        return ClinicalChipsStep(
          title: 'Que ressentez-vous ?',
          hint: 'Touchez tout ce qui correspond. Le « i » explique chaque terme.',
          items: vm.symptoms,
          selectedIds: vm.selectedSymptomIds,
          onChanged: (id, selected) => vm.toggleSelection('SYMPTOM', id, selected),
          emptyText: 'Aucun symptôme proposé pour le moment',
          unitSingular: 'symptôme',
          unitPlural: 'symptômes',
        );
      case 2:
        return ClinicalChipsStep(
          title: 'Avez-vous déjà eu… ?',
          hint: 'Sélectionnez vos antécédents. Continuez si aucun ne correspond.',
          items: vm.medicalHistories,
          selectedIds: vm.selectedMedicalHistoryIds,
          onChanged: (id, selected) => vm.toggleSelection('MEDICAL_HISTORY', id, selected),
          emptyText: 'Aucun antécédent proposé pour le moment',
          unitSingular: 'antécédent',
          unitPlural: 'antécédents',
        );
      default:
        return _Recap(viewModel: vm, form: f);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.step, required this.total, required this.onClose});

  final int step;
  final int total;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      color: k.surface,
      padding: const EdgeInsets.fromLTRB(KSpace.xxs, KSpace.xxs, KSpace.gutter, KSpace.sm),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                  tooltip: 'Quitter la pré-consultation', onPressed: onClose, icon: const Icon(Icons.close_rounded)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ma pré-consultation', style: context.text.titleLarge),
                    Text(
                      'Étape ${step + 1} sur $total · ${PatientPreconsultationPage.steps[step]}',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: KSpace.md, top: KSpace.xs),
            child: KWaveProgress(
              progress: (step + 1) / total,
              urgency: null,
              semanticLabel: 'Étape ${step + 1} sur $total',
            ),
          ),
        ],
      ),
    );
  }
}

class _Recap extends StatelessWidget {
  const _Recap({required this.viewModel, required this.form});

  final PatientConsultationViewModel viewModel;
  final PatientFormControllers form;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final f = form;
    final symptoms = vm.labelsFor(vm.symptoms, vm.selectedSymptomIds);
    final histories = vm.labelsFor(vm.medicalHistories, vm.selectedMedicalHistoryIds);
    String or(String v, String fallback) => v.trim().isEmpty ? fallback : v.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepQuestion(
          title: 'Vérifiez avant d’envoyer',
          hint: 'Touchez « Modifier » pour corriger une réponse.',
        ),
        _RecapCard(
          title: 'Vos informations',
          onEdit: () => vm.goToStep(0),
          children: [
            KInfoRow(label: 'Nom', value: '${f.firstName.text} ${f.lastName.text}'.trim()),
            KInfoRow(label: 'Âge', value: f.age.text.trim().isEmpty ? 'Non renseigné' : '${f.age.text.trim()} ans'),
            KInfoRow(label: 'Sexe', value: KLabels.sex(f.sex.value)),
            KInfoRow(label: 'Téléphone', value: or(f.phone.text, 'Non renseigné')),
            KInfoRow(label: 'Adresse', value: or(f.address.text, 'Non renseignée')),
          ],
        ),
        const SizedBox(height: KSpace.sm),
        _RecapCard(
          title: 'Vos symptômes',
          onEdit: () => vm.goToStep(1),
          children: [
            Text(symptoms.isEmpty ? 'Aucun symptôme sélectionné' : symptoms.join(', '), style: context.text.bodyMedium)
          ],
        ),
        const SizedBox(height: KSpace.sm),
        _RecapCard(
          title: 'Vos antécédents',
          onEdit: () => vm.goToStep(2),
          children: [
            Text(histories.isEmpty ? 'Aucun antécédent sélectionné' : histories.join(', '),
                style: context.text.bodyMedium)
          ],
        ),
        const SizedBox(height: KSpace.md),
        EarSideSelector(value: vm.earSide, onChanged: vm.setEarSide),
        const SizedBox(height: KSpace.md),
        TextField(
          controller: f.notes,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Autre chose à signaler ? (facultatif)',
            hintText: 'Depuis quand, à quel moment la douleur est la plus forte…',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.title, required this.onEdit, required this.children});

  final String title;
  final VoidCallback onEdit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.xs, KSpace.xs, KSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.text.titleMedium)),
              TextButton(onPressed: onEdit, child: const Text('Modifier')),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar(
      {required this.step, required this.last, required this.busy, required this.onBack, required this.onNext});

  final int step;
  final bool last;
  final bool busy;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      decoration: BoxDecoration(color: k.surface, border: Border(top: BorderSide(color: k.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.sm, KSpace.gutter, KSpace.sm),
          child: Row(
            children: [
              if (onBack != null) ...[
                TextButton.icon(
                  onPressed: busy ? null : onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Retour'),
                ),
                const SizedBox(width: KSpace.xs),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onNext,
                  child: busy
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: k.inkMuted)),
                            const SizedBox(width: 10),
                            const Text('Envoi en cours…'),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (last) ...[const Icon(Icons.send_rounded, size: 20), const SizedBox(width: 8)],
                            Flexible(
                              child: Text(last ? 'Envoyer' : 'Continuer',
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (!last) ...[const SizedBox(width: 8), const Icon(Icons.arrow_forward_rounded, size: 20)],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ce que le patient voit après l'envoi : le résultat seulement quand le
/// serveur l'autorise (après validation par un professionnel).
class _ResultDetails extends StatelessWidget {
  const _ResultDetails({required this.consultation});

  final AiCase? consultation;

  @override
  Widget build(BuildContext context) {
    final c = consultation;
    if (c != null && c.hasAiResult && c.patientCanSeeClinicalDetails) {
      return AiProposalBlock(summary: c.summary, compact: true);
    }
    return KBanner(
      tone: KTone.info,
      icon: Icons.lock_clock_outlined,
      title: 'Résultat partagé après validation',
      message: c?.effectiveSummary?.patientStatusLabel ??
          'Le résultat de l’analyse vous sera communiqué par votre soignant, après son examen.',
    );
  }
}
