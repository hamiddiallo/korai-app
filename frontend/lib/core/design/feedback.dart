import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import 'korai_tokens.dart';

/// Traduit n'importe quelle erreur en message clair pour l'utilisateur :
/// ce qui s'est passé et quoi faire. Jamais d'exception brute à l'écran.
String friendlyError(Object error) {
  if (error is ApiException) return _fromApi(error);
  if (kDebugMode) debugPrint('Erreur non gérée : $error');
  return 'Une erreur inattendue s’est produite. Réessayez ; si le problème '
      'continue, contactez l’administrateur.';
}

String _fromApi(ApiException e) {
  // Messages déjà rédigés côté client (réseau, IA).
  if (e.isNetworkFailure || e.isAiUnavailable || e.code == 'AI_BAD_REQUEST') {
    return e.message;
  }
  switch (e.code) {
    // Messages du serveur déjà rédigés pour la personne concernée (ce qu'il
    // faut faire est dit dans le message).
    case 'ACCOUNT_PENDING':
    case 'ACCOUNT_REJECTED':
    case 'SESSION_EXPIRED':
    case 'TOO_MANY_REQUESTS':
    case 'CONSENT_AI_REQUIRED':
    case 'CONSENT_TELEEXPERTISE_REQUIRED':
    case 'FACILITY_CHANGE_FORBIDDEN':
      return e.message;
    case 'OUT_OF_SCOPE':
      return 'Ce dossier n’est pas rattaché à votre établissement : vous ne pouvez pas y accéder. '
          'Si c’est une erreur, contactez l’administrateur.';
    case 'FACILITY_NOT_FOUND':
      return 'Cet établissement n’existe plus. Actualisez la liste et choisissez-en un autre.';
    case 'ACCOUNT_NOT_PENDING':
      return 'Ce compte a déjà été traité. Actualisez la liste.';
    case 'UNAUTHORIZED':
      return e.message.toLowerCase().contains('mot de passe')
          ? 'E-mail ou mot de passe incorrect. Vérifiez vos identifiants.'
          : 'Votre session a expiré. Reconnectez-vous pour continuer.';
    case 'FORBIDDEN':
      if (e.message.toLowerCase().contains('pris en charge')) {
        return 'Ce dossier est déjà pris en charge par un autre spécialiste.';
      }
      return 'Vous n’avez pas accès à cette action avec votre compte.';
    case 'VALIDATION_ERROR':
      return 'Certaines informations sont invalides. Vérifiez les champs, '
          'puis réessayez.';
    case 'EMAIL_ALREADY_EXISTS':
      return 'Un compte existe déjà avec cette adresse e-mail. Connectez-vous '
          'ou utilisez une autre adresse.';
    case 'MATRICULE_NOT_FOUND':
      return 'Ce matricule ne figure pas dans le registre des médecins. '
          'Vérifiez-le ou contactez l’administrateur.';
    case 'SUPERVISOR_MATRICULE_NOT_FOUND':
      return 'Le matricule de votre encadrant est introuvable. Vérifiez-le '
          'auprès de lui.';
    case 'MATRICULE_ALREADY_USED':
      return 'Ce matricule est déjà associé à un compte.';
    case 'INVALID_PASSWORD':
      return 'Le mot de passe actuel est incorrect.';
    case 'NOT_FOUND':
    case 'USER_NOT_FOUND':
      return 'Élément introuvable : il a peut-être été supprimé. Actualisez '
          'la page.';
    case 'CONFLICT':
      return 'Cet élément existe déjà.';
    case 'EXPERTISE_ALREADY_COMPLETED':
      return 'Cette expertise est déjà terminée.';
    case 'INVALID_EXPERTISE_STATUS':
      return 'Ce dossier n’est plus disponible : un autre spécialiste l’a '
          'déjà pris en charge.';
    case 'EXPERTISE_NOT_IN_REVIEW':
      return 'Prenez d’abord le dossier en charge avant d’envoyer votre avis.';
    case 'PATIENT_HAS_ACTIVE_REVIEW':
      return 'Une demande d’avis est déjà en cours pour ce patient.';
    case 'DOSSIER_VALIDATED':
      return 'Ce dossier a été validé par un soignant : il ne peut plus être '
          'modifié.';
    case 'USER_HAS_CLINICAL_DATA':
      return 'Ce compte est lié à des données cliniques : il ne peut pas être '
          'supprimé.';
    case 'INVALID_IMAGE_TYPE':
      return 'Format d’image non pris en charge. Utilisez une photo JPEG, PNG '
          'ou WebP.';
    case 'CONVERSATION_ARCHIVED':
      return 'Cette conversation est archivée. Démarrez-en une nouvelle.';
    case 'AI_RESPONSE_REQUIRED':
      return 'L’analyse IA doit être terminée avant cette action.';
    case 'INTERNAL_SERVER_ERROR':
      return 'Le serveur a rencontré un problème. Réessayez dans un instant.';
  }
  final status = e.statusCode ?? 0;
  if (status >= 500) {
    return 'Le serveur a rencontré un problème. Réessayez dans un instant.';
  }
  final msg = e.message.trim();
  final technical = msg.isEmpty || msg.startsWith('Erreur API') || msg.contains('Exception') || msg.contains('Error');
  return technical ? 'L’opération n’a pas abouti. Réessayez dans un instant.' : msg;
}

/// Messages courts en bas d'écran, cohérents dans toute l'app.
class KSnack {
  const KSnack._();

  static void show(
    BuildContext context,
    String message, {
    KTone tone = KTone.neutral,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final icon = switch (tone) {
      KTone.success => Icons.check_circle_rounded,
      KTone.danger => Icons.error_rounded,
      KTone.warning => Icons.warning_amber_rounded,
      KTone.info => Icons.info_rounded,
      KTone.ai => Icons.auto_awesome_rounded,
      _ => null,
    };
    final accent = switch (tone) {
      KTone.success => const Color(0xFF8FDBAE),
      KTone.danger => const Color(0xFFFFB3AC),
      KTone.warning => const Color(0xFFF1CB85),
      _ => const Color(0xFF9DD9DC),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: Duration(seconds: tone == KTone.danger ? 5 : 3),
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(message)),
            ],
          ),
          action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
        ),
      );
  }

  static void success(BuildContext context, String message) => show(context, message, tone: KTone.success);

  static void error(BuildContext context, Object error) => show(context, friendlyError(error), tone: KTone.danger);
}

/// Confirmation avant une action risquée. Retourne `true` si confirmée.
Future<bool> showKConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Annuler',
  bool destructive = false,
}) async {
  final k = context.k;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: k.danger,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                  minimumSize: const Size(64, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Refus avec motif facultatif (inscription, compte). Renvoie le motif saisi
/// (éventuellement vide) ou `null` si l'utilisateur annule.
Future<String?> showKReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Refuser',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _KReasonDialog(title: title, message: message, confirmLabel: confirmLabel),
  );
}

class _KReasonDialog extends StatefulWidget {
  const _KReasonDialog({required this.title, required this.message, required this.confirmLabel});

  final String title;
  final String message;
  final String confirmLabel;

  @override
  State<_KReasonDialog> createState() => _KReasonDialogState();
}

class _KReasonDialogState extends State<_KReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: KSpace.md),
          TextField(
            controller: _reason,
            autofocus: true,
            maxLines: 2,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Motif (facultatif)'),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: k.danger,
            foregroundColor: Theme.of(context).colorScheme.onError,
            minimumSize: const Size(64, 44),
          ),
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
