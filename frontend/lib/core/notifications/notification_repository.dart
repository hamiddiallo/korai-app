import '../api/api_client.dart';
import 'notification_local_dao.dart';
import 'notification_models.dart';

/// Accès aux notifications : serveur (REST) + cache local chiffré, fusionnés.
/// Fonctionne hors-ligne en lecture (depuis le cache).
class NotificationRepository {
  NotificationRepository(this._apiClient, {NotificationLocalDao? localDao})
      : _localDao = localDao ?? NotificationLocalDao.instance;

  final ApiClient _apiClient;
  final NotificationLocalDao _localDao;

  /// Récupère les notifications serveur et les fusionne dans le cache, puis
  /// renvoie la liste fusionnée (serveur + locales). En cas d'échec réseau,
  /// renvoie simplement le cache local.
  Future<List<AppNotification>> refresh() async {
    try {
      final response = await _apiClient.getJson('/notifications?limit=50');
      final items = (response['notifications'] as List<dynamic>? ?? const [])
          .map((e) => AppNotification.fromApi(e as Map<String, dynamic>))
          .toList();
      await _localDao.upsertServerNotifications(items);
      await _localDao.pruneServerOlderThan(100);
    } on ApiException {
      // Hors-ligne ou serveur indisponible : on se contente du cache.
    }
    return _localDao.list();
  }

  Future<List<AppNotification>> cached() => _localDao.list();

  Future<int> unreadCount() => _localDao.countUnread();

  /// Marque une notification comme lue. Serveur si possible (best-effort),
  /// toujours en local pour une UI réactive et cohérente hors-ligne.
  Future<void> markRead(AppNotification notification) async {
    await _localDao.markRead(notification.id);
    if (!notification.isLocal) {
      try {
        await _apiClient.patchJson(
          '/notifications/${notification.id}/read',
          const {},
        );
      } on ApiException {
        // Best-effort : l'état local reste « lu » et est préservé au prochain fetch.
      }
    }
  }

  Future<void> markAllRead() async {
    await _localDao.markAllRead();
    try {
      await _apiClient.postJson('/notifications/read-all', const {});
    } on ApiException {
      // Best-effort.
    }
  }

  /// Génère une notification locale (ex. résultat de synchronisation offline).
  Future<void> addLocal({
    required NotificationType type,
    required String title,
    required String body,
    String? consultationId,
    String? patientId,
  }) {
    return _localDao.insertLocal(
      type: type,
      title: title,
      body: body,
      consultationId: consultationId,
      patientId: patientId,
    );
  }
}
