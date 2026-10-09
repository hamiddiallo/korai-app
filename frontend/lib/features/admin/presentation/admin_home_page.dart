import 'package:flutter/material.dart';

import '../../../core/auth/logout.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/design/design.dart';
import '../../../core/refresh/live_refresh.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';
import 'admin_audit_tab.dart';
import 'admin_clinical_items_tab.dart';
import 'admin_medecins_tab.dart';
import 'admin_patients_tab.dart';
import 'admin_users_tab.dart';

enum _Section { users, patients, facilities, medecins, symptoms, histories, touches, audit }

extension on _Section {
  String get title => switch (this) {
        _Section.users => 'Comptes',
        _Section.patients => 'Dossiers patients',
        _Section.facilities => 'Établissements',
        _Section.audit => 'Journal d’audit',
        _Section.medecins => 'Registre des médecins',
        _Section.symptoms => 'Symptômes',
        _Section.histories => 'Antécédents',
        _Section.touches => 'Vérifications au toucher',
      };

  String get subtitle => switch (this) {
        _Section.users => 'Accès des soignants, spécialistes, patients et administrateurs.',
        _Section.patients => 'Identité, consentements et consultations.',
        _Section.facilities => 'Les soignants d’un établissement partagent ses dossiers.',
        _Section.audit => 'Qui a consulté ou modifié quel dossier, et quand.',
        _Section.medecins => 'Matricules vérifiés à l’inscription.',
        _Section.symptoms => 'Proposés en consultation, avec leur score de danger.',
        _Section.histories => 'Antécédents et facteurs de risque, avec leur score de danger.',
        _Section.touches => 'Gestes de l’examen, avec leur score de danger.',
      };

  IconData get icon => switch (this) {
        _Section.users => Icons.group_outlined,
        _Section.patients => Icons.folder_shared_outlined,
        _Section.facilities => Icons.local_hospital_outlined,
        _Section.audit => Icons.policy_outlined,
        _Section.medecins => Icons.badge_outlined,
        _Section.symptoms => Icons.sick_outlined,
        _Section.histories => Icons.history_edu_outlined,
        _Section.touches => Icons.touch_app_outlined,
      };
}

/// Console d'administration : chiffres clés, puis accès aux comptes, aux
/// dossiers et aux référentiels cliniques.
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key, required this.session});

  final AuthCubit session;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> with LiveReloadState {
  late final AdminRepository repository;

  _Section? _section;
  bool _loadingStats = false;
  Object? _statsError;
  Map<_Section, int>? _counts;

  /// Inscriptions en attente de vérification (spécialistes, infirmiers).
  int _pendingAccounts = 0;

  @override
  void initState() {
    super.initState();
    repository = AdminRepository(widget.session.apiClient);
    _loadStats();
  }

  // Chiffres relus au retour au premier plan ; une rubrique ouverte se relit elle-même.
  @override
  Future<void> liveReload() async {
    if (_section == null) await _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _loadingStats = true;
      _statsError = null;
    });
    try {
      final r = await Future.wait([
        repository.listUsers(),
        repository.listPatients(),
        repository.listFacilities(),
        repository.listMedecins(),
        repository.listClinicalItems('SYMPTOM'),
        repository.listClinicalItems('MEDICAL_HISTORY'),
        repository.listClinicalItems('TOUCH_CHECK'),
      ]);
      if (!mounted) return;
      const counted = [
        _Section.users,
        _Section.patients,
        _Section.facilities,
        _Section.medecins,
        _Section.symptoms,
        _Section.histories,
        _Section.touches,
      ];
      setState(() {
        _counts = {for (var i = 0; i < counted.length; i++) counted[i]: r[i].length};
        _pendingAccounts = (r[0] as List<AdminUser>).where((u) => u.isPending).length;
      });
    } catch (e) {
      if (mounted) setState(() => _statsError = e);
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  void _open(_Section? section) {
    setState(() => _section = section);
    if (section == null) _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final section = _section;
    return PopScope(
      canPop: section == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _section != null) _open(null);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: KMotion.of(context, KMotion.base),
            child: section == null ? _dashboard(context) : _sectionView(context, section),
          ),
        ),
      ),
    );
  }

  Widget _dashboard(BuildContext context) {
    final k = context.k;
    final name = widget.session.user?.fullName.trim().split(RegExp(r'\s+')).first ?? '';
    return RefreshIndicator(
      key: const ValueKey('dashboard'),
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.md, KSpace.gutter, KSpace.xl),
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Administration', style: context.text.bodyLarge?.copyWith(color: k.inkMuted)),
                      Text('Console Korai', style: context.text.headlineLarge),
                    ],
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Se déconnecter',
                onPressed: () => confirmAndLogout(context, widget.session),
                icon: Icon(Icons.logout_rounded, color: k.danger),
              ),
            ],
          ),
          const SizedBox(height: KSpace.md),
          KCard(
            color: k.hero,
            borderColor: k.hero,
            padding: const EdgeInsets.all(KSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Bonjour' : 'Bonjour, $name',
                  style: context.text.headlineSmall?.copyWith(color: k.onHero),
                ),
                const SizedBox(height: KSpace.xxs),
                Text(
                  'Gérez les accès, les dossiers patients et les référentiels cliniques utilisés par les soignants et l’IA.',
                  style: context.text.bodyMedium?.copyWith(color: k.onHeroMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.lg),
          if (_statsError != null) ...[
            KBanner(
              tone: KTone.warning,
              title: 'Chiffres indisponibles',
              message: friendlyError(_statsError!),
              actionLabel: 'Réessayer',
              onAction: _loadStats,
            ),
            const SizedBox(height: KSpace.md),
          ],
          KSectionHeader(title: 'Personnes'),
          if (_loadingStats) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: KSpace.xs),
          for (final s in const [_Section.users, _Section.patients, _Section.facilities, _Section.medecins])
            _launcher(context, s),
          const SizedBox(height: KSpace.md),
          KSectionHeader(title: 'Référentiels cliniques'),
          const SizedBox(height: KSpace.xs),
          for (final s in const [_Section.symptoms, _Section.histories, _Section.touches]) _launcher(context, s),
          const SizedBox(height: KSpace.md),
          KSectionHeader(title: 'Traçabilité'),
          const SizedBox(height: KSpace.xs),
          _launcher(context, _Section.audit),
        ],
      ),
    );
  }

  Widget _launcher(BuildContext context, _Section s) {
    final k = context.k;
    final count = _counts?[s];
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.xs),
      child: KCard(
        onTap: () => _open(s),
        padding: const EdgeInsets.all(KSpace.sm),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: k.lagoon, borderRadius: KRadius.controlAll),
              child: Icon(s.icon, color: k.brand),
            ),
            const SizedBox(width: KSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(s.subtitle, style: context.text.bodySmall),
                  if (s == _Section.users && _pendingAccounts > 0) ...[
                    const SizedBox(height: 6),
                    KPill(
                      label: _pendingAccounts == 1
                          ? '1 inscription à valider'
                          : '$_pendingAccounts inscriptions à valider',
                      icon: Icons.hourglass_top_rounded,
                      tone: KTone.warning,
                      dense: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: KSpace.xs),
            if (s != _Section.audit)
              Semantics(
                label: count == null ? 'Nombre inconnu' : '$count éléments',
                child: ExcludeSemantics(
                  child: Text(
                    count == null ? '–' : '$count',
                    style: context.text.titleLarge?.copyWith(fontFamily: KFonts.mono),
                  ),
                ),
              ),
            Icon(Icons.chevron_right_rounded, color: k.inkMuted),
          ],
        ),
      ),
    );
  }

  Widget _sectionView(BuildContext context, _Section s) {
    final k = context.k;
    return Column(
      key: ValueKey(s),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(KSpace.xxs, KSpace.xxs, KSpace.gutter, KSpace.xs),
          decoration: BoxDecoration(color: k.surface, border: Border(bottom: BorderSide(color: k.line))),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Retour à la console',
                onPressed: () => _open(null),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title, style: context.text.titleLarge),
                    Text(s.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (s) {
            _Section.users => AdminUsersTab(repository: repository),
            _Section.patients => AdminPatientsTab(repository: repository),
            _Section.facilities => FacilitiesView(repository: repository),
            _Section.audit => AuditLogView(repository: repository),
            _Section.medecins => MedecinsTab(repository: repository),
            _Section.symptoms => ClinicalItemsTab(repository: repository, kind: ClinicalKind.symptom),
            _Section.histories => ClinicalItemsTab(repository: repository, kind: ClinicalKind.history),
            _Section.touches => ClinicalItemsTab(repository: repository, kind: ClinicalKind.touch),
          },
        ),
      ],
    );
  }
}
