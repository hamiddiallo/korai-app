import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../design/design.dart';
import 'notification_cubit.dart';
import 'notification_models.dart';

typedef NotificationTapCallback = void Function(AppNotification notification);

/// Cloche avec badge du nombre de notifications non lues. Ouvre le centre de
/// notifications au toucher.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    this.color,
    this.onTapNotification,
    this.pinnedHeader,
    this.filled = false,
  });

  /// Couleur de l'icône. `null` → hérite du thème.
  final Color? color;
  final NotificationTapCallback? onTapNotification;

  /// En-tête épinglé optionnel (ex. « patients à valider » côté soignant).
  final WidgetBuilder? pinnedHeader;

  /// Fond de carte rond (en-têtes d'écran) plutôt qu'une icône nue.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return BlocBuilder<NotificationCubit, NotificationState>(
      buildWhen: (p, n) => p.unreadCount != n.unreadCount,
      builder: (context, state) {
        final count = state.unreadCount;
        final icon = count > 0
            ? Badge(
                backgroundColor: k.danger,
                label: Text(count > 99 ? '99+' : '$count'),
                child: Icon(Icons.notifications_rounded, color: color ?? k.ink),
              )
            : Icon(Icons.notifications_none_rounded, color: color ?? k.ink);
        return IconButton(
          tooltip: count > 0 ? 'Notifications, $count non lues' : 'Notifications',
          style: filled
              ? IconButton.styleFrom(
                  backgroundColor: k.surface,
                  side: BorderSide(color: k.line),
                  minimumSize: const Size(46, 46),
                )
              : null,
          onPressed: () => showNotificationCenter(
            context,
            onTapNotification: onTapNotification,
            pinnedHeader: pinnedHeader,
          ),
          icon: icon,
        );
      },
    );
  }
}

Future<void> showNotificationCenter(
  BuildContext context, {
  NotificationTapCallback? onTapNotification,
  WidgetBuilder? pinnedHeader,
}) {
  final cubit = context.read<NotificationCubit>();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return BlocProvider.value(
        value: cubit,
        child: _NotificationCenterSheet(
          onTapNotification: onTapNotification,
          pinnedHeader: pinnedHeader,
        ),
      );
    },
  );
}

class _NotificationCenterSheet extends StatelessWidget {
  const _NotificationCenterSheet({this.onTapNotification, this.pinnedHeader});

  final NotificationTapCallback? onTapNotification;
  final WidgetBuilder? pinnedHeader;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return BlocBuilder<NotificationCubit, NotificationState>(
          builder: (context, state) {
            final cubit = context.read<NotificationCubit>();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.xs, KSpace.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Notifications', style: context.text.headlineSmall),
                      ),
                      if (state.unreadCount > 0)
                        TextButton(
                          onPressed: cubit.markAllRead,
                          child: const Text('Tout marquer comme lu'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: cubit.refresh,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.xxs, KSpace.md, KSpace.xl),
                      children: [
                        if (pinnedHeader != null) pinnedHeader!(context),
                        if (state.items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: KSpace.xl),
                            child: KEmptyView(
                              icon: Icons.notifications_none_rounded,
                              title: 'Aucune notification',
                              message:
                                  'Vous serez prévenu·e ici des avis de spécialistes, des validations et des envois de données.',
                            ),
                          )
                        else
                          for (final n in state.items) ...[
                            _NotificationTile(
                              notification: n,
                              onTap: () {
                                cubit.markRead(n);
                                if (onTapNotification != null) {
                                  Navigator.pop(context);
                                  onTapNotification!(n);
                                }
                              },
                            ),
                            const SizedBox(height: KSpace.xs),
                          ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final unread = !notification.isRead;
    final c = k.tone(notification.type.tone);
    return Semantics(
      label: unread ? 'Non lue' : null,
      child: KCard(
        onTap: onTap,
        color: unread ? k.surface : k.mist,
        borderColor: unread ? c.accent.withValues(alpha: 0.45) : k.line,
        padding: const EdgeInsets.all(KSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
              child: Icon(notification.type.icon, color: c.fg, size: 21),
            ),
            const SizedBox(width: KSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(notification.body, style: context.text.bodyMedium?.copyWith(color: k.inkMuted)),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: context.text.labelSmall?.copyWith(color: k.inkMuted, fontFamily: KFonts.mono),
                  ),
                ],
              ),
            ),
            if (unread)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 6),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime utc) {
    final diff = DateTime.now().toUtc().difference(utc);
    if (diff.inMinutes < 1) return 'À l’instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    final local = utc.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }
}
