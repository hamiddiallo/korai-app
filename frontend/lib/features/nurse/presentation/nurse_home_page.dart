import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/profile_page.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/design/design.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/refresh/live_refresh.dart';
import '../../chatbot/presentation/korai_chatbot_screen.dart';
import '../data/nurse_repository.dart';
import '../domain/ai_case.dart';
import '../domain/patient.dart';
import 'nurse_actions.dart';
import 'nurse_consultation_view_model.dart';
import 'nurse_workspace.dart';
import 'screens/consultation_flow_page.dart';
import 'screens/nurse_history_tab.dart';
import 'screens/nurse_patients_tab.dart';
import 'screens/nurse_today_tab.dart';
import 'screens/patient_dossier_page.dart';
import 'screens/patient_validation_sheet.dart';
import 'widgets/consultation_history_list.dart';
import '../../../core/sync/sync_cubit.dart';

/// Espace du soignant : Aujourd'hui, Patients, nouvelle consultation,
/// Historique et Assistant.
class NurseHomePage extends StatefulWidget {
  const NurseHomePage({super.key, required this.session});

  final AuthCubit session;

  @override
  State<NurseHomePage> createState() => _NurseHomePageState();
}

class _NurseHomePageState extends State<NurseHomePage> with LiveReloadState {
  late final NurseRepository _repository;
  late final NurseConsultationViewModel _viewModel;
  late final NurseWorkspace _workspace;
  final _searchFocus = FocusNode();
  int _tab = NurseTab.today;

  late final _actions = NurseActions(
    startConsultation: _startConsultation,
    openPatient: _openPatient,
    openConsultation: _openConsultation,
    openProfile: _openProfile,
    goToTab: _goToTab,
    reviewPendingPatient: _reviewPendingPatient,
  );

  @override
  void initState() {
    super.initState();
    _repository = NurseRepository(widget.session.apiClient);
    _viewModel = NurseConsultationViewModel(repository: _repository)..loadClinicalReferences();
    _workspace = NurseWorkspace(_repository)..refresh();
  }

  // Avis du spécialiste et dossier validé arrivent par notification ; la relève
  // toutes les 2 min couvre le reste (patient inscrit seul, collègue du centre).
  @override
  Set<LiveTopic> get liveTopics => const {LiveTopic.consultations, LiveTopic.patients};

  @override
  Duration? get livePollEvery => const Duration(minutes: 2);

  @override
  Future<void> liveReload() => _workspace.refresh();

  @override
  void dispose() {
    _viewModel.close();
    _workspace.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ---------------- Navigation ----------------

  void _goToTab(int tab, {bool focusSearch = false}) {
    if (tab == NurseTab.newConsultation) {
      _startConsultation();
      return;
    }
    setState(() => _tab = tab);
    if (focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
    }
  }

  Future<void> _startConsultation({Patient? patient, String? prefill}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ConsultationFlowPage(
          viewModel: _viewModel,
          workspace: _workspace,
          patient: patient,
          prefillNarrative: prefill,
          onStartNew: () => _startConsultation(),
        ),
      ),
    );
  }

  void _openPatient(Patient patient) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientDossierPage(workspace: _workspace, patient: patient, actions: _actions),
      ),
    );
  }

  void _openConsultation(AiCase consultation) {
    ConsultationHistoryList.openDetail(
      context,
      consultation,
      patientName: _workspace.patientNameFor(consultation),
      onRequestExpertise: _workspace.requestExpertise,
      onConsultationUpdated: _workspace.upsertCase,
      onRetry: _workspace.retryDiagnosis,
      updates: _workspace,
      latest: _workspace.caseById,
      onResumeDraft: (draft) => _startConsultation(
        patient: _workspace.patientById(draft.patientId),
        prefill: draft.symptoms,
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfilePage(session: widget.session)));
  }

  void _reviewPendingPatient(Patient patient) {
    showPatientValidationSheet(
      context,
      workspace: _workspace,
      viewModel: _viewModel,
      patient: patient,
      onValidated: (validated, narrative) => _startConsultation(patient: validated, prefill: narrative),
    );
  }

  Future<void> _onNotificationTap(AppNotification notification) async {
    final consultationId = notification.consultationId;
    var consultation = consultationId == null ? null : _workspace.caseById(consultationId);
    var patient = _workspace.patientById(notification.patientId);
    if (consultation == null && patient == null) {
      // Annoncé par la notification mais pas encore chargé : relire d'abord.
      await _workspace.refresh();
      if (!mounted) return;
      consultation = consultationId == null ? null : _workspace.caseById(consultationId);
      patient = _workspace.patientById(notification.patientId);
    }
    if (consultation != null) {
      _openConsultation(consultation);
    } else if (patient != null) {
      _openPatient(patient);
    }
  }

  /// En-tête épinglé du centre de notifications : comptes patients à valider.
  Widget _pendingHeader(BuildContext sheetContext) {
    final n = _workspace.pendingValidation.length;
    if (n == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.xs),
      child: KBanner(
        tone: KTone.warning,
        icon: Icons.fact_check_outlined,
        title: n == 1 ? '1 compte patient à valider' : '$n comptes patients à valider',
        message: 'Vérifiez leur identité avant leur consultation.',
        actionLabel: 'Voir',
        onAction: () {
          Navigator.pop(sheetContext);
          _goToTab(NurseTab.patients);
        },
      ),
    );
  }

  int get _stackIndex => switch (_tab) {
        NurseTab.patients => 1,
        NurseTab.history => 2,
        NurseTab.assistant => 3,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    // Un envoi de la file a abouti (ou échoué) : les écrans se mettent à jour
    // sans rechargement manuel.
    return BlocListener<SyncCubit, SyncState>(
      listenWhen: (previous, current) =>
          previous.pendingCount != current.pendingCount || previous.failedCount != current.failedCount,
      listener: (_, __) => _workspace.refresh(),
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _stackIndex,
          children: [
            NurseTodayTab(
              workspace: _workspace,
              actions: _actions,
              userName: widget.session.user?.fullName ?? '',
              onNotificationTap: _onNotificationTap,
              pinnedNotificationHeader: _pendingHeader,
            ),
            NursePatientsTab(workspace: _workspace, actions: _actions, searchFocus: _searchFocus),
            NurseHistoryTab(workspace: _workspace, actions: _actions),
            KoraiChatbotScreen(
              apiClient: widget.session.apiClient,
              userName: widget.session.user?.fullName,
            ),
          ],
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _workspace,
        builder: (context, _) => KPillNavBar(
          currentIndex: _tab,
          onTap: _goToTab,
          items: [
            const KNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Accueil'),
            KNavItem(
              icon: Icons.people_outline_rounded,
              activeIcon: Icons.people_rounded,
              label: 'Patients',
              badge: _workspace.pendingValidation.length,
            ),
            const KNavItem(icon: Icons.add_rounded, label: 'Nouvelle consultation', isAction: true),
            KNavItem(
              icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment_rounded,
              label: 'Historique',
              badge: _workspace.cases.where(NurseWorkspace.needsAction).length,
            ),
            const KNavItem(
                icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Assistant'),
          ],
        ),
      ),
    );
  }
}
