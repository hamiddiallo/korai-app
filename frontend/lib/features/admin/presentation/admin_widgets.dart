import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

export '../../../core/widgets/consent_fields.dart' show ConsentPills;

/// Liste d'administration : chargement, erreur, vide, puis contenu, avec
/// une action « Ajouter » toujours visible.
class AdminListScaffold extends StatelessWidget {
  const AdminListScaffold({
    super.key,
    required this.loading,
    required this.loadedOnce,
    required this.error,
    required this.onRefresh,
    required this.createLabel,
    required this.onCreate,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.children,
    this.header,
  });

  final bool loading;
  final bool loadedOnce;
  final Object? error;
  final Future<void> Function() onRefresh;
  final String createLabel;
  final VoidCallback? onCreate;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final List<Widget> children;

  /// Contenu fixe au-dessus de la liste (filtres, onglets).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (!loadedOnce && loading) {
      body = const KSkeletonList(count: 5, itemHeight: 72);
    } else if (!loadedOnce && error != null) {
      body = KErrorView(title: 'La liste n’a pas pu être chargée', error: error!, onRetry: onRefresh);
    } else {
      body = RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.sm, KSpace.gutter, 110),
          children: [
            if (error != null) ...[
              KBanner(
                tone: KTone.warning,
                title: 'Liste peut-être incomplète',
                message: friendlyError(error!),
                actionLabel: 'Réessayer',
                onAction: onRefresh,
              ),
              const SizedBox(height: KSpace.sm),
            ],
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: KSpace.xl),
                child: KEmptyView(
                  icon: emptyIcon,
                  title: emptyTitle,
                  message: emptyMessage,
                  actionLabel: onCreate == null ? null : createLabel,
                  onAction: onCreate,
                  compact: true,
                ),
              )
            else
              ...children,
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          if (header != null) header!,
          if (loadedOnce && loading) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: onCreate == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: Text(createLabel),
            ),
    );
  }
}

/// Ligne d'une liste d'administration : avatar, titre, détails, actions.
class AdminRow extends StatelessWidget {
  const AdminRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.footer,
    this.trailing,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.editTooltip = 'Modifier',
    this.deleteTooltip = 'Supprimer',
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? footer;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String editTooltip;
  final String deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.xs),
      child: KCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(KSpace.sm, KSpace.sm, KSpace.xxs, KSpace.sm),
        child: Row(
          children: [
            leading,
            const SizedBox(width: KSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                  ],
                  if (footer != null) ...[const SizedBox(height: 6), footer!],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onEdit != null)
              IconButton(
                tooltip: editTooltip,
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, color: k.inkMuted),
              ),
            if (onDelete != null)
              IconButton(
                tooltip: deleteTooltip,
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: k.danger),
              ),
          ],
        ),
      ),
    );
  }
}

/// Icône ronde de tête de ligne.
class AdminLeadingIcon extends StatelessWidget {
  const AdminLeadingIcon({super.key, required this.icon, this.tone = KTone.brand});

  final IconData icon;
  final KTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.k.tone(tone);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
      child: Icon(icon, color: c.fg, size: 20),
    );
  }
}

/// Formulaire d'administration en feuille : valide les champs, enregistre
/// sur place et reste ouvert avec un message clair si l'envoi échoue.
/// Renvoie `true` quand l'enregistrement a réussi.
///
/// Les [controllers] sont libérés par la feuille elle-même, une fois son
/// animation de fermeture terminée (les libérer plus tôt ferait planter
/// les champs encore affichés).
Future<bool> showAdminFormSheet(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required List<Widget> Function(BuildContext context, StateSetter setState) fields,
  required Future<void> Function() onSubmit,
  List<TextEditingController> controllers = const [],
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AdminFormSheet(
      title: title,
      submitLabel: submitLabel,
      fields: fields,
      onSubmit: onSubmit,
      controllers: controllers,
    ),
  );
  return result ?? false;
}

class _AdminFormSheet extends StatefulWidget {
  const _AdminFormSheet({
    required this.title,
    required this.submitLabel,
    required this.fields,
    required this.onSubmit,
    required this.controllers,
  });

  final String title;
  final String submitLabel;
  final List<Widget> Function(BuildContext context, StateSetter setState) fields;
  final Future<void> Function() onSubmit;
  final List<TextEditingController> controllers;

  @override
  State<_AdminFormSheet> createState() => _AdminFormSheetState();
}

class _AdminFormSheetState extends State<_AdminFormSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _error;
  bool _invalid = false;

  @override
  void dispose() {
    for (final c in widget.controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() {
        _invalid = true;
        _error = 'Corrigez les champs signalés en rouge, puis enregistrez.';
      });
      return;
    }
    setState(() {
      _invalid = false;
      _error = null;
    });
    try {
      await widget.onSubmit();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.lg),
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.title, style: context.text.headlineSmall)),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: KSpace.sm),
            ...widget.fields(context, setState),
            if (_error != null) ...[
              const SizedBox(height: KSpace.sm),
              KBanner(
                tone: _invalid ? KTone.warning : KTone.danger,
                title: _invalid ? 'Champs à corriger' : 'Enregistrement impossible',
                message: _error!,
              ),
            ],
            const SizedBox(height: KSpace.md),
            KAsyncButton(
              label: widget.submitLabel,
              busyLabel: 'Enregistrement…',
              icon: Icons.check_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation de suppression (bouton rouge).
Future<bool> confirmDelete(BuildContext context, {required String title, required String message}) {
  return showKConfirm(context, title: title, message: message, confirmLabel: 'Supprimer', destructive: true);
}

/// Petit badge du score de danger (0–3) d'un élément clinique.
class DangerScoreBadge extends StatelessWidget {
  const DangerScoreBadge({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final tone = switch (score) {
      >= 3 => KTone.danger,
      2 => KTone.warning,
      1 => KTone.info,
      _ => KTone.neutral,
    };
    final c = context.k.tone(tone);
    return Tooltip(
      message: 'Score de danger : $score sur 3',
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle, border: Border.all(color: c.accent)),
        child: Text('$score', style: context.text.labelMedium?.copyWith(color: c.fg, fontFamily: KFonts.mono)),
      ),
    );
  }
}

/// « 12/05/2026 14:30 » pour les dates d'administration.
String adminDate(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return 'Date inconnue';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
