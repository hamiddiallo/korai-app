import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/app_lock_settings.dart';
import '../../../core/auth/logout.dart';
import '../../../core/auth/profile_sheets.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/design/design.dart';
import '../../../core/notifications/notification_center.dart';
import '../../../core/refresh/live_refresh.dart';
import '../../../core/utils/patient_age.dart';
import '../../../core/utils/validators.dart';
import '../../chatbot/presentation/korai_chatbot_screen.dart';
import '../../nurse/presentation/widgets/consultation_history_list.dart';
import '../data/patient_repository.dart';
import 'patient_consultation_view_model.dart';
import 'patient_form.dart';
import 'patient_preconsultation_page.dart';
import '../../../core/widgets/consent_fields.dart';

/// Espace patient : son dossier (pré-consultation ou historique une fois
/// validé), l'assistant Korai et son profil.
class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key, required this.session});

  final AuthCubit session;

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> with LiveReloadState {
  late final PatientConsultationViewModel viewModel;
  late final StreamSubscription<PatientConsultationState> _subscription;
  final form = PatientFormControllers();
  int _tab = 0; // 0 dossier, 1 assistant, 2 profil

  /// Change à chaque mise à jour du dossier : le détail d'une consultation
  /// ouvert suit les relectures (compte-rendu du spécialiste).
  final _dossierVersion = ValueNotifier<int>(0);

  // Validation du dossier : notifiée. Résultats d'un avis : relève toutes les 2 min.
  @override
  Set<LiveTopic> get liveTopics => const {LiveTopic.patients, LiveTopic.consultations};

  @override
  Duration? get livePollEvery => const Duration(minutes: 2);

  @override
  Future<void> liveReload() => viewModel.refresh();

  @override
  void initState() {
    super.initState();
    viewModel = PatientConsultationViewModel(
      repository: PatientRepository(widget.session.apiClient),
      session: widget.session,
    );
    _subscription = viewModel.stream.listen((_) {
      _dossierVersion.value++;
      final p = viewModel.patient;
      if (p != null) form.fillOnce(p, fallbackPhone: widget.session.user?.phone);
      if (viewModel.isReadOnly && viewModel.readOnlyNotes != null) {
        form.notes.text = viewModel.readOnlyNotes!;
      }
    });
    viewModel.initialize();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _dossierVersion.dispose();
    form.dispose();
    viewModel.close();
    super.dispose();
  }

  Future<void> _startPreconsultation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PatientPreconsultationPage(viewModel: viewModel, form: form),
      ),
    );
    // Retour au dossier : la pré-consultation envoyée y figure.
    viewModel.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PatientConsultationViewModel, PatientConsultationState>(
      bloc: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) {
          return const Scaffold(body: KLoadingView(message: 'Chargement de votre dossier…'));
        }
        if (viewModel.loadError != null) {
          return _Blocked(
            session: widget.session,
            child: KErrorView(
              title: 'Votre dossier n’a pas pu être chargé',
              error: viewModel.loadError!,
              onRetry: viewModel.initialize,
            ),
          );
        }
        if (viewModel.patient == null) {
          return _Blocked(
            session: widget.session,
            child: const KEmptyView(
              icon: Icons.folder_off_outlined,
              title: 'Aucun dossier patient lié',
              message: 'Votre compte n’est pas encore rattaché à un dossier. Contactez votre centre de santé.',
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _tab,
              children: [
                _DossierTab(
                  viewModel: viewModel,
                  userName: widget.session.user?.fullName ?? viewModel.patient!.fullName,
                  onStart: _startPreconsultation,
                  updates: _dossierVersion,
                ),
                KoraiChatbotScreen(
                  apiClient: widget.session.apiClient,
                  userName: widget.session.user?.fullName,
                  forPatient: true,
                ),
                _ProfileTab(viewModel: viewModel, form: form, session: widget.session),
              ],
            ),
          ),
          bottomNavigationBar: KPillNavBar(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            items: const [
              KNavItem(
                  icon: Icons.folder_shared_outlined, activeIcon: Icons.folder_shared_rounded, label: 'Mon dossier'),
              KNavItem(
                  icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Assistant'),
              KNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profil'),
            ],
          ),
        );
      },
    );
  }
}

/// Écran bloquant (erreur, dossier absent) avec une sortie : se déconnecter.
class _Blocked extends StatelessWidget {
  const _Blocked({required this.session, required this.child});

  final AuthCubit session;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: child),
            Padding(padding: const EdgeInsets.only(bottom: KSpace.md), child: KLogoutButton(session: session)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mon dossier
// ---------------------------------------------------------------------------

class _DossierTab extends StatelessWidget {
  const _DossierTab({required this.viewModel, required this.userName, required this.onStart, required this.updates});

  final PatientConsultationViewModel viewModel;
  final String userName;
  final VoidCallback onStart;
  final Listenable updates;

  String get _firstName {
    final parts = userName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'Bienvenue' : parts.first;
  }

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final validated = vm.isReadOnly;
    return RefreshIndicator(
      onRefresh: vm.reloadHistory,
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
              const NotificationBell(filled: true),
            ],
          ),
          const SizedBox(height: KSpace.md),
          if (validated) ..._validated(context) else ..._pending(context),
        ],
      ),
    );
  }

  List<Widget> _validated(BuildContext context) {
    final vm = viewModel;
    return [
      const KBanner(
        tone: KTone.success,
        icon: Icons.verified_user_outlined,
        title: 'Dossier validé',
        message:
            'Votre soignant a vérifié vos informations. Retrouvez ici vos consultations et leurs résultats partagés.',
      ),
      const SizedBox(height: KSpace.lg),
      KSectionHeader(title: 'Mes consultations', count: vm.consultations.isEmpty ? null : vm.consultations.length),
      const SizedBox(height: KSpace.xs),
      if (vm.historyError != null)
        KErrorView(
          title: 'Vos consultations n’ont pas pu être chargées',
          error: vm.historyError!,
          onRetry: vm.reloadHistory,
          compact: true,
        )
      else
        ConsultationHistoryList(
          consultations: vm.consultations,
          patient: vm.patient,
          emptyMessage: 'Vos consultations apparaîtront ici après votre visite.',
          showStartButton: false,
          forPatient: true,
          updates: updates,
          latest: (id) => vm.consultations.where((c) => c.id == id).firstOrNull,
        ),
    ];
  }

  /// Sans accord pour l'IA, la pré-consultation ne peut pas être envoyée :
  /// on le dit avant de commencer et on propose de donner l'accord.
  Future<void> _askAiConsent(BuildContext context) async {
    final patient = viewModel.patient;
    if (patient == null) return;
    final saved = await showConsentSheet(
      context,
      patientName: patient.fullName,
      forPatient: true,
      ai: true,
      teleExpertise: patient.consentForTeleExpertise,
      onSave: viewModel.updateConsents,
    );
    if (!context.mounted || !saved) return;
    if (viewModel.patient?.consentForAi == true) {
      onStart();
    } else {
      KSnack.show(
        context,
        'Sans votre accord pour l’analyse par l’IA, la pré-consultation ne peut pas être envoyée.',
        tone: KTone.warning,
      );
    }
  }

  List<Widget> _pending(BuildContext context) {
    final vm = viewModel;
    final k = context.k;
    final sent = vm.aiCase != null || vm.consultations.isNotEmpty;
    return [
      const KBanner(
        tone: KTone.warning,
        icon: Icons.hourglass_top_rounded,
        title: 'Compte en attente de validation',
        message: 'Un soignant vérifiera votre identité lors de votre visite. En attendant, préparez-la ici.',
      ),
      const SizedBox(height: KSpace.lg),
      KCard(
        padding: const EdgeInsets.all(KSpace.lg),
        color: k.hero,
        borderColor: k.hero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(sent ? Icons.mark_email_read_outlined : Icons.hearing_rounded, color: k.onHero, size: 30),
            const SizedBox(height: KSpace.sm),
            Text(
              sent ? 'Pré-consultation envoyée' : 'Préparez votre visite',
              style: context.text.headlineSmall?.copyWith(color: k.onHero),
            ),
            const SizedBox(height: KSpace.xxs),
            Text(
              sent
                  ? 'Votre soignant la retrouvera lors de votre visite. Si vos symptômes changent, envoyez-en une nouvelle.'
                  : 'Décrivez vos symptômes en quatre étapes : votre soignant gagnera du temps lors de la consultation.',
              style: context.text.bodyMedium?.copyWith(color: k.onHeroMuted),
            ),
            const SizedBox(height: KSpace.md),
            FilledButton.icon(
              onPressed: vm.patient?.consentForAi == false ? () => _askAiConsent(context) : onStart,
              style: FilledButton.styleFrom(backgroundColor: k.surface, foregroundColor: k.ink),
              icon: Icon(sent ? Icons.add_rounded : Icons.arrow_forward_rounded),
              label: Text(sent ? 'Nouvelle pré-consultation' : 'Commencer ma pré-consultation'),
            ),
          ],
        ),
      ),
      const SizedBox(height: KSpace.lg),
      KSectionHeader(title: 'Comment ça se passe ?'),
      const SizedBox(height: KSpace.xs),
      for (final (i, (title, text)) in const [
        ('Vous décrivez vos symptômes', 'Depuis votre téléphone, avant la visite.'),
        ('Votre soignant vous examine', 'Il vérifie vos informations et valide votre dossier.'),
        ('Vous recevez le résultat', 'Une fois validé par un professionnel de santé.'),
      ].indexed) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: k.lagoon, shape: BoxShape.circle),
              child: Text('${i + 1}', style: context.text.labelMedium?.copyWith(color: k.brand)),
            ),
            const SizedBox(width: KSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  Text(text, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: KSpace.sm),
      ],
    ];
  }
}

// ---------------------------------------------------------------------------
// Profil
// ---------------------------------------------------------------------------

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.viewModel, required this.form, required this.session});

  final PatientConsultationViewModel viewModel;
  final PatientFormControllers form;
  final AuthCubit session;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _formKey = GlobalKey<FormState>();

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      KSnack.show(context, 'Complétez les champs signalés en rouge.', tone: KTone.warning);
      return;
    }
    final f = widget.form;
    try {
      await widget.viewModel.updatePatientProfile(
        firstName: f.firstName.text.trim(),
        lastName: f.lastName.text.trim(),
        phone: f.phone.text.trim(),
        address: f.address.text.trim(),
        birthDate: f.birthDateValue,
        sex: f.sex.value,
      );
      if (mounted) KSnack.success(context, 'Vos informations sont enregistrées.');
    } catch (e) {
      if (mounted) KSnack.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final patient = vm.patient!;
    final f = widget.form;
    final k = context.k;
    return ListView(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.md, KSpace.gutter, 120),
      children: [
        Center(child: KInitialsAvatar(name: patient.fullName, size: 84)),
        const SizedBox(height: KSpace.sm),
        Text(patient.fullName, textAlign: TextAlign.center, style: context.text.headlineSmall),
        Text(
          widget.session.user?.email ?? '',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
        ),
        const SizedBox(height: KSpace.xs),
        Center(
          child: patient.isValidated
              ? const KPill(label: 'Dossier validé', icon: Icons.verified_rounded, tone: KTone.success)
              : const KPill(label: 'En attente de validation', icon: Icons.hourglass_top_rounded, tone: KTone.warning),
        ),
        const SizedBox(height: KSpace.lg),
        if (patient.isValidated) ...[
          KCard(
            child: Column(
              children: [
                KInfoRow(label: 'Âge', value: PatientAge.label(patient.birthDate)),
                KInfoRow(label: 'Sexe', value: KLabels.sex(patient.sex)),
                KInfoRow(label: 'Téléphone', value: _or(patient.phone)),
                KInfoRow(label: 'Adresse', value: _or(patient.address)),
              ],
            ),
          ),
          const SizedBox(height: KSpace.xs),
          Text(
            'Votre dossier est validé : pour corriger une information, adressez-vous à votre soignant.',
            style: context.text.bodySmall,
          ),
        ] else
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Mes informations', style: context.text.titleMedium),
                const SizedBox(height: KSpace.sm),
                TextFormField(
                  controller: f.lastName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (v) => KValidators.required(v, 'Nom'),
                ),
                const SizedBox(height: KSpace.sm),
                TextFormField(
                  controller: f.firstName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                  validator: (v) => KValidators.required(v, 'Prénom'),
                ),
                const SizedBox(height: KSpace.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        controller: f.age,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Âge', suffixText: 'ans'),
                        validator: (v) => KValidators.age(v, required: false),
                      ),
                    ),
                    const SizedBox(width: KSpace.sm),
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: f.sex,
                        builder: (_, sex, __) => KSegmented<String>(
                          segments: const [
                            KSegment(value: 'F', label: 'Féminin'),
                            KSegment(value: 'M', label: 'Masculin'),
                          ],
                          value: sex,
                          onChanged: (v) => f.sex.value = v,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KSpace.sm),
                TextFormField(
                  controller: f.phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone (facultatif)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: KValidators.phoneOptional,
                ),
                const SizedBox(height: KSpace.sm),
                TextFormField(
                  controller: f.address,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Adresse (facultatif)',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
                const SizedBox(height: KSpace.md),
                KAsyncButton(
                  label: 'Enregistrer mes informations',
                  busyLabel: 'Enregistrement…',
                  icon: Icons.check_rounded,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        const SizedBox(height: KSpace.lg),
        _MyConsents(viewModel: vm),
        const SizedBox(height: KSpace.lg),
        const AppLockSettingsCard(),
        const SizedBox(height: KSpace.sm),
        OutlinedButton.icon(
          onPressed: () => showChangePasswordSheet(context, widget.session),
          icon: const Icon(Icons.lock_reset_rounded),
          label: const Text('Changer le mot de passe'),
        ),
        const SizedBox(height: KSpace.xl),
        Center(child: KLogoutButton(session: widget.session)),
      ],
    );
  }

  static String _or(String? v) => (v == null || v.trim().isEmpty) ? 'Non renseigné' : v;
}

/// Accords du patient, modifiables à tout moment (même dossier validé).
class _MyConsents extends StatelessWidget {
  const _MyConsents({required this.viewModel});

  final PatientConsultationViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final patient = viewModel.patient!;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Mes accords', style: context.text.titleSmall)),
              TextButton(
                onPressed: () async {
                  final saved = await showConsentSheet(
                    context,
                    patientName: patient.fullName,
                    forPatient: true,
                    ai: patient.consentForAi,
                    teleExpertise: patient.consentForTeleExpertise,
                    onSave: viewModel.updateConsents,
                  );
                  if (saved && context.mounted) KSnack.success(context, 'Vos accords sont enregistrés.');
                },
                child: const Text('Modifier'),
              ),
            ],
          ),
          ConsentPills(ai: patient.consentForAi, teleExpertise: patient.consentForTeleExpertise),
        ],
      ),
    );
  }
}
