import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/design.dart';
import '../../../../core/widgets/consent_fields.dart';
import '../../../../core/domain/korai_enums.dart';
import '../../../../core/utils/patient_age.dart';
import '../../../../core/widgets/orl_image_capture_step.dart';
import '../../domain/patient.dart';
import '../nurse_consultation_view_model.dart';
import '../nurse_workspace.dart';
import '../widgets/consultation_steps.dart';
import 'consultation_result_page.dart';

/// Parcours de consultation en 6 étapes, plein écran.
///
/// L'onde en tête sert de barre de progression : sa longueur suit les étapes,
/// son amplitude et sa couleur suivent l'urgence estimée en direct.
class ConsultationFlowPage extends StatefulWidget {
  const ConsultationFlowPage({
    super.key,
    required this.viewModel,
    required this.workspace,
    this.patient,
    this.prefillNarrative,
    this.onStartNew,
  });

  final NurseConsultationViewModel viewModel;
  final NurseWorkspace workspace;
  final Patient? patient;
  final String? prefillNarrative;

  /// Démarre une nouvelle consultation depuis l'écran de fin.
  final VoidCallback? onStartNew;

  static const steps = [
    'Patient',
    'Symptômes',
    'Antécédents',
    'Examen au toucher',
    'Image de l’oreille',
    'Récapitulatif'
  ];

  @override
  State<ConsultationFlowPage> createState() => _ConsultationFlowPageState();
}

class _ConsultationFlowPageState extends State<ConsultationFlowPage> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _age = TextEditingController();
  final _notes = TextEditingController();
  String _sex = 'F';

  NurseConsultationViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    final p = widget.patient;
    vm
      ..patient = p
      ..consentForAi = p?.consentForAi ?? false
      ..consentForTeleExpertise = p?.consentForTeleExpertise ?? false
      ..aiCase = null
      ..errorMessage = null
      ..infoMessage = null
      ..imageDescription = ''
      ..earSide = EarSide.left;
    vm.photos.clear();
    vm.selectedSymptomIds.clear();
    vm.selectedMedicalHistoryIds.clear();
    vm.selectedTouchCheckIds.clear();
    vm.touchCheckObservations.clear();

    if (p != null) {
      _last.text = p.lastName;
      _first.text = p.firstName;
      _phone.text = p.phone ?? '';
      _address.text = p.address ?? '';
      _age.text = PatientAge.years(p.birthDate)?.toString() ?? '';
      _sex = p.sex == 'M' ? 'M' : 'F';
      _notes.text = vm.extractNotesFromNarrative(widget.prefillNarrative) ?? '';
      final preCase = vm.findPatientPreconsultationCase(widget.workspace.cases, p.id);
      if (preCase != null) {
        vm.applyClinicalPrefillFromCase(preCase);
      } else {
        vm.applyClinicalPrefillFromNarrative(widget.prefillNarrative);
      }
    }
    if (vm.symptoms.isEmpty && !vm.isLoading) {
      unawaited(vm.loadClinicalReferences());
    }
    vm.goToStep(0);
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _phone, _address, _age, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasInput =>
      vm.currentStep > 0 || [_first, _last, _phone, _address, _age].any((c) => c.text.trim().isNotEmpty);

  Future<void> _confirmExit() async {
    if (vm.isSubmitting) {
      KSnack.show(context, 'Analyse en cours : patientez quelques instants avant de quitter.', tone: KTone.warning);
      return;
    }
    if (!_hasInput || widget.patient != null && vm.currentStep == 0) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await showKConfirm(
      context,
      title: 'Quitter la consultation ?',
      message: 'Les informations saisies pour cette consultation seront perdues.',
      confirmLabel: 'Quitter',
      destructive: true,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  bool _savingConsents = false;

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    final step = vm.currentStep;
    if (step == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (!vm.consentForAi) {
        KSnack.show(
          context,
          'Sans l’accord du patient pour l’analyse par l’IA, la consultation ne peut pas être enregistrée. '
          'Demandez-lui son accord, puis activez « Analyse par l’IA ».',
          tone: KTone.warning,
        );
        return;
      }
      if (_savingConsents) return;
      setState(() => _savingConsents = true);
      try {
        await vm.saveConsentsIfChanged();
      } catch (error) {
        if (mounted) KSnack.error(context, error);
        return;
      } finally {
        if (mounted) setState(() => _savingConsents = false);
      }
      if (!mounted) return;
    }
    if (step == 3) {
      final error = vm.validateTouchCheckStep();
      if (error != null) {
        KSnack.show(context, error, tone: KTone.warning);
        return;
      }
    }
    if (step < ConsultationFlowPage.steps.length - 1) {
      vm.nextStep();
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    await vm.submitSprint(
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      age: _age.text.trim(),
      sex: _sex,
      notes: _notes.text.trim(),
    );
    if (!mounted) return;
    final name = '${_first.text.trim()} ${_last.text.trim()}'.trim();
    final ai = vm.aiCase;
    if (ai != null) {
      widget.workspace.upsertCase(ai);
      unawaited(widget.workspace.refresh());
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConsultationResultPage(
            consultation: ai,
            patientName: name,
            infoMessage: vm.infoMessage,
            workspace: widget.workspace,
          ),
        ),
      );
    } else if (vm.errorMessage == null) {
      unawaited(widget.workspace.refresh());
      final urgency = vm.computedUrgency();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => KResultScreen(
            kind: KResultKind.offline,
            title: 'Consultation enregistrée',
            message: vm.infoMessage ??
                'Consultation enregistrée sur l’appareil. L’analyse démarrera automatiquement au retour du réseau.',
            details: KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Patient' : name, style: ctx.text.titleMedium),
                  const SizedBox(height: 4),
                  KEarTag(side: vm.earSide, long: true),
                  const SizedBox(height: KSpace.xs),
                  KUrgencyPill(level: urgency, prefix: 'Urgence estimée', dense: true),
                ],
              ),
            ),
            primaryLabel: 'Retour à l’accueil',
            onPrimary: () => Navigator.of(ctx).popUntil((route) => route.isFirst),
            secondaryLabel: widget.onStartNew == null ? null : 'Nouvelle consultation',
            onSecondary: widget.onStartNew == null
                ? null
                : () {
                    Navigator.of(ctx).pop();
                    widget.onStartNew!();
                  },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NurseConsultationViewModel, NurseConsultationState>(
      bloc: vm,
      builder: (context, _) {
        final step = vm.currentStep;
        final urgency = vm.hasUrgencyInput ? vm.computedUrgency() : null;
        final title = widget.patient?.fullName ??
            (('${_first.text} ${_last.text}').trim().isEmpty
                ? 'Nouvelle consultation'
                : '${_first.text} ${_last.text}'.trim());

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmExit();
          },
          child: Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _Header(
                    title: title,
                    stepLabel:
                        '${ConsultationFlowPage.steps[step]} · étape ${step + 1} sur ${ConsultationFlowPage.steps.length}',
                    step: step,
                    urgency: urgency,
                    onClose: _confirmExit,
                  ),
                  Expanded(child: _body(context, step)),
                  _BottomBar(
                    step: step,
                    busy: vm.isSubmitting,
                    urgency: urgency,
                    noPhoto: step == 4 && !vm.hasPhotos,
                    onBack: step == 0 ? null : vm.previousStep,
                    onNext: _next,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, int step) {
    if (vm.isSubmitting) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
        child: AnalysisProgressView(photoCount: vm.photosToSend.length),
      );
    }
    final clinicalStep = step >= 1 && step <= 3;
    if (clinicalStep && vm.symptoms.isEmpty && vm.medicalHistories.isEmpty && vm.touchChecks.isEmpty) {
      if (vm.isLoading) return const KLoadingView(message: 'Chargement des listes cliniques…');
      if (vm.errorMessage != null) {
        return KErrorView(
          title: 'Listes cliniques indisponibles',
          error: vm.errorMessage!,
          onRetry: vm.loadClinicalReferences,
        );
      }
    }

    final content = switch (step) {
      0 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PatientInfoStep(
              formKey: _formKey,
              firstNameController: _first,
              lastNameController: _last,
              phoneController: _phone,
              addressController: _address,
              ageController: _age,
              sex: _sex,
              onSexChanged: (v) => setState(() => _sex = v),
              existingPatient: widget.patient != null,
            ),
            const SizedBox(height: KSpace.md),
            ConsentFields(
              ai: vm.consentForAi,
              teleExpertise: vm.consentForTeleExpertise,
              enabled: !_savingConsents,
              onChanged: ({required ai, required teleExpertise}) =>
                  vm.setConsents(ai: ai, teleExpertise: teleExpertise),
            ),
          ],
        ),
      1 => ClinicalChipsStep(
          title: 'Qu’est-ce qui gêne le patient ?',
          hint: 'Touchez un symptôme pour le cocher. Le « i » affiche sa définition.',
          items: vm.symptoms,
          selectedIds: vm.selectedSymptomIds,
          onChanged: (id, s) => vm.toggleSelection('SYMPTOM', id, s),
          emptyText: 'Aucun symptôme configuré',
          unitSingular: 'symptôme',
          unitPlural: 'symptômes',
        ),
      2 => ClinicalChipsStep(
          title: 'Quels sont ses antécédents ?',
          hint: 'Cochez ce que le patient a déjà eu. Passez si aucun.',
          items: vm.medicalHistories,
          selectedIds: vm.selectedMedicalHistoryIds,
          onChanged: (id, s) => vm.toggleSelection('MEDICAL_HISTORY', id, s),
          emptyText: 'Aucun antécédent configuré',
          unitSingular: 'antécédent',
          unitPlural: 'antécédents',
        ),
      3 => TouchExamStep(
          items: vm.touchChecks,
          selectedIds: vm.selectedTouchCheckIds,
          observations: vm.touchCheckObservations,
          options: NurseConsultationViewModel.touchObservationOptions,
          onSelectionChanged: vm.toggleTouchCheck,
          onObservationChanged: vm.setTouchCheckObservation,
        ),
      4 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepQuestion(
              title: 'Photographiez le tympan',
              hint: 'Choisissez l’oreille examinée, ou les deux pour photographier chaque tympan.',
            ),
            OrlImageCaptureStep(
              photos: vm.photos,
              earSide: vm.earSide,
              onEarSideChanged: vm.setEarSide,
              editingSide: vm.editingSide,
              description: vm.imageDescription,
              onDescriptionChanged: vm.setImageDescription,
              onCamera: (side) => _pick(ImageSource.camera, side),
              onGallery: (side) => _pick(ImageSource.gallery, side),
              onRotateLeft: (side) => vm.rotateImage(side, clockwise: false),
              onRotateRight: (side) => vm.rotateImage(side, clockwise: true),
              onFlipHorizontal: vm.flipImageHorizontal,
              onBrighten: (side) => vm.adjustImageBrightness(side, brighter: true),
              onDarken: (side) => vm.adjustImageBrightness(side, brighter: false),
              onRemove: vm.removePhoto,
            ),
          ],
        ),
      _ => RecapStep(
          patientName: '${_first.text.trim()} ${_last.text.trim()}'.trim(),
          age: _age.text.trim(),
          sex: _sex,
          phone: _phone.text.trim(),
          earSide: vm.earSide,
          symptoms: vm.labelsFor(vm.symptoms, vm.selectedSymptomIds),
          histories: vm.labelsFor(vm.medicalHistories, vm.selectedMedicalHistoryIds),
          touchChecks: vm.touchCheckSummaries(),
          photos: vm.photosToSend,
          urgency: vm.computedUrgency(),
          notesController: _notes,
          error: vm.errorMessage,
          onRetry: _submit,
        ),
    };

    final reduced = KMotion.reduced(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : KMotion.base,
      switchInCurve: KMotion.enter,
      switchOutCurve: KMotion.leave,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: SingleChildScrollView(
        key: ValueKey('step-$step'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.md, KSpace.gutter, KSpace.xl),
        child: content,
      ),
    );
  }

  Future<void> _pick(ImageSource source, EarSide side) async {
    try {
      await vm.pickImage(source, side: side);
    } catch (e) {
      if (mounted) {
        KSnack.show(
          context,
          source == ImageSource.camera
              ? 'Impossible d’ouvrir l’appareil photo. Vérifiez l’autorisation dans les réglages du téléphone.'
              : 'Impossible d’ouvrir la galerie. Vérifiez l’autorisation dans les réglages du téléphone.',
          tone: KTone.danger,
        );
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.title, required this.stepLabel, required this.step, required this.urgency, required this.onClose});

  final String title;
  final String stepLabel;
  final int step;
  final UrgencyLevel? urgency;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final total = ConsultationFlowPage.steps.length;
    return Container(
      color: k.surface,
      padding: const EdgeInsets.fromLTRB(KSpace.xxs, KSpace.xxs, KSpace.gutter, KSpace.sm),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Quitter la consultation',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleLarge),
                    Text(stepLabel, style: context.text.bodySmall),
                  ],
                ),
              ),
              if (urgency != null) KUrgencyPill(level: urgency, dense: true),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: KSpace.md, top: KSpace.xs),
            child: KWaveProgress(
              progress: (step + 1) / total,
              urgency: urgency,
              semanticLabel: 'Étape ${step + 1} sur $total. '
                  '${urgency == null ? 'Urgence pas encore estimée' : 'Urgence estimée ${KUrgency.label(urgency).toLowerCase()}'}',
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.busy,
    required this.urgency,
    required this.noPhoto,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final bool busy;
  final UrgencyLevel? urgency;
  final bool noPhoto;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final last = step == ConsultationFlowPage.steps.length - 1;
    final label = last ? 'Lancer l’analyse' : (noPhoto ? 'Continuer sans photo' : 'Continuer');
    return Container(
      decoration: BoxDecoration(color: k.surface, border: Border(top: BorderSide(color: k.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.sm, KSpace.gutter, KSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (urgency != null && !busy && !last)
                Padding(
                  padding: const EdgeInsets.only(bottom: KSpace.xs),
                  child: Row(
                    children: [
                      Icon(KUrgency.icon(urgency), size: 16, color: KUrgency.color(context, urgency)),
                      const SizedBox(width: 6),
                      Text('Urgence estimée : ${KUrgency.label(urgency).toLowerCase()}',
                          style: context.text.labelMedium),
                    ],
                  ),
                ),
              Row(
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
                      style: noPhoto && !last
                          ? FilledButton.styleFrom(backgroundColor: k.lagoon, foregroundColor: k.onLagoon)
                          : null,
                      child: busy
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2.4, color: k.inkMuted)),
                                const SizedBox(width: 10),
                                const Text('Analyse en cours…'),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (last) ...[
                                  const Icon(Icons.auto_awesome_rounded, size: 20),
                                  const SizedBox(width: 8)
                                ],
                                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                                if (!last) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 20)
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
