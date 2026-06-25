import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'notification_cubit.dart';
import 'notification_models.dart';

typedef NotificationTapCallback = void Function(AppNotification notification);

/// Cloche avec badge du nombre de notifications non lues. Ouvre le centre de
/// notifications au tap.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    this.color,
    this.onTapNotification,
    this.pinnedHeader,
  });

  /// Couleur de l'icône. `null` → hérite du thème (utile dans une AppBar).
  final Color? color;
  final NotificationTapCallback? onTapNotification;

  /// En-tête épinglé optionnel (ex. « patients à valider » côté infirmier).
  final WidgetBuilder? pinnedHeader;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      buildWhen: (p, n) => p.unreadCount != n.unreadCount,
      builder: (context, state) {
        final count = state.unreadCount;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => showNotificationCenter(
            context,
            onTapNotification: onTapNotification,
            pinnedHeader: pinnedHeader,
          ),
          icon: count > 0
              ? Badge(
                  label: Text('$count'),
                  child: Icon(Icons.notifications_active, color: color),
                )
              : Icon(Icons.notifications_none, color: color),
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
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
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
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (state.unreadCount > 0)
                        TextButton(
                          onPressed: cubit.markAllRead,
                          child: const Text('Tout marquer lu'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: cubit.refresh,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      children: [
                        if (pinnedHeader != null) pinnedHeader!(context),
                        if (state.items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Column(
                              children: [
                                Icon(Icons.notifications_none,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'Aucune notification',
                                  style:
                                      TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        else
                          ...state.items.map(
                            (n) => _NotificationTile(
                              notification: n,
                              onTap: () {
                                cubit.markRead(n);
                                if (onTapNotification != null) {
                                  Navigator.pop(context);
                                  onTapNotification!(n);
                                }
                              },
                            ),
                          ),
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
    final unread = !notification.isRead;
    final type = notification.type;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: unread ? const Color(0xFFF0FBFF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: unread
              ? type.color.withValues(alpha: 0.35)
              : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: type.color.withValues(alpha: 0.12),
          child: Icon(type.icon, color: type.color, size: 22),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: unread ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(notification.body, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 4),
            Text(
              _relativeTime(notification.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: unread
            ? Container(
                width: 9,
                height: 9,
                decoration:
                    BoxDecoration(color: type.color, shape: BoxShape.circle),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  String _relativeTime(DateTime utc) {
    final diff = DateTime.now().toUtc().difference(utc);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    final local = utc.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }
}
