import 'package:flutter/material.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/domain/korai_enums.dart';
import '../../../core/utils/consultation_format.dart';
import '../../nurse/domain/ai_case.dart';
import '../../nurse/presentation/widgets/consultation_history_list.dart';
import '../data/specialist_repository.dart';
import 'widgets/specialist_expandable_section.dart';

class SpecialistHomePage extends StatefulWidget {
  const SpecialistHomePage({super.key, required this.session});

  final SessionController session;

  @override
  State<SpecialistHomePage> createState() => _SpecialistHomePageState();
}

class _SpecialistHomePageState extends State<SpecialistHomePage> {
  late final SpecialistRepository repository;
  List<ExpertiseInboxItem> inbox = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    repository = SpecialistRepository(widget.session.apiClient);
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final items = await repository.listInbox();
      if (!mounted) return;
      setState(() {
        inbox = items;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _openCase(ExpertiseInboxItem item) async {
    final caseData = await repository.findCase(item.consultationId);
    if (!mounted) return;
    if (caseData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dossier introuvable')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpecialistReviewPage(
          session: widget.session,
          repository: repository,
          consultation: caseData,
          inboxItem: item,
          onCompleted: _loadInbox,
        ),
      ),
    );
    _loadInbox();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expertise ORL'),
        actions: [
          IconButton(onPressed: _loadInbox, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () => widget.session.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!, textAlign: TextAlign.center))
              : inbox.isEmpty
                  ? const Center(child: Text('Aucun dossier en attente d\'expertise.'))
                  : RefreshIndicator(
                      onRefresh: _loadInbox,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: inbox.length,
                        itemBuilder: (context, index) {
                          final item = inbox[index];
                          final isMine = item.assignedToUserId == widget.session.user?.id;
                          return _InboxRequestCard(
                            item: item,
                            isMine: isMine,
                            statusLabel: _statusLabel(item.status),
                            onOpen: () => _openCase(item),
                          );
                        },
                      ),
                    ),
    );
  }

  String _statusLabel(ExpertiseStatus status) => switch (status) {
        ExpertiseStatus.pending => 'En attente',
        ExpertiseStatus.inReview => 'En cours',
        ExpertiseStatus.completed => 'Terminé',
      };
}

class _InboxRequestCard extends StatelessWidget {
  const _InboxRequestCard({
    required this.item,
    required this.isMine,
    required this.statusLabel,
    required this.onOpen,
  });

  final ExpertiseInboxItem item;
  final bool isMine;
  final String statusLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: (isMine ? Colors.blue : Colors.teal).withValues(alpha: 0.12),
            child: Icon(
              isMine ? Icons.edit_note : Icons.inbox_outlined,
              size: 20,
              color: isMine ? Colors.blue.shade800 : const Color(0xFF006D77),
            ),
          ),
          title: Text(
            item.patientLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            '$statusLabel · ${ConsultationFormat.formatDateTime(item.createdAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          children: [
            if (item.aiDiagnosis != null && item.aiDiagnosis!.trim().isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'IA : ${item.aiDiagnosis}',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (isMine)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  'Dossier assigné à vous',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ouvrir le dossier'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpecialistReviewPage extends StatefulWidget {
  const SpecialistReviewPage({
    super.key,
    required this.session,
    required this.repository,
    required this.consultation,
    required this.inboxItem,
    required this.onCompleted,
  });

  final SessionController session;
  final SpecialistRepository repository;
  final AiCase consultation;
  final ExpertiseInboxItem inboxItem;
  final VoidCallback onCompleted;

  @override
  State<SpecialistReviewPage> createState() => _SpecialistReviewPageState();
}

class _SpecialistReviewPageState extends State<SpecialistReviewPage> {
  ExpertDecision decision = ExpertDecision.validated;
  final commentController = TextEditingController();
  final diagnosisController = TextEditingController();
  final recommendationController = TextEditingController();
  final clinicalSummaryController = TextEditingController();
  bool submitting = false;
  bool assigned = false;
  String? assignError;

  @override
  void initState() {
    super.initState();
    assigned = widget.inboxItem.status == ExpertiseStatus.inReview &&
        widget.inboxItem.assignedToUserId == widget.session.user?.id;
    diagnosisController.text = widget.consultation.summary.likelyDiagnosis ?? '';
  }

  @override
  void dispose() {
    commentController.dispose();
    diagnosisController.dispose();
    recommendationController.dispose();
    clinicalSummaryController.dispose();
    super.dispose();
  }

  Future<void> _takeCharge() async {
    setState(() {
      submitting = true;
      assignError = null;
    });
    try {
      await widget.repository.assign(widget.consultation.id);
      if (!mounted) return;
      setState(() {
        assigned = true;
        submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dossier pris en charge')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        assignError = e.toString();
        submitting = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!assigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prenez d\'abord en charge le dossier')),
      );
      return;
    }
    setState(() => submitting = true);
    try {
      await widget.repository.submitReview(
        widget.consultation.id,
        decision: decision,
        comment: commentController.text.trim(),
        correctedLikelyDiagnosis: diagnosisController.text.trim(),
        correctedRecommendation: recommendationController.text.trim(),
        correctedClinicalSummary: clinicalSummaryController.text.trim(),
      );
      if (!mounted) return;
      widget.onCompleted();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avis enregistré')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consultation;
    final review = c.expertiseReview;
    final snapshot = review?.aiSnapshot;
    final aiDiag = c.summary.likelyDiagnosis ?? snapshot?.likelyDiagnosis ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.inboxItem.patientLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              _statusLabel(widget.inboxItem.status),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.inboxItem.patientLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  _HeaderChip(
                    icon: Icons.schedule,
                    label: ConsultationFormat.formatDateTime(widget.inboxItem.createdAt),
                  ),
                  const SizedBox(height: 4),
                  _HeaderChip(icon: Icons.psychology_outlined, label: 'IA : $aiDiag'),
                  if (review?.summaryNote != null && review!.summaryNote!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Note infirmier : ${review.summaryNote}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!assigned) ...[
            const SizedBox(height: 8),
            Card(
              color: Colors.orange.shade50,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Prise en charge requise',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Obligatoire avant de rédiger votre avis.',
                      style: TextStyle(fontSize: 12),
                    ),
                    if (assignError != null) ...[
                      const SizedBox(height: 6),
                      Text(assignError!, style: TextStyle(color: Colors.red.shade700, fontSize: 11)),
                    ],
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: submitting ? null : _takeCharge,
                      child: submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Prendre en charge'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          if (review?.summaryNote != null && review!.summaryNote!.trim().isNotEmpty)
            SpecialistExpandableSection(
              title: 'Transmission infirmier',
              subtitle: 'Note à l\'escalade',
              icon: Icons.notes_outlined,
              children: [
                Text(review.summaryNote!, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          if (snapshot != null)
            SpecialistExpandableSection(
              title: 'Snapshot IA (à la demande)',
              subtitle: snapshot.likelyDiagnosis ?? 'Voir le détail',
              icon: Icons.history,
              children: [_SnapshotDetails(snapshot: snapshot)],
            ),
          SpecialistExpandableSection(
            title: 'Analyse IA et dossier',
            subtitle: aiDiag,
            icon: Icons.folder_open_outlined,
            children: [
              ConsultationDiagnosticDetails(consultation: c),
            ],
          ),
          SpecialistExpandableSection(
            title: 'Votre avis',
            subtitle: decision.label,
            icon: Icons.medical_services_outlined,
            initiallyExpanded: assigned,
            children: [
              DropdownButtonFormField<ExpertDecision>(
                key: ValueKey(decision),
                initialValue: decision,
                decoration: const InputDecoration(
                  labelText: 'Décision',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: ExpertDecision.values
                    .map((d) => DropdownMenuItem(value: d, child: Text(d.label)))
                    .toList(),
                onChanged: assigned && !submitting ? (v) => setState(() => decision = v!) : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Commentaire libre',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
                enabled: assigned && !submitting,
              ),
              if (decision == ExpertDecision.corrected || decision == ExpertDecision.insufficient) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: diagnosisController,
                  decoration: InputDecoration(
                    labelText: decision == ExpertDecision.insufficient
                        ? 'Diagnostic (optionnel)'
                        : 'Diagnostic corrigé *',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  enabled: assigned && !submitting,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: clinicalSummaryController,
                  decoration: const InputDecoration(
                    labelText: 'Synthèse clinique *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 4,
                  enabled: assigned && !submitting,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: recommendationController,
                decoration: const InputDecoration(
                  labelText: 'Recommandation',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
                enabled: assigned && !submitting,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: assigned && !submitting ? _submit : null,
                  child: submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Soumettre l\'avis'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _statusLabel(ExpertiseStatus status) => switch (status) {
        ExpertiseStatus.pending => 'En attente',
        ExpertiseStatus.inReview => 'En cours',
        ExpertiseStatus.completed => 'Terminé',
      };
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SnapshotDetails extends StatelessWidget {
  const _SnapshotDetails({required this.snapshot});

  final AiSummarySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (snapshot.likelyDiagnosis != null)
          _SnapshotLine('Diagnostic', snapshot.likelyDiagnosis!),
        if (snapshot.confidenceLabel != null)
          _SnapshotLine('Confiance', snapshot.confidenceLabel!),
        if (snapshot.imageOpinion != null)
          _SnapshotBlock('Avis image', snapshot.imageOpinion!),
        if (snapshot.ragOpinion != null)
          _SnapshotBlock('Avis RAG', snapshot.ragOpinion!),
        if (snapshot.warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Alertes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ...snapshot.warnings.map((w) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $w', style: const TextStyle(fontSize: 12)),
              )),
        ],
      ],
    );
  }
}

class _SnapshotLine extends StatelessWidget {
  const _SnapshotLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: Colors.grey.shade900),
          children: [
            TextSpan(text: '$label : ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _SnapshotBlock extends StatelessWidget {
  const _SnapshotBlock(this.label, this.text);

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }
}
