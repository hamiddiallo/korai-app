import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/design/design.dart';
import '../../../core/refresh/live_refresh.dart';
import '../../../core/utils/consultation_format.dart';
import '../data/nurse_registration_repository.dart';

enum _Tab { pending, processed }

/// Validation des demandes d'inscription des infirmier·ères encadré·es
/// (côté spécialiste / admin).
class NurseRequestsPage extends StatefulWidget {
  const NurseRequestsPage({super.key, required this.apiClient, this.embedded = false, this.onPendingCountChanged});

  final ApiClient apiClient;

  /// Nombre de demandes en attente après chaque chargement (badge de navigation).
  final ValueChanged<int>? onPendingCountChanged;

  /// `true` quand l'écran est un onglet (pas de barre d'application propre).
  final bool embedded;

  @override
  State<NurseRequestsPage> createState() => _NurseRequestsPageState();
}

class _NurseRequestsPageState extends State<NurseRequestsPage> with LiveReloadState {
  late final NurseRegistrationRepository _repository = NurseRegistrationRepository(widget.apiClient);

  List<NurseRequest> _requests = const [];
  bool _loading = true;
  bool _loadedOnce = false;
  Object? _error;
  _Tab _tab = _Tab.pending;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Une nouvelle demande d'inscription est notifiée à l'encadrant.
  @override
  Set<LiveTopic> get liveTopics => const {LiveTopic.registrations};

  @override
  Future<void> liveReload() => _load();

  /// Relit les demandes, une lecture à la fois ; celles déjà affichées restent
  /// visibles pendant la lecture.
  Future<void> _load() => _reload();

  late final _reload = SerialRefresh(_fetch);

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final requests = await _repository.list();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _error = null;
        _loadedOnce = true;
      });
      widget.onPendingCountChanged?.call(requests.where((r) => r.isPending).length);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(NurseRequest r) async {
    final ok = await showKConfirm(
      context,
      title: 'Valider l’inscription ?',
      message: '${r.fullName} pourra se connecter et enregistrer des consultations sous votre encadrement.',
      confirmLabel: 'Valider',
    );
    if (!ok) return;
    await _act(r, () => _repository.approve(r.id), '${r.fullName} peut maintenant se connecter.');
  }

  Future<void> _reject(NurseRequest r) async {
    final reason = await _askReason(r);
    if (reason == null) return;
    await _act(r, () => _repository.reject(r.id, reason: reason), 'Demande de ${r.fullName} refusée.');
  }

  Future<void> _act(NurseRequest r, Future<void> Function() action, String successMsg) async {
    setState(() => _busy.add(r.id));
    try {
      await action();
      if (!mounted) return;
      KSnack.success(context, successMsg);
      await _load();
    } catch (e) {
      if (mounted) KSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<String?> _askReason(NurseRequest r) {
    return showKReasonDialog(
      context,
      title: 'Refuser la demande',
      message: '${r.fullName} verra ce motif lors de sa prochaine tentative de connexion.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests.where((r) => r.isPending).toList();
    final processed = _requests.where((r) => !r.isPending).toList();
    final list = _tab == _Tab.pending ? pending : processed;

    final Widget body;
    if (!_loadedOnce && _loading) {
      body = const KSkeletonList(count: 3);
    } else if (!_loadedOnce && _error != null) {
      body = KErrorView(error: _error!, onRetry: _load);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, 120),
          children: [
            if (_error != null) ...[
              KBanner(
                tone: KTone.warning,
                title: 'Liste peut-être incomplète',
                message: friendlyError(_error!),
                actionLabel: 'Réessayer',
                onAction: _load,
              ),
              const SizedBox(height: KSpace.sm),
            ],
            KSegmented<_Tab>(
              segments: [
                KSegment(value: _Tab.pending, label: 'En attente', count: pending.length),
                KSegment(value: _Tab.processed, label: 'Traitées', count: processed.length),
              ],
              value: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: KSpace.md),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: KSpace.xl),
                child: KEmptyView(
                  icon: _tab == _Tab.pending ? Icons.how_to_reg_outlined : Icons.history_rounded,
                  title: _tab == _Tab.pending ? 'Aucune demande en attente' : 'Aucune demande traitée',
                  message: _tab == _Tab.pending
                      ? 'Les infirmier·ères qui s’inscrivent avec votre matricule apparaîtront ici.'
                      : 'Les demandes validées ou refusées apparaîtront ici.',
                ),
              )
            else
              for (final r in list) ...[
                _RequestCard(
                  request: r,
                  busy: _busy.contains(r.id),
                  onApprove: r.isPending ? () => _approve(r) : null,
                  onReject: r.isPending ? () => _reject(r) : null,
                ),
                const SizedBox(height: KSpace.sm),
              ],
          ],
        ),
      );
    }

    if (widget.embedded) {
      return Column(
        children: [
          KScreenHeader(
            eyebrow: 'Encadrement',
            title: 'Inscriptions',
            trailing: [
              IconButton(tooltip: 'Actualiser', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes d’inscription'),
        actions: [
          IconButton(tooltip: 'Actualiser', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: body,
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.busy, this.onApprove, this.onReject});

  final NurseRequest request;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final status = request.accountStatus;
    final statusIcon = switch (status) {
      'ACTIVE' => Icons.check_circle_rounded,
      'REJECTED' => Icons.block_rounded,
      _ => Icons.hourglass_top_rounded,
    };
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KInitialsAvatar(name: request.fullName),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.fullName, style: context.text.titleSmall),
                    Text(request.email, style: context.text.bodySmall),
                  ],
                ),
              ),
              KPill(
                label: KLabels.accountStatus(status),
                icon: statusIcon,
                tone: KLabels.accountStatusTone(status),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: KSpace.sm),
          if (request.healthFacility != null && request.healthFacility!.trim().isNotEmpty)
            _Line(icon: Icons.local_hospital_outlined, text: request.healthFacility!),
          if (request.phone != null && request.phone!.trim().isNotEmpty)
            _Line(icon: Icons.phone_outlined, text: request.phone!),
          if (request.createdAt != null)
            _Line(icon: Icons.event_outlined, text: 'Demande du ${ConsultationFormat.formatDate(request.createdAt)}'),
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: KSpace.sm),
            if (busy)
              const KLoadingView(message: 'Enregistrement de votre décision…', compact: true)
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Refuser'),
                      style: OutlinedButton.styleFrom(foregroundColor: k.danger),
                    ),
                  ),
                  const SizedBox(width: KSpace.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Valider'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.k.inkMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: context.text.bodySmall)),
        ],
      ),
    );
  }
}
