import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../data/nurse_registration_repository.dart';

/// Écran de validation des demandes d'inscription des infirmiers encadrés
/// (côté spécialiste / admin).
class NurseRequestsPage extends StatefulWidget {
  const NurseRequestsPage({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<NurseRequestsPage> createState() => _NurseRequestsPageState();
}

class _NurseRequestsPageState extends State<NurseRequestsPage> {
  late final NurseRegistrationRepository _repository =
      NurseRegistrationRepository(widget.apiClient);

  List<NurseRequest> _requests = const [];
  bool _loading = true;
  String? _error;

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
      final requests = await _repository.list();
      if (mounted) setState(() => _requests = requests);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(NurseRequest r) async {
    await _act(() => _repository.approve(r.id), '${r.fullName} validé(e).');
  }

  Future<void> _reject(NurseRequest r) async {
    final reason = await _askReason();
    if (reason == null) return; // annulé
    await _act(
      () => _repository.reject(r.id, reason: reason),
      'Demande de ${r.fullName} refusée.',
    );
  }

  Future<void> _act(Future<void> Function() action, String successMsg) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(successMsg)));
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la demande'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Motif (optionnel)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests.where((r) => r.isPending).toList();
    final processed = _requests.where((r) => !r.isPending).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Demandes d'inscription"),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (pending.isEmpty && processed.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                              child: Text('Aucune demande d\'inscription.')),
                        ),
                      if (pending.isNotEmpty) ...[
                        Text('En attente (${pending.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        ...pending.map((r) => _RequestCard(
                              request: r,
                              onApprove: () => _approve(r),
                              onReject: () => _reject(r),
                            )),
                        const SizedBox(height: 16),
                      ],
                      if (processed.isNotEmpty) ...[
                        Text('Traitées',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.grey.shade700)),
                        const SizedBox(height: 8),
                        ...processed.map((r) => _RequestCard(request: r)),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, this.onApprove, this.onReject});

  final NurseRequest request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (request.accountStatus) {
      'ACTIVE' => (const Color(0xFF059669), 'Validé'),
      'REJECTED' => (const Color(0xFFEF4444), 'Refusé'),
      _ => (const Color(0xFFF59E0B), 'En attente'),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
            Row(
              children: [
                Expanded(
                  child: Text(request.fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(request.email,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            if (request.healthFacility != null)
              Text(request.healthFacility!,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (onApprove != null || onReject != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Refuser'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Valider'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
