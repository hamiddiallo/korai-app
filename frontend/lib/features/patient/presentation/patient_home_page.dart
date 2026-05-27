import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/domain/korai_enums.dart';
import '../../../core/utils/consultation_format.dart';
import '../../../core/widgets/ear_side_selector.dart';
import '../../chatbot/presentation/korai_chatbot_screen.dart';
import '../../nurse/presentation/widgets/consultation_history_list.dart';
import '../data/patient_repository.dart';
import 'patient_consultation_view_model.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key, required this.session});

  final AuthCubit session;

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  late final PatientConsultationViewModel viewModel;
  late final StreamSubscription<PatientConsultationState>
      _viewModelSubscription;

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final ageController = TextEditingController();
  final notesController = TextEditingController();
  String sex = 'F';
  bool _isProfilePopulated = false;
  int _currentTab = 0; // 0 = Consultation, 1 = Chatbot

  static const steps = [
    'Infos Perso',
    'Symptômes',
    'Antécédents',
    'Récapitulatif',
  ];

  @override
  void initState() {
    super.initState();
    viewModel = PatientConsultationViewModel(
      repository: PatientRepository(widget.session.apiClient),
      session: widget.session,
    );
    _viewModelSubscription =
        viewModel.stream.listen((_) => _onViewModelChanged());
    viewModel.initialize();
  }

  void _onViewModelChanged() {
    if (viewModel.patient == null) return;

    setState(() {
      if (!_isProfilePopulated) {
        firstNameController.text = viewModel.patient!.firstName;
        lastNameController.text = viewModel.patient!.lastName;
        phoneController.text =
            viewModel.patient!.phone ?? widget.session.user?.phone ?? '';
        addressController.text = viewModel.patient!.address ?? '';
        if (viewModel.patient!.birthDate != null) {
          ageController.text = viewModel.patient!.birthDate!
              .replaceAll('Age: ', '')
              .replaceAll(' ans', '');
        }
        if (viewModel.patient!.sex != null) {
          sex = viewModel.patient!.sex == 'M' ? 'M' : 'F';
        }
        _isProfilePopulated = true;
      }
      if (viewModel.isReadOnly && viewModel.readOnlyNotes != null) {
        notesController.text = viewModel.readOnlyNotes!;
      }
    });
  }

  @override
  void dispose() {
    _viewModelSubscription.cancel();
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    ageController.dispose();
    notesController.dispose();
    viewModel.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PatientConsultationViewModel, PatientConsultationState>(
      bloc: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement de votre dossier patient...',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: _currentTab == 1
              ? null
              : AppBar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTab == 2
                            ? 'Mon Profil'
                            : 'Pré-consultation ORL',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Espace Patient',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Déconnexion',
                      onPressed: widget.session.logout,
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
          body: _currentTab == 1
              ? KoraiChatbotScreen(
                  apiClient: widget.session.apiClient,
                  userName: widget.session.user?.fullName,
                )
              : _currentTab == 2
                  ? _buildProfileTab()
                  : viewModel.isReadOnly
                      ? _buildReadOnlyConsultationTab()
                      : SafeArea(
                          child: Column(
                            children: [
                              PatientSprintProgress(
                                steps: steps,
                                currentStep: viewModel.currentStep,
                                onTap: viewModel.isReadOnly
                                    ? (_) {}
                                    : viewModel.goToStep,
                              ),
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  children: [
                                    if (viewModel.errorMessage != null) ...[
                                      PatientErrorBanner(
                                          message: viewModel.errorMessage!),
                                      const SizedBox(height: 12),
                                    ],
                                    PatientSprintCard(
                                      title: steps[viewModel.currentStep],
                                      subtitle: _getStepSubtitle(
                                          viewModel.currentStep),
                                      child: _currentStepBody(),
                                    ),
                                    if (viewModel.aiCase != null) ...[
                                      const SizedBox(height: 16),
                                      PatientAiResultCard(
                                          aiCase: viewModel.aiCase!),
                                    ],
                                  ],
                                ),
                              ),
                              PatientSprintNavigationBar(
                                isFirst: viewModel.currentStep == 0,
                                isLast:
                                    viewModel.currentStep == steps.length - 1,
                                isBusy: viewModel.isSubmitting,
                                isReadOnly: viewModel.isReadOnly,
                                onPrevious: viewModel.previousStep,
                                onNext: _handleNext,
                              ),
                            ],
                          ),
                        ),
          bottomNavigationBar: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomTab(
                  icon: Icons.assignment_outlined,
                  activeIcon: Icons.assignment_rounded,
                  label: 'Consultation',
                  isActive: _currentTab == 0,
                  onPressed: () => setState(() => _currentTab = 0),
                ),
                _buildBottomTab(
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  label: 'Chatbot KORAI',
                  isActive: _currentTab == 1,
                  onPressed: () => setState(() => _currentTab = 1),
                ),
                _buildBottomTab(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Mon Profil',
                  isActive: _currentTab == 2,
                  onPressed: () => setState(() => _currentTab = 2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomTab({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final color = isActive ? Colors.indigo.shade700 : Colors.grey.shade500;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.indigo.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 22),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyConsultationTab() {
    final patient = viewModel.patient;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.green, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dossier validé. Consultez l\'historique de vos consultations.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          ConsultationHistoryList(
            consultations: viewModel.consultations,
            patient: patient,
            emptyMessage: 'Aucune consultation enregistrée sur votre dossier.',
            showStartButton: false,
            forPatient: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final patient = viewModel.patient;
    if (patient == null) {
      return const Center(child: Text('Dossier patient introuvable.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF006D77).withValues(alpha: 0.1),
                child: const Icon(Icons.person,
                    size: 36, color: Color(0xFF006D77)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.session.user?.email ?? 'patient@korai.local',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!patient.isValidated)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compte en attente de validation',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                              fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Votre compte est actuellement un brouillon. Un infirmier validera votre dossier lors de votre visite clinique.',
                          style: TextStyle(color: Colors.black87, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compte Validé et Actif',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Votre dossier est validé. Vous pouvez le consulter mais plus le modifier.',
                          style: TextStyle(color: Colors.black87, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'Informations personnelles',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: firstNameController,
            readOnly: patient.isValidated,
            decoration: const InputDecoration(
              labelText: 'Prénom',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: lastNameController,
            readOnly: patient.isValidated,
            decoration: const InputDecoration(
              labelText: 'Nom',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: phoneController,
            readOnly: patient.isValidated,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: ageController,
            readOnly: patient.isValidated,
            decoration: const InputDecoration(
              labelText: 'Âge (ans)',
              prefixIcon: Icon(Icons.calendar_today_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: addressController,
            readOnly: patient.isValidated,
            decoration: const InputDecoration(
              labelText: 'Adresse',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          if (!patient.isValidated) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006D77),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  try {
                    await viewModel.updatePatientProfile(
                      firstName: firstNameController.text.trim(),
                      lastName: lastNameController.text.trim(),
                      phone: phoneController.text.trim(),
                      address: addressController.text.trim(),
                      birthDate: ageController.text.isEmpty
                          ? null
                          : 'Age: ${ageController.text.trim()} ans',
                      sex: sex,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profil mis à jour avec succès !'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur lors de la mise à jour : $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer les modifications',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStepSubtitle(int step) {
    if (viewModel.isReadOnly) {
      return 'Consultation validée — affichage en lecture seule.';
    }
    return switch (step) {
      0 => 'Vérifiez et complétez vos coordonnées personnelles.',
      1 =>
        'Sélectionnez les signes et douleurs que vous ressentez actuellement.',
      2 => 'Avez-vous des antécédents médicaux particuliers ?',
      _ => 'Vérifiez toutes vos réponses avant de valider votre dossier.',
    };
  }

  Widget _currentStepBody() {
    final readOnly = viewModel.isReadOnly;
    return switch (viewModel.currentStep) {
      0 => PatientInfoStep(
          firstNameController: firstNameController,
          lastNameController: lastNameController,
          phoneController: phoneController,
          addressController: addressController,
          ageController: ageController,
          sex: sex,
          readOnly: readOnly,
          onSexChanged: (value) => setState(() => sex = value),
        ),
      1 => PatientClinicalSelectionStep(
          items: viewModel.symptoms,
          selectedIds: viewModel.selectedSymptomIds,
          emptyText: 'Aucun symptôme configuré',
          readOnly: readOnly,
          onChanged: (id, selected) =>
              viewModel.toggleSelection('SYMPTOM', id, selected),
        ),
      2 => PatientClinicalSelectionStep(
          items: viewModel.medicalHistories,
          selectedIds: viewModel.selectedMedicalHistoryIds,
          emptyText: 'Aucun antécédent configuré',
          readOnly: readOnly,
          onChanged: (id, selected) =>
              viewModel.toggleSelection('MEDICAL_HISTORY', id, selected),
        ),
      _ => PatientRecapStep(
          firstName: firstNameController.text,
          lastName: lastNameController.text,
          phone: phoneController.text,
          address: addressController.text,
          age: ageController.text,
          sex: sex,
          earSide: viewModel.earSide,
          onEarSideChanged: readOnly ? null : viewModel.setEarSide,
          notesController: notesController,
          readOnly: readOnly,
          selectedSymptoms: viewModel.labelsFor(
              viewModel.symptoms, viewModel.selectedSymptomIds),
          selectedHistories: viewModel.labelsFor(
              viewModel.medicalHistories, viewModel.selectedMedicalHistoryIds),
          selectedTouchChecks: const [],
          hasImage: false,
        ),
    };
  }

  Future<void> _handleNext() async {
    if (viewModel.isReadOnly) {
      if (viewModel.currentStep < steps.length - 1) {
        viewModel.nextStep();
      }
      return;
    }

    if (viewModel.currentStep < steps.length - 1) {
      viewModel.nextStep();
      return;
    }

    try {
      await viewModel.submitSprint(
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        age: ageController.text.trim(),
        sex: sex,
        notes: notesController.text.trim(),
      );

      if (!mounted) return;

      if (viewModel.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Erreur : ${viewModel.errorMessage}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dossier enregistré avec succès ! En attente de validation par un infirmier.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        notesController.clear();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur inattendue : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class PatientSprintProgress extends StatefulWidget {
  const PatientSprintProgress({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.onTap,
  });

  final List<String> steps;
  final int currentStep;
  final ValueChanged<int> onTap;

  @override
  State<PatientSprintProgress> createState() => _PatientSprintProgressState();
}

class _PatientSprintProgressState extends State<PatientSprintProgress> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActiveStep());
  }

  @override
  void didUpdateWidget(covariant PatientSprintProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep) {
      _scrollToActiveStep();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveStep() {
    if (!_scrollController.hasClients) return;

    // Estimate item width plus padding/spacing
    const double itemWidth = 140.0;
    final screenWidth = MediaQuery.of(context).size.width;

    // Target scroll offset to center active index
    final targetOffset = (widget.currentStep * itemWidth) +
        16.0 -
        (screenWidth / 2) +
        (itemWidth / 2);
    final maxScroll = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Sleek progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (widget.currentStep + 1) / widget.steps.length,
                minHeight: 6,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Scrollable step indicators
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 16),
                for (var index = 0; index < widget.steps.length; index++) ...[
                  GestureDetector(
                    onTap: () => widget.onTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: index == widget.currentStep
                            ? colorScheme.primary
                            : index < widget.currentStep
                                ? colorScheme.primary.withValues(alpha: 0.08)
                                : colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: index == widget.currentStep
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: index == widget.currentStep
                                ? Colors.white
                                : index < widget.currentStep
                                    ? colorScheme.primary
                                    : colorScheme.outline
                                        .withValues(alpha: 0.5),
                            child: index < widget.currentStep
                                ? const Icon(Icons.check,
                                    size: 10, color: Colors.white)
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: index == widget.currentStep
                                          ? colorScheme.primary
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.steps[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: index == widget.currentStep
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: index == widget.currentStep
                                  ? Colors.white
                                  : index < widget.currentStep
                                      ? colorScheme.primary
                                      : colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (index < widget.steps.length - 1) const SizedBox(width: 8),
                ],
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PatientSprintCard extends StatelessWidget {
  const PatientSprintCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const Divider(height: 24, thickness: 1),
            child,
          ],
        ),
      ),
    );
  }
}

class PatientClinicalSelectionStep extends StatelessWidget {
  const PatientClinicalSelectionStep({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.emptyText,
    required this.onChanged,
    this.readOnly = false,
  });

  final List<dynamic> items;
  final Set<String> selectedIds;
  final String emptyText;
  final void Function(String id, bool selected) onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
            child: Text(emptyText, style: const TextStyle(color: Colors.grey))),
      );
    }

    return Column(
      children: items.map((item) {
        final isSelected = selectedIds.contains(item.id);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: CheckboxListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              item.label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: item.description == null ? null : Text(item.description!),
            value: isSelected,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged:
                readOnly ? null : (value) => onChanged(item.id, value ?? false),
          ),
        );
      }).toList(),
    );
  }
}

class PatientInfoStep extends StatelessWidget {
  const PatientInfoStep({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.phoneController,
    required this.addressController,
    required this.ageController,
    required this.sex,
    required this.onSexChanged,
    this.readOnly = false,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController ageController;
  final String sex;
  final ValueChanged<String> onSexChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nom',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: lastNameController,
                    readOnly: readOnly,
                    decoration: InputDecoration(
                      hintText: 'ex: Diallo',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prénom',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: firstNameController,
                    readOnly: readOnly,
                    decoration: InputDecoration(
                      hintText: 'ex: Aïssatou',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Téléphone',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: phoneController,
          readOnly: readOnly,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: 'ex: +221 77 ...',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Adresse',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: addressController,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: 'ex: Sacré-Cœur 3, Dakar',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Âge (ans)',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ageController,
                    readOnly: readOnly,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'ex: 28',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sexe',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor:
                          Theme.of(context).colorScheme.primary,
                      selectedForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    segments: const [
                      ButtonSegment(value: 'M', label: Text('M')),
                      ButtonSegment(value: 'F', label: Text('F')),
                    ],
                    selected: {sex},
                    onSelectionChanged:
                        readOnly ? null : (value) => onSexChanged(value.first),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PatientRecapStep extends StatelessWidget {
  const PatientRecapStep({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.address,
    required this.age,
    required this.sex,
    required this.earSide,
    this.onEarSideChanged,
    required this.notesController,
    required this.selectedSymptoms,
    required this.selectedHistories,
    required this.selectedTouchChecks,
    required this.hasImage,
    this.readOnly = false,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String address;
  final String age;
  final String sex;
  final EarSide earSide;
  final ValueChanged<EarSide>? onEarSideChanged;
  final TextEditingController notesController;
  final List<String> selectedSymptoms;
  final List<String> selectedHistories;
  final List<String> selectedTouchChecks;
  final bool hasImage;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RecapRow(label: 'Patient', value: '$firstName $lastName'.trim()),
        _RecapRow(
            label: 'Âge', value: age.isEmpty ? 'Non renseigné' : '$age ans'),
        _RecapRow(label: 'Sexe', value: sex == 'M' ? 'Masculin' : 'Féminin'),
        if (readOnly)
          _RecapRow(
              label: 'Oreille', value: ConsultationFormat.earSideLabel(earSide))
        else if (onEarSideChanged != null) ...[
          EarSideSelector(value: earSide, onChanged: onEarSideChanged!),
          const SizedBox(height: 12),
        ],
        _RecapRow(
            label: 'Téléphone', value: phone.isEmpty ? 'Non renseigné' : phone),
        _RecapRow(
            label: 'Adresse',
            value: address.isEmpty ? 'Non renseignée' : address),
        const Divider(height: 20),
        _RecapRow(
          label: 'Symptômes',
          value: selectedSymptoms.isEmpty
              ? 'Aucun sélectionné'
              : selectedSymptoms.join(', '),
        ),
        _RecapRow(
          label: 'Antécédents',
          value: selectedHistories.isEmpty
              ? 'Aucun sélectionné'
              : selectedHistories.join(', '),
        ),
        const Divider(height: 24),
        const Text(
          'Notes ou commentaires complémentaires',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: notesController,
          readOnly: readOnly,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: readOnly
                ? 'Aucune note complémentaire'
                : 'Décrivez précisément vos douleurs ou d\'autres symptômes...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label :',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientSprintNavigationBar extends StatelessWidget {
  const PatientSprintNavigationBar({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.isBusy,
    required this.onPrevious,
    required this.onNext,
    this.isReadOnly = false,
  });

  final bool isFirst;
  final bool isLast;
  final bool isBusy;
  final bool isReadOnly;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isFirst || isBusy ? null : onPrevious,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Précédent'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: isBusy || (isReadOnly && isLast) ? null : onNext,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(isReadOnly || !isLast
                        ? Icons.arrow_forward
                        : Icons.save),
                label: Text(isReadOnly
                    ? 'Suivant'
                    : (isLast ? 'Enregistrer' : 'Suivant')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientErrorBanner extends StatelessWidget {
  const PatientErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientAiResultCard extends StatelessWidget {
  const PatientAiResultCard({super.key, required this.aiCase});

  final dynamic aiCase;

  @override
  Widget build(BuildContext context) {
    final summary = aiCase.summary;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: colorScheme.primary, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Synthèse de l\'Analyse IA',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            _RecapRow(
                label: 'Diagnostic probable',
                value: summary.likelyDiagnosis ?? 'Non déterminé'),
            _RecapRow(
                label: 'Avis image',
                value: summary.imageOpinion ?? 'Non disponible'),
            _RecapRow(
                label: 'Avis symptômes',
                value: summary.ragOpinion ?? 'Non disponible'),
            _RecapRow(
              label: 'Niveau de confiance',
              value: summary.confidenceLabel.value,
              valueColor: summary.confidenceLabel == AiConfidenceLabel.high
                  ? Colors.green
                  : summary.confidenceLabel == AiConfidenceLabel.medium
                      ? Colors.orange
                      : Colors.red,
            ),
            if (summary.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Alertes & Conseils',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              ...summary.warnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warning,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
