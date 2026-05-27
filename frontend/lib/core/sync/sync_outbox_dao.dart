import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../offline/offline_models.dart';
import '../storage/encrypted_local_database.dart';

class SyncOutboxEntry {
  const SyncOutboxEntry({
    required this.localId,
    required this.entityType,
    required this.entityLocalId,
    required this.operation,
    required this.payload,
    required this.status,
    required this.attemptCount,
  });

  final String localId;
  final String entityType;
  final String entityLocalId;
  final String operation;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final int attemptCount;

  factory SyncOutboxEntry.fromRow(Map<String, dynamic> row) {
    final rawPayload = row['payload_json']?.toString() ?? '{}';
    return SyncOutboxEntry(
      localId: row['local_id'].toString(),
      entityType: row['entity_type'].toString(),
      entityLocalId: row['entity_local_id'].toString(),
      operation: row['operation'].toString(),
      payload: jsonDecode(rawPayload) as Map<String, dynamic>,
      status: SyncStatus.fromValue(row['status']?.toString()),
      attemptCount: int.tryParse(row['attempt_count']?.toString() ?? '') ?? 0,
    );
  }
}

class SyncOutboxDao {
  SyncOutboxDao({
    EncryptedLocalDatabase? database,
  }) : _database = database ?? EncryptedLocalDatabase.instance;

  static final SyncOutboxDao instance = SyncOutboxDao();

  final EncryptedLocalDatabase _database;
  final _uuid = const Uuid();

  Future<String> enqueue({
    required OfflineEntityType entityType,
    required String entityLocalId,
    required OutboxOperation operation,
    required Map<String, dynamic> payload,
    int priority = 100,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();

    await db.insert(
      'sync_outbox',
      {
        'local_id': id,
        'entity_type': entityType.value,
        'entity_local_id': entityLocalId,
        'operation': operation.value,
        'payload_json': jsonEncode(payload),
        'status': SyncStatus.pendingSync.value,
        'priority': priority,
        'attempt_count': 0,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<SyncOutboxEntry>> listRunnable({int limit = 25}) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await db.query(
      'sync_outbox',
      where: 'status = ? AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [SyncStatus.pendingSync.value, now],
      orderBy: 'priority ASC, created_at ASC',
      limit: limit,
    );
    return rows.map(SyncOutboxEntry.fromRow).toList();
  }

  Future<int> countPending() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_outbox WHERE status = ?',
      [SyncStatus.pendingSync.value],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> countFailed() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_outbox WHERE status = ?',
      [SyncStatus.syncFailed.value],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> markSynced(String localId) async {
    final db = await _database.database;
    await db.update(
      'sync_outbox',
      {
        'status': SyncStatus.synced.value,
        'last_error': null,
        'locked_at': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markRetryableFailure(
    SyncOutboxEntry entry,
    Object error,
  ) async {
    final db = await _database.database;
    final attempts = entry.attemptCount + 1;
    final now = DateTime.now().toUtc();
    final delay = switch (attempts) {
      <= 1 => const Duration(minutes: 1),
      2 => const Duration(minutes: 5),
      3 => const Duration(minutes: 15),
      _ => const Duration(hours: 1),
    };

    await db.update(
      'sync_outbox',
      {
        'status': SyncStatus.pendingSync.value,
        'attempt_count': attempts,
        'last_error': error.toString(),
        'next_retry_at': now.add(delay).toIso8601String(),
        'locked_at': null,
        'updated_at': now.toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [entry.localId],
    );
  }

  Future<void> markFailed(String localId, Object error) async {
    final db = await _database.database;
    await db.update(
      'sync_outbox',
      {
        'status': SyncStatus.syncFailed.value,
        'last_error': error.toString(),
        'locked_at': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markSyncedByEntity({
    required OfflineEntityType entityType,
    required String entityLocalId,
  }) async {
    final db = await _database.database;
    await db.update(
      'sync_outbox',
      {
        'status': SyncStatus.synced.value,
        'last_error': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'entity_type = ? AND entity_local_id = ?',
      whereArgs: [entityType.value, entityLocalId],
    );
  }

  Future<void> markRetryableFailureByEntity({
    required OfflineEntityType entityType,
    required String entityLocalId,
    required Object error,
  }) async {
    final db = await _database.database;
    await db.update(
      'sync_outbox',
      {
        'status': SyncStatus.pendingSync.value,
        'last_error': error.toString(),
        'next_retry_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 1))
            .toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'entity_type = ? AND entity_local_id = ?',
      whereArgs: [entityType.value, entityLocalId],
    );
  }

  Future<void> markFailedByEntity({
    required OfflineEntityType entityType,
    required String entityLocalId,
    required Object error,
  }) async {
    final db = await _database.database;
    await db.update(
      'sync_outbox',
      {
        'status': SyncStatus.syncFailed.value,
        'last_error': error.toString(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'entity_type = ? AND entity_local_id = ?',
      whereArgs: [entityType.value, entityLocalId],
    );
  }
}
