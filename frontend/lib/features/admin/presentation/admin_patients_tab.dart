import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/refresh/live_refresh.dart';
import '../../../core/domain/korai_enums.dart';
import '../../../core/utils/diagnosis_text.dart';
import '../../../core/utils/patient_age.dart';
import '../../../core/utils/validators.dart';
import '../../nurse/presentation/widgets/ai_proposal_block.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';
import 'admin_widgets.dart';
import 'admin_audit_tab.dart';

enum _PatientsView { active, trash }

/// Dossiers patients : actifs et corbeille (restauration possible).
class AdminPatientsTab extends StatefulWidget {
  const AdminPatientsTab({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminPatientsTab> createState() => _AdminPatientsTabState();
}

class _AdminPatientsTabState extends State<AdminPatientsTab> with LiveReloadState {
  List<AdminPatient> _patients = const [];
  List<AdminPatient> _deleted = const [];
  bool _loading = true;
  bool _loadedOnce = false;
  Object? _error;
  _PatientsView _view = _PatientsView.active;

  AdminRepository get repo => widget.repository;

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
      final results = await Future.wait([repo.listPatients(), repo.listDeletedPatients()]);
      if (!mounted) return;
      setState(() {
        _patients = results[0];
        _deleted = results[1];
        _error = null;
        _loadedOnce = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final saved = await showPatientFormSheet(context, repository: repo);
    if (saved == null || !mounted) return;
    KSnack.success(context, 'Dossier de ${saved.fullName} créé.');
    _load();
  }

  Future<void> _edit(AdminPatient p) async {
    final saved = await showPatientFormSheet(context, repository: repo, patient: p);
    if (saved == null || !mounted) return;
    KSnack.success(context, 'Dossier de ${saved.fullName} mis à jour.');
    _load();
  }

  Future<void> _delete(AdminPatient p) async {
    final done = await deletePatientWithUndo(context, repository: repo, patient: p, onChanged: _load);
    if (done) _load();
  }

  Future<void> _restore(AdminPatient p) async {
    try {
      await repo.restorePatient(p.id);
      if (!mounted) return;
      KSnack.success(context, 'Dossier de ${p.fullName} restauré.');
      _load();
    } catch (e) {
      if (mounted) KSnack.error(context, e);
    }
  }

  Future<void> _open(AdminPatient p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminPatientDossierPage(repository: repo, patient: p, onChanged: _load)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final trash = _view == _PatientsView.trash;
    final list = trash ? _deleted : _patients;
    return AdminListScaffold(
      loading: _loading,
      loadedOnce: _loadedOnce,
      error: _error,
      onRefresh: _load,
      createLabel: 'Nouveau patient',
      onCreate: trash ? null : _create,
      emptyIcon: trash ? Icons.delete_outline_rounded : Icons.folder_shared_outlined,
      emptyTitle: trash ? 'Corbeille vide' : 'Aucun dossier patient',
      emptyMessage: trash
          ? 'Les dossiers supprimés apparaissent ici et peuvent être restaurés.'
          : 'Les dossiers créés par les soignants ou les patients apparaîtront ici.',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.xs),
        child: KSegmented<_PatientsView>(
          segments: [
            KSegment(value: _PatientsView.active, label: 'Actifs', count: _patients.length),
            KSegment(value: _PatientsView.trash, label: 'Corbeille', count: _deleted.length),
          ],
          value: _view,
          onChanged: (v) => setState(() => _view = v),
        ),
      ),
      children: [
        for (final p in list)
          trash
              ? AdminRow(
                  leading: const AdminLeadingIcon(icon: Icons.delete_sweep_outlined, tone: KTone.danger),
                  title: p.fullName,
                  subtitle: 'Supprimé le ${adminDate(p.deletedAt)}',
                  trailing: TextButton.icon(
                    onPressed: () => _restore(p),
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restaurer'),
                  ),
                )
              : AdminRow(
                  leading: KInitialsAvatar(name: p.fullName, size: 40),
                  title: p.fullName,
                  subtitle: [
                    PatientAge.label(p.birthDate),
                    if (p.phone?.trim().isNotEmpty ?? false) p.phone!,
                  ].join(' · '),
                  footer: ConsentPills(ai: p.consentForAi, teleExpertise: p.consentForTeleExpertise),
                  onTap: () => _open(p),
                  onEdit: () => _edit(p),
                  onDelete: () => _delete(p),
                ),
      ],
    );
  }
}

/// Supprime un dossier (corbeille) avec « Annuler » dans le message.
Future<bool> deletePatientWithUndo(
  BuildContext context, {
  required AdminRepository repository,
  required AdminPatient patient,
  required VoidCallback onChanged,
}) async {
  final ok = await confirmDelete(
    context,
    title: 'Supprimer ce dossier ?',
    message: 'Le dossier de ${patient.fullName} et ses consultations iront dans la corbeille. '
        'Vous pourrez les restaurer.',
  );
  if (!ok || !context.mounted) return false;
  try {
    await repository.deletePatient(patient.id);
    if (!context.mounted) return true;
    KSnack.show(
      context,
      'Dossier de ${patient.fullName} placé dans la corbeille.',
      tone: KTone.success,
      actionLabel: 'Annuler',
      onAction: () async {
        try {
          await repository.restorePatient(patient.id);
          onChanged();
        } catch (e) {
          if (context.mounted) KSnack.error(context, e);
        }
      },
    );
    return true;
  } catch (e) {
    if (context.mounted) KSnack.error(context, e);
    return false;
  }
}

/// Création ou modification d'un dossier patient. Renvoie le dossier
/// enregistré, ou `null` si l'utilisateur a fermé la feuille.
Future<AdminPatient?> showPatientFormSheet(
  BuildContext context, {
  required AdminRepository repository,
  AdminPatient? patient,
}) async {
  final isNew = patient == null;
  final firstName = TextEditingController(text: patient?.firstName);
  final lastName = TextEditingController(text: patient?.lastName);
  final initialAge = PatientAge.years(patient?.birthDate)?.toString() ?? '';
  final age = TextEditingController(text: initialAge);
  final phone = TextEditingController(text: patient?.phone);
  final address = TextEditingController(text: patient?.address);
  var sex = patient?.sex == 'M' ? 'M' : 'F';
  // Aucun accord supposé : l'admin coche seulement ce que le patient a accepté.
  var consentAi = patient?.consentForAi ?? false;
  var consentTele = patient?.consentForTeleExpertise ?? false;
  var facilityId = patient?.facilityId;
  final facilities = await repository.listFacilities().catchError((_) => <AdminFacility>[]);
  if (!context.mounted) return null;
  AdminPatient? saved;

  await showAdminFormSheet(
    context,
    title: isNew ? 'Nouveau patient' : 'Modifier le dossier',
    submitLabel: isNew ? 'Créer le dossier' : 'Enregistrer',
    fields: (context, setState) => [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: lastName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: (v) => KValidators.required(v, 'Nom'),
            ),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: TextFormField(
              controller: firstName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Prénom'),
              validator: (v) => KValidators.required(v, 'Prénom'),
            ),
          ),
        ],
      ),
      const SizedBox(height: KSpace.sm),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: TextFormField(
              controller: age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Âge', suffixText: 'ans'),
              validator: (v) => KValidators.age(v, required: false),
            ),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: KSegmented<String>(
              segments: const [
                KSegment(value: 'F', label: 'Féminin'),
                KSegment(value: 'M', label: 'Masculin'),
              ],
              value: sex,
              onChanged: (v) => setState(() => sex = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: KSpace.sm),
      TextFormField(
        controller: phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Téléphone (facultatif)', prefixIcon: Icon(Icons.phone_outlined)),
        validator: KValidators.phoneOptional,
      ),
      const SizedBox(height: KSpace.sm),
      TextFormField(
        controller: address,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Adresse (facultatif)', prefixIcon: Icon(Icons.place_outlined)),
      ),
      const SizedBox(height: KSpace.xs),
      if (facilities.isNotEmpty) ...[
        const SizedBox(height: KSpace.sm),
        DropdownButtonFormField<String?>(
          initialValue: facilities.any((f) => f.id == facilityId) ? facilityId : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Établissement',
            helperText: 'Ses soignants voient ce dossier.',
            prefixIcon: Icon(Icons.local_hospital_outlined),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Non rattaché')),
            for (final f in facilities) DropdownMenuItem<String?>(value: f.id, child: Text(f.name)),
          ],
          onChanged: (v) => setState(() => facilityId = v),
        ),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Consentement à l’analyse IA'),
        subtitle: const Text('Les consultations peuvent être analysées par l’IA.'),
        value: consentAi,
        onChanged: (v) => setState(() => consentAi = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Consentement à la télé-expertise'),
        subtitle: const Text('Le dossier peut être partagé avec un spécialiste Korai.'),
        value: consentTele,
        onChanged: (v) => setState(() => consentTele = v),
      ),
    ],
    controllers: [firstName, lastName, age, phone, address],
    onSubmit: () async {
      final ageText = age.text.trim();
      final data = <String, dynamic>{
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        // Ne réécrit l'âge que s'il a changé (préserve une vraie date de naissance).
        if (ageText != initialAge && ageText.isNotEmpty) 'birthDate': 'Age: $ageText ans',
        'sex': sex,
        if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
        if (address.text.trim().isNotEmpty) 'address': address.text.trim(),
        'consentForAi': consentAi,
        'consentForTeleExpertise': consentTele,
      };
      if (isNew) {
        final created = await repository.createPatient(data);
        saved = facilityId == null ? created : await repository.updatePatient(created.id, {'facilityId': facilityId});
      } else {
        saved = await repository.updatePatient(patient.id, {
          ...data,
          if (facilityId != null && facilityId != patient.facilityId) 'facilityId': facilityId,
        });
      }
    },
  );
  return saved;
}

// ---------------------------------------------------------------------------
// Dossier d'un patient
// ---------------------------------------------------------------------------

class AdminPatientDossierPage extends StatefulWidget {
  const AdminPatientDossierPage({super.key, required this.repository, required this.patient, required this.onChanged});

  final AdminRepository repository;
  final AdminPatient patient;

  /// Rafraîchit la liste des patients (après « Annuler » une suppression).
  final VoidCallback onChanged;

  @override
  State<AdminPatientDossierPage> createState() => _AdminPatientDossierPageState();
}

class _AdminPatientDossierPageState extends State<AdminPatientDossierPage> with LiveReloadState {
  late AdminPatient _patient = widget.patient;
  List<AdminConsultation> _consultations = const [];
  bool _loading = true;
  Object? _error;

  AdminRepository get repo => widget.repository;

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
      final list = await repo.listPatientConsultations(_patient.id);
      if (mounted) {
        setState(() {
          _consultations = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final saved = await showPatientFormSheet(context, repository: repo, patient: _patient);
    if (saved == null || !mounted) return;
    setState(() => _patient = saved);
    KSnack.success(context, 'Dossier de ${saved.fullName} mis à jour.');
  }

  Future<void> _deletePatient() async {
    final done = await deletePatientWithUndo(context, repository: repo, patient: _patient, onChanged: widget.onChanged);
    if (done && mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteConsultation(AdminConsultation c) async {
    final ok = await confirmDelete(
      context,
      title: 'Supprimer cette consultation ?',
      message: 'Consultation du ${adminDate(c.createdAt)}. Vous pourrez l’annuler juste après.',
    );
    if (!ok || !mounted) return;
    try {
      await repo.deleteConsultation(c.id);
      if (!mounted) return;
      KSnack.show(
        context,
        'Consultation supprimée.',
        tone: KTone.success,
        actionLabel: 'Annuler',
        onAction: () async {
          try {
            await repo.restoreConsultation(c.id);
            _load();
          } catch (e) {
            if (mounted) KSnack.error(context, e);
          }
        },
      );
      _load();
    } catch (e) {
      if (mounted) KSnack.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _patient;
    final k = context.k;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dossier patient'),
        actions: [
          IconButton(
            tooltip: 'Journal du dossier',
            icon: const Icon(Icons.policy_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text('Journal · ${_patient.fullName}')),
                  body: AuditLogView(repository: repo, patientId: _patient.id),
                ),
              ),
            ),
          ),
          IconButton(tooltip: 'Modifier le dossier', onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            tooltip: 'Supprimer le dossier',
            onPressed: _deletePatient,
            icon: Icon(Icons.delete_outline_rounded, color: k.danger),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.xl),
          children: [
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      KInitialsAvatar(name: p.fullName, size: 56),
                      const SizedBox(width: KSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.fullName, style: context.text.headlineSmall),
                            Text(
                              [
                                if (KLabels.sexOrNull(p.sex) != null) KLabels.sexOrNull(p.sex)!,
                                PatientAge.label(p.birthDate)
                              ].join(' · '),
                              style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpace.sm),
                  KInfoRow(label: 'Téléphone', value: _or(p.phone)),
                  KInfoRow(label: 'Adresse', value: _or(p.address)),
                  const SizedBox(height: KSpace.xs),
                  ConsentPills(ai: p.consentForAi, teleExpertise: p.consentForTeleExpertise),
                ],
              ),
            ),
            const SizedBox(height: KSpace.lg),
            KSectionHeader(title: 'Consultations', count: _consultations.isEmpty ? null : _consultations.length),
            const SizedBox(height: KSpace.xs),
            if (_loading && _consultations.isEmpty)
              const KSkeletonList(count: 2, padding: EdgeInsets.zero)
            else if (_error != null)
              KErrorView(
                  title: 'Les consultations n’ont pas pu être chargées', error: _error!, onRetry: _load, compact: true)
            else if (_consultations.isEmpty)
              const KEmptyView(
                icon: Icons.event_note_outlined,
                title: 'Aucune consultation',
                message: 'Les consultations de ce patient apparaîtront ici.',
                compact: true,
              )
            else
              for (final c in _consultations) ...[
                _ConsultationRow(
                  consultation: c,
                  onTap: () => showAdminConsultationSheet(context, c, onDelete: () => _deleteConsultation(c)),
                ),
                const SizedBox(height: KSpace.xs),
              ],
          ],
        ),
      ),
    );
  }

  static String _or(String? v) => (v == null || v.trim().isEmpty) ? 'Non renseigné' : v;
}

class _ConsultationRow extends StatelessWidget {
  const _ConsultationRow({required this.consultation, required this.onTap});

  final AdminConsultation consultation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final c = consultation;
    final urgency = KUrgency.parse(c.urgency);
    final diagnosis = c.likelyDiagnosis;
    return KCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: urgency == null ? k.line : KUrgency.color(context, urgency)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(KSpace.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(adminDate(c.createdAt),
                              style: context.text.titleSmall?.copyWith(fontFamily: KFonts.mono)),
                        ),
                        KUrgencyPill(level: urgency, dense: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.symptomLabels.isNotEmpty ? c.symptomLabels.join(', ') : 'Symptômes non renseignés',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium,
                    ),
                    if (diagnosis != null && !DiagnosisText.isTechnicalFailure(diagnosis)) ...[
                      const SizedBox(height: 4),
                      Text(
                        DiagnosisText.headline(diagnosis),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: k.aquaInk, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: KSpace.xs),
              child: Icon(Icons.chevron_right_rounded, color: k.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Détail d'une consultation (lecture seule) avec suppression.
void showAdminConsultationSheet(BuildContext context, AdminConsultation c, {required VoidCallback onDelete}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final k = sheetContext.k;
      final diagnosis = c.likelyDiagnosis;
      final hasDiagnosis =
          diagnosis != null && diagnosis.trim().isNotEmpty && !DiagnosisText.isTechnicalFailure(diagnosis);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.xl),
          children: [
            Row(
              children: [
                Expanded(child: Text('Consultation', style: context.text.headlineSmall)),
                IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded)),
              ],
            ),
            Text(adminDate(c.createdAt),
                style: context.text.bodyMedium?.copyWith(color: k.inkMuted, fontFamily: KFonts.mono)),
            const SizedBox(height: KSpace.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                KConsultationStatusPill(status: c.status, dense: true),
                KUrgencyPill(level: KUrgency.parse(c.urgency), prefix: 'Urgence', dense: true),
              ],
            ),
            const SizedBox(height: KSpace.md),
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Symptômes déclarés', style: context.text.titleMedium),
                  const SizedBox(height: KSpace.xs),
                  if (c.symptomLabels.isEmpty)
                    Text('Aucun symptôme déclaré.', style: context.text.bodyMedium?.copyWith(color: k.inkMuted))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final s in c.symptomLabels) KPill(label: s, tone: KTone.brand, dense: true)],
                    ),
                  const SizedBox(height: KSpace.md),
                  Text('Description clinique', style: context.text.titleMedium),
                  const SizedBox(height: KSpace.xs),
                  Text(
                    c.clinicalNarrative.isNotEmpty ? c.clinicalNarrative : 'Aucune description.',
                    style: context.text.bodyMedium,
                  ),
                ],
              ),
            ),
            if (c.otoscopicImages.isNotEmpty) ...[
              const SizedBox(height: KSpace.sm),
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Images de l’oreille', style: context.text.titleMedium),
                    for (final img in c.otoscopicImages) ...[
                      const SizedBox(height: KSpace.xs),
                      KEarTag(side: EarSide.fromApi(img.earSide), long: true),
                      Text(
                        img.description?.trim().isNotEmpty ?? false ? img.description! : 'Sans description.',
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: KSpace.sm),
            if (hasDiagnosis)
              KAuthorBlock.ai(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DiagnosisText.headline(diagnosis), style: context.text.titleMedium),
                    if (DiagnosisText.hasDetails(diagnosis)) FullReport(text: diagnosis),
                  ],
                ),
              )
            else
              const KBanner(
                tone: KTone.neutral,
                icon: Icons.cloud_off_rounded,
                title: 'Pas de diagnostic IA',
                message: 'L’analyse n’a pas été faite ou n’a pas abouti pour cette consultation.',
              ),
            const SizedBox(height: KSpace.lg),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: k.danger, side: BorderSide(color: k.danger)),
              onPressed: () {
                Navigator.pop(sheetContext);
                onDelete();
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Supprimer la consultation'),
            ),
          ],
        ),
      );
    },
  );
}
