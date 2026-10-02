import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../feedback.dart';
import '../korai_tokens.dart';

/// Chargement centré avec un message qui dit ce qui se passe.
class KLoadingView extends StatelessWidget {
  const KLoadingView({super.key, this.message = 'Chargement…', this.compact = false});

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? KSpace.md : KSpace.xl),
        child: Semantics(
          liveRegion: true,
          label: message,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: compact ? 22 : 30,
                height: compact ? 22 : 30,
                child: CircularProgressIndicator(strokeWidth: 3, color: k.brand),
              ),
              const SizedBox(height: KSpace.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Squelette de liste pendant le chargement (au lieu d'un spinner isolé).
class KSkeletonList extends StatefulWidget {
  const KSkeletonList({super.key, this.count = 4, this.itemHeight = 76, this.padding = const EdgeInsets.all(KSpace.gutter)});

  final int count;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  @override
  State<KSkeletonList> createState() => _KSkeletonListState();
}

class _KSkeletonListState extends State<KSkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KMotion.reduced(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      label: 'Chargement en cours',
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final c = Color.lerp(k.surfaceAlt, k.line, _c.value)!;
            return ListView.separated(
              padding: widget.padding,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: widget.count,
              separatorBuilder: (_, __) => const SizedBox(height: KSpace.sm),
              itemBuilder: (_, i) => Container(
                height: widget.itemHeight,
                padding: const EdgeInsets.all(KSpace.md),
                decoration: BoxDecoration(
                  color: k.surface,
                  borderRadius: KRadius.cardAll,
                  border: Border.all(color: k.line),
                ),
                child: Row(
                  children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                    const SizedBox(width: KSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(height: 12, width: 140.0 + (i % 3) * 30, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6))),
                          const SizedBox(height: 8),
                          Container(height: 10, width: 90.0 + (i % 2) * 40, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Erreur de chargement : ce qui s'est passé, et un bouton pour réessayer.
class KErrorView extends StatelessWidget {
  const KErrorView({
    super.key,
    this.title,
    required this.error,
    this.onRetry,
    this.retryLabel = 'Réessayer',
    this.compact = false,
  });

  /// Titre ; déduit de l'erreur si absent.
  final String? title;

  /// Erreur brute ou message déjà rédigé.
  final Object error;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool compact;

  bool get _isNetwork => error is ApiException && (error as ApiException).isNetworkFailure;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final message = error is String ? error as String : friendlyError(error);
    final heading = title ?? (_isNetwork ? 'Pas de connexion au serveur' : 'Chargement impossible');
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? KSpace.md : KSpace.xl),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 44 : 60,
                height: compact ? 44 : 60,
                decoration: BoxDecoration(
                  color: _isNetwork ? k.neutralBg : k.dangerBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isNetwork ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                  color: _isNetwork ? k.inkMuted : k.danger,
                  size: compact ? 22 : 30,
                ),
              ),
              const SizedBox(height: KSpace.md),
              Text(heading, textAlign: TextAlign.center, style: context.text.titleLarge),
              const SizedBox(height: KSpace.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: KSpace.lg),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// État vide : une invitation à agir, pas un écran muet.
class KEmptyView extends StatelessWidget {
  const KEmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? KSpace.md : KSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 48 : 64,
              height: compact ? 48 : 64,
              decoration: BoxDecoration(color: k.lagoon, shape: BoxShape.circle),
              child: Icon(icon, color: k.brand, size: compact ? 24 : 30),
            ),
            const SizedBox(height: KSpace.md),
            Text(title, textAlign: TextAlign.center, style: context.text.titleLarge),
            if (message != null) ...[
              const SizedBox(height: KSpace.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: KSpace.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bannière en ligne (hors ligne, avertissement, information…).
class KBanner extends StatelessWidget {
  const KBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = KTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final KTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.k.tone(tone);
    final i = icon ??
        switch (tone) {
          KTone.success => Icons.check_circle_rounded,
          KTone.warning => Icons.warning_amber_rounded,
          KTone.danger => Icons.error_rounded,
          KTone.ai => Icons.auto_awesome_rounded,
          _ => Icons.info_rounded,
        };
    return Semantics(
      liveRegion: tone == KTone.danger,
      child: Container(
        padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.sm, KSpace.xs, KSpace.sm),
        decoration: BoxDecoration(color: c.bg, borderRadius: KRadius.controlAll),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(i, size: 20, color: c.accent),
            ),
            const SizedBox(width: KSpace.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: KSpace.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(title!, style: context.text.titleSmall?.copyWith(color: c.fg)),
                    Text(message, style: context.text.bodyMedium?.copyWith(color: c.fg)),
                  ],
                ),
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: c.fg, minimumSize: const Size(44, 36)),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

enum KResultKind { success, error, info, offline }

/// Écran de résultat plein écran : succès, erreur, information ou
/// « enregistré hors ligne ». Une action principale, une secondaire.
class KResultScreen extends StatelessWidget {
  const KResultScreen({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.details,
    this.primaryLabel = 'Terminer',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final KResultKind kind;
  final String title;
  final String message;
  final Widget? details;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (IconData icon, Color fg, Color bg) = switch (kind) {
      KResultKind.success => (Icons.check_rounded, k.onBrand, k.brand),
      KResultKind.error => (Icons.priority_high_rounded, Theme.of(context).colorScheme.onError, k.danger),
      KResultKind.info => (Icons.info_outline_rounded, k.onBrand, k.brand),
      KResultKind.offline => (Icons.cloud_upload_outlined, k.onHero, k.hero),
    };
    final reduced = KMotion.reduced(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) (onPrimary ?? () => Navigator.of(context).pop())();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(KSpace.lg, KSpace.lg, KSpace.lg, KSpace.md),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: reduced ? 1 : 0.6, end: 1),
                            duration: reduced ? Duration.zero : const Duration(milliseconds: 420),
                            curve: Curves.easeOutBack,
                            builder: (_, v, child) => Transform.scale(scale: v, child: child),
                            child: Container(
                              width: 118,
                              height: 118,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: bg.withValues(alpha: 0.18), width: 12),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                                child: Icon(icon, color: fg, size: 40),
                              ),
                            ),
                          ),
                          const SizedBox(height: KSpace.lg),
                          Semantics(
                            header: true,
                            liveRegion: true,
                            child: Text(title, textAlign: TextAlign.center, style: context.text.headlineSmall),
                          ),
                          const SizedBox(height: KSpace.xs),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: context.text.bodyLarge?.copyWith(color: k.inkMuted),
                          ),
                          if (details != null) ...[
                            const SizedBox(height: KSpace.lg),
                            details!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onPrimary ?? () => Navigator.of(context).pop(),
                    child: Text(primaryLabel),
                  ),
                ),
                if (secondaryLabel != null) ...[
                  const SizedBox(height: KSpace.xs),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum KButtonKind { filled, outlined, text, danger, tonal }

/// Bouton qui gère lui-même son chargement : désactivé et « Envoi… » pendant
/// l'opération, pour éviter les doubles envois.
class KAsyncButton extends StatefulWidget {
  const KAsyncButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busyLabel,
    this.kind = KButtonKind.filled,
    this.expand = true,
  });

  final String label;
  final Future<void> Function()? onPressed;
  final IconData? icon;
  final String? busyLabel;
  final KButtonKind kind;
  final bool expand;

  @override
  State<KAsyncButton> createState() => _KAsyncButtonState();
}

class _KAsyncButtonState extends State<KAsyncButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy || widget.onPressed == null) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final onDanger = Theme.of(context).colorScheme.onError;
    final enabled = widget.onPressed != null && !_busy;
    final spinnerColor = switch (widget.kind) {
      KButtonKind.filled => k.onBrand,
      KButtonKind.danger => onDanger,
      _ => k.brand,
    };
    final child = AnimatedSwitcher(
      duration: KMotion.of(context, KMotion.fast),
      child: _busy
          ? Row(
              key: const ValueKey('busy'),
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: spinnerColor),
                ),
                const SizedBox(width: 10),
                Text(widget.busyLabel ?? 'Patientez…'),
              ],
            )
          : Row(
              key: const ValueKey('idle'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[Icon(widget.icon, size: 20), const SizedBox(width: 8)],
                Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
    final onTap = enabled ? _run : null;
    final button = switch (widget.kind) {
      KButtonKind.filled => FilledButton(
          onPressed: onTap,
          style: _busy
              ? FilledButton.styleFrom(
                  disabledBackgroundColor: k.brand.withValues(alpha: 0.85),
                  disabledForegroundColor: k.onBrand,
                )
              : null,
          child: child,
        ),
      KButtonKind.danger => FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: k.danger,
            foregroundColor: onDanger,
            disabledBackgroundColor: k.danger.withValues(alpha: _busy ? 0.85 : 0.4),
            disabledForegroundColor: onDanger,
          ),
          child: child,
        ),
      KButtonKind.tonal => FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(backgroundColor: k.lagoon, foregroundColor: k.onLagoon),
          child: child,
        ),
      KButtonKind.outlined => OutlinedButton(onPressed: onTap, child: child),
      KButtonKind.text => TextButton(onPressed: onTap, child: child),
    };
    return widget.expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
