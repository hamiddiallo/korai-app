import 'package:flutter/material.dart';

import '../../../../core/domain/korai_enums.dart';
import '../../domain/ai_case.dart';

typedef ExpertiseRequestCallback = Future<AiCase> Function(
  AiCase consultation, {
  String? summaryNote,
});

class ExpertiseRequestPanel extends StatefulWidget {
  const ExpertiseRequestPanel({
    super.key,
    required this.consultation,
    required this.onRequest,
    this.onUpdated,
    this.summaryNote,
  });

  final AiCase consultation;
  final ExpertiseRequestCallback onRequest;
  final ValueChanged<AiCase>? onUpdated;
  final String? summaryNote;

  @override
  State<ExpertiseRequestPanel> createState() => _ExpertiseRequestPanelState();
}

class _ExpertiseRequestPanelState extends State<ExpertiseRequestPanel> {
  bool submitting = false;

  Future<void> _submit() async {
    setState(() => submitting = true);
    try {
      final updated = await widget.onRequest(
        widget.consultation,
        summaryNote: widget.summaryNote,
      );
      if (!mounted) return;
      widget.onUpdated?.call(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande d\'expertise envoyée au spécialiste')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consultation;

    if (c.expertiseReview?.status == ExpertiseStatus.completed ||
        c.status == ConsultationStatus.specialistCompleted.value) {
      return const SizedBox.shrink();
    }

    if (c.expertiseInProgress) {
      return Card(
        color: Colors.blue.shade50,
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.hourglass_top, color: Colors.blue.shade800, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Demande d\'expertise en cours — en attente d\'avis spécialiste.',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!c.canRequestExpertise) return const SizedBox.shrink();

    return Card(
      color: const Color(0xFFE8F5E9),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Expertise spécialiste',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Soumettre cette consultation pour validation ou correction par un ORL.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: submitting ? null : _submit,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(submitting ? 'Envoi…' : 'Demander un avis spécialiste'),
            ),
          ],
        ),
      ),
    );
  }
}
