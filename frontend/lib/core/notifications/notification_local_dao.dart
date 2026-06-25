import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../storage/encrypted_local_database.dart';
import 'notification_models.dart';

/// Cache local des notifications : miroir des notifications serveur (is_local=0)
/// + notifications générées localement (synchronisation, is_local=1).
class NotificationLocalDao {
  NotificationLocalDao({EncryptedLocalDatabase? database})
      : _database = database ?? EncryptedLocalDatabase.instance;

  static final NotificationLocalDao instance = NotificationLocalDao();

  final EncryptedLocalDatabase _database;
  final _uuid = const Uuid();

  /// Fusionne les notifications serveur dans le cache. Conserve l'état « lu »
  /// déjà appliqué localement (évite qu'une notif lue hors-ligne réapparaisse
  /// non-lue après un fetch).
  Future<void> upsertServerNotifications(
    List<AppNotification> notifications,
  ) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final n in notifications) {
        final existing = await txn.query(
          'notifications',
          columns: ['is_read'],
          where: 'id = ?',
          whereArgs: [n.id],
          limit: 1,
        );
        final alreadyRead =
            existing.isNotEmpty && existing.first['is_read'] == 1;
        final row = n.toRow();
        if (alreadyRead) row['is_read'] = 1;
        await txn.insert(
          'notifications',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Insère une notification locale (générée par l'app, ex. résultat de sync).
  Future<void> insertLocal({
    required NotificationType type,
    required String title,
    required String body,
    String? consultationId,
    String? patientId,
  }) async {
    final db = await _database.database;
    final notification = AppNotification(
      id: 'local_${_uuid.v4()}',
      type: type,
      title: title,
      body: body,
      isRead: false,
      isLocal: true,
      createdAt: DateTime.now().toUtc(),
      consultationId: consultationId,
      patientId: patientId,
    );
    await db.insert(
      'notifications',
      notification.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AppNotification>> list({int limit = 50}) async {
    final db = await _database.database;
    final rows = await db.query(
      'notifications',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(AppNotification.fromRow).toList();
  }

  Future<int> countUnread() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notifications WHERE is_read = 0',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> markRead(String id) async {
    final db = await _database.database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllRead() async {
    final db = await _database.database;
    await db.update('notifications', {'is_read': 1}, where: 'is_read = 0');
  }

  /// Purge complète du cache (à la déconnexion : le cache est global à
  /// l'appareil, il ne doit pas fuiter d'un utilisateur à l'autre).
  Future<void> clearAll() async {
    final db = await _database.database;
    await db.delete('notifications');
  }

  /// Purge les notifications serveur (is_local=0) anciennes pour borner le cache.
  Future<void> pruneServerOlderThan(int keep) async {
    final db = await _database.database;
    await db.execute(
      '''
      DELETE FROM notifications
      WHERE is_local = 0 AND id NOT IN (
        SELECT id FROM notifications WHERE is_local = 0
        ORDER BY created_at DESC LIMIT ?
      )
      ''',
      [keep],
    );
  }
}
