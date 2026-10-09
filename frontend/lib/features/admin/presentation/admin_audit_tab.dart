import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/refresh/live_refresh.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';
import 'admin_widgets.dart';

/// Libellé, icône et ton de chaque action du journal.
({String label, IconData icon, KTone tone}) auditActionStyle(String action) => switch (action) {
      'AUTH_LOGIN_SUCCEEDED' => (label: 'Connexion', icon: Icons.login_rounded, tone: KTone.neutral),
      'AUTH_LOGIN_FAILED' => (label: 'Connexion refusée', icon: Icons.no_accounts_outlined, tone: KTone.danger),
      'AUTH_PASSWORD_CHANGED' => (label: 'Mot de passe changé', icon: Icons.lock_reset_rounded, tone: KTone.info),
      'ACCESS_DENIED' => (label: 'Accès refusé', icon: Icons.gpp_bad_outlined, tone: KTone.danger),
      'PATIENTS_LISTED' => (label: 'Liste des patients ouverte', icon: Icons.groups_outlined, tone: KTone.neutral),
      'PATIENT_CREATED' => (label: 'Dossier créé', icon: Icons.person_add_alt_1_outlined, tone: KTone.info),
      'PATIENT_VIEWED' => (label: 'Dossier consulté', icon: Icons.visibility_outlined, tone: KTone.neutral),
      'PATIENT_UPDATED' => (label: 'Dossier modifié', icon: Icons.edit_outlined, tone: KTone.info),
      'PATIENT_CONSENT_CHANGED' => (label: 'Accords modifiés', icon: Icons.handshake_outlined, tone: KTone.warning),
      'PATIENT_VALIDATED' => (label: 'Dossier validé', icon: Icons.verified_outlined, tone: KTone.success),
      'CONSULTATIONS_LISTED' => (label: 'Consultations ouvertes', icon: Icons.event_note_outlined, tone: KTone.neutral),
      'CONSULTATION_CREATED' => (label: 'Consultation enregistrée', icon: Icons.note_add_outlined, tone: KTone.info),
      'CONSULTATION_AI_RETRIED' => (label: 'Analyse relancée', icon: Icons.refresh_rounded, tone: KTone.info),
      'EXPERTISE_INBOX_VIEWED' => (label: 'File d’avis ouverte', icon: Icons.inbox_outlined, tone: KTone.neutral),
      'EXPERTISE_REQUESTED' => (label: 'Avis demandé', icon: Icons.send_outlined, tone: KTone.info),
      'EXPERTISE_ASSIGNED' => (label: 'Dossier pris en charge', icon: Icons.assignment_ind_outlined, tone: KTone.info),
      'EXPERTISE_COMPLETED' => (label: 'Avis rendu', icon: Icons.task_alt_rounded, tone: KTone.success),
      'NURSE_REGISTRATION_APPROVED' => (
          label: 'Inscription validée',
          icon: Icons.how_to_reg_outlined,
          tone: KTone.success
        ),
      'NURSE_REGISTRATION_REJECTED' => (
          label: 'Inscription refusée',
          icon: Icons.person_off_outlined,
          tone: KTone.warning
        ),
      'ADMIN_USER_CREATED' => (label: 'Compte créé', icon: Icons.person_add_outlined, tone: KTone.info),
      'ADMIN_USER_UPDATED' => (label: 'Compte modifié', icon: Icons.manage_accounts_outlined, tone: KTone.info),
      'ADMIN_USER_DELETED' => (label: 'Compte supprimé', icon: Icons.person_remove_outlined, tone: KTone.warning),
      'ADMIN_USER_APPROVED' => (label: 'Compte activé', icon: Icons.verified_user_outlined, tone: KTone.success),
      'ADMIN_USER_REJECTED' => (label: 'Compte refusé', icon: Icons.person_off_outlined, tone: KTone.warning),
      'ADMIN_PATIENTS_LISTED' => (
          label: 'Dossiers ouverts (admin)',
          icon: Icons.folder_shared_outlined,
          tone: KTone.neutral
        ),
      'ADMIN_PATIENT_UPDATED' => (label: 'Dossier modifié (admin)', icon: Icons.edit_outlined, tone: KTone.info),
      'ADMIN_PATIENT_DELETED' => (
          label: 'Dossier mis à la corbeille',
          icon: Icons.delete_outline_rounded,
          tone: KTone.warning
        ),
      'ADMIN_PATIENT_RESTORED' => (label: 'Dossier restauré', icon: Icons.restore_rounded, tone: KTone.info),
      'ADMIN_PATIENT_CONSULTATIONS_VIEWED' => (
          label: 'Consultations consultées (admin)',
          icon: Icons.visibility_outlined,
          tone: KTone.neutral
        ),
      'ADMIN_CONSULTATION_DELETED' => (
          label: 'Consultation supprimée',
          icon: Icons.delete_outline_rounded,
          tone: KTone.warning
        ),
      'ADMIN_CONSULTATION_RESTORED' => (label: 'Consultation restaurée', icon: Icons.restore_rounded, tone: KTone.info),
      'AUDIT_VIEWED' => (label: 'Journal consulté', icon: Icons.policy_outlined, tone: KTone.neutral),
      _ => (label: action, icon: Icons.history_rounded, tone: KTone.neutral),
    };

const _roles = {'NURSE': 'soignant', 'SPECIALIST': 'spécialiste', 'PATIENT': 'patient', 'ADMIN': 'admin'};

/// Détail lisible, sans donnée de santé (le serveur n'en enregistre pas).
String? auditDetail(AuditEntry e) {
  final d = e.details;
  String yesNo(Object? v) => v == true ? 'oui' : 'non';
  return switch (e.action) {
    'PATIENT_CONSENT_CHANGED' =>
      'IA : ${yesNo(d['consentForAi'])} · télé-expertise : ${yesNo(d['consentForTeleExpertise'])}',
    'PATIENT_UPDATED' ||
    'ADMIN_PATIENT_UPDATED' when d['fields'] is List =>
      'Champs : ${(d['fields'] as List).join(', ')}',
    'ACCESS_DENIED' => '${d['method'] ?? ''} ${d['path'] ?? ''}'.trim(),
    'AUTH_LOGIN_FAILED' => d['email']?.toString(),
    'EXPERTISE_COMPLETED' when d['decision'] != null => 'Décision : ${d['decision']}',
    _ when d['count'] is num => (d['count'] as num) > 1 ? '${d['count']} éléments' : '${d['count']} élément',
    _ => null,
  };
}

/// Journal d'audit : toutes les actions, ou celles d'un seul dossier.
class AuditLogView extends StatefulWidget {
  const AuditLogView({super.key, required this.repository, this.patientId});

  final AdminRepository repository;

  /// Limite le journal à un dossier patient.
  final String? patientId;

  @override
  State<AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<AuditLogView> {
  final _entries = <AuditEntry>[];
  String? _nextBefore;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loadedOnce = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.listAudit(patientId: widget.patientId);
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(page.entries);
        _nextBefore = page.nextBefore;
        _loadedOnce = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final before = _nextBefore;
    if (before == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.listAudit(patientId: widget.patientId, before: before);
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.entries);
        _nextBefore = page.nextBefore;
      });
    } catch (e) {
      if (mounted) KSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return AdminListScaffold(
      loading: _loading,
      loadedOnce: _loadedOnce,
      error: _error,
      onRefresh: _load,
      createLabel: '',
      onCreate: null,
      emptyIcon: Icons.policy_outlined,
      emptyTitle: 'Journal vide',
      emptyMessage: widget.patientId == null
          ? 'Les connexions, consultations de dossiers et modifications apparaîtront ici.'
          : 'Aucune action enregistrée sur ce dossier pour l’instant.',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.sm, KSpace.gutter, 0),
        child: Text(
          'Aucune donnée médicale n’est enregistrée dans ce journal.',
          style: context.text.bodySmall?.copyWith(color: k.inkMuted),
        ),
      ),
      children: [
        for (final e in _entries) _AuditRow(entry: e, showPatient: widget.patientId == null),
        if (_nextBefore != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
            child: KAsyncButton(
              label: 'Afficher les actions plus anciennes',
              busyLabel: 'Chargement…',
              kind: KButtonKind.outlined,
              onPressed: _loadMore,
            ),
          ),
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry, required this.showPatient});

  final AuditEntry entry;
  final bool showPatient;

  @override
  Widget build(BuildContext context) {
    final style = auditActionStyle(entry.action);
    final who = entry.actorName == null
        ? 'Personne non connectée'
        : '${entry.actorName}${entry.actorRole == null ? '' : ' (${_roles[entry.actorRole] ?? entry.actorRole})'}';
    final lines = [
      who,
      if (showPatient && entry.patientName != null) 'Dossier : ${entry.patientName}',
      if (auditDetail(entry) case final detail?) detail,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.xs),
      child: KCard(
        padding: const EdgeInsets.all(KSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminLeadingIcon(icon: style.icon, tone: style.tone),
            const SizedBox(width: KSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(style.label, style: context.text.titleSmall)),
                      Text(adminDate(entry.createdAt),
                          style: context.text.bodySmall?.copyWith(fontFamily: KFonts.mono)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  for (final line in lines) Text(line, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Établissements : combien de soignants et de patients y sont rattachés.
class FacilitiesView extends StatefulWidget {
  const FacilitiesView({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<FacilitiesView> createState() => _FacilitiesViewState();
}

class _FacilitiesViewState extends State<FacilitiesView> with LiveReloadState {
  List<AdminFacility> _items = const [];
  bool _loading = false;
  bool _loadedOnce = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Relu au retour de l'application au premier plan (changements faits ailleurs).
  @override
  Future<void> liveReload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await widget.repository.listFacilities();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
          _loadedOnce = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String plural(int n, String one, String many) => n <= 1 ? '$n $one' : '$n $many';
    return AdminListScaffold(
      loading: _loading,
      loadedOnce: _loadedOnce,
      error: _error,
      onRefresh: _load,
      createLabel: '',
      onCreate: null,
      emptyIcon: Icons.local_hospital_outlined,
      emptyTitle: 'Aucun établissement',
      emptyMessage: 'Ils sont créés à l’inscription des soignants ou depuis la fiche d’un compte soignant.',
      children: [
        for (final f in _items)
          AdminRow(
            leading: const AdminLeadingIcon(icon: Icons.local_hospital_outlined, tone: KTone.info),
            title: f.name,
            subtitle:
                '${plural(f.nurseCount, 'soignant', 'soignants')} · ${plural(f.patientCount, 'patient', 'patients')}',
          ),
      ],
    );
  }
}
