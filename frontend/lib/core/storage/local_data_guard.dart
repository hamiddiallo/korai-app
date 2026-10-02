import 'package:sqflite_sqlcipher/sqflite.dart';

import '../offline/offline_models.dart';
import 'encrypted_local_database.dart';

/// Compte à qui appartiennent les données hors-ligne de ce téléphone.
class LocalDataOwner {
  const LocalDataOwner({required this.id, required this.name});

  final String id;
  final String name;
}

sealed class LocalDataClaim {
  const LocalDataClaim();
}

/// Les données locales appartiennent au compte connecté : l'app peut s'ouvrir.
class LocalDataReady extends LocalDataClaim {
  const LocalDataReady({this.clearedPreviousOwner = false});

  /// Les données (toutes envoyées) d'un autre compte ont été effacées.
  final bool clearedPreviousOwner;
}

/// Un autre compte a laissé des données non envoyées sur ce téléphone.
class LocalDataConflict extends LocalDataClaim {
  const LocalDataConflict({required this.ownerName, required this.unsentCount});

  final String ownerName;
  final int unsentCount;
}

abstract class LocalDataStore {
  Future<LocalDataOwner?> readOwner();
  Future<void> writeOwner(LocalDataOwner owner);

  /// Éléments de la file d'envoi pas encore acceptés par le serveur.
  Future<int> countUnsent();

  /// Efface patients, consultations, images, réponses IA, file d'envoi,
  /// notifications et caches de discussion (le référentiel clinique reste).
  Future<void> clearPersonalData();
}

/// Un téléphone partagé ne mélange jamais les données de deux comptes : sans
/// ce contrôle, la file d'envoi d'un soignant partait sous le compte du
/// suivant, qui voyait aussi ses patients en cache.
class LocalDataGuard {
  const LocalDataGuard(this.store);

  static final instance = LocalDataGuard(SqliteLocalDataStore(EncryptedLocalDatabase.instance));

  final LocalDataStore store;

  Future<LocalDataClaim> claim({required String userId, required String userName}) async {
    final me = LocalDataOwner(id: userId, name: userName);
    final owner = await store.readOwner();
    if (owner == null) {
      // Première utilisation (ou données d'une version sans propriétaire) :
      // elles reviennent au compte qui se connecte.
      await store.writeOwner(me);
      return const LocalDataReady();
    }
    if (owner.id == userId) {
      if (owner.name != userName) await store.writeOwner(me);
      return const LocalDataReady();
    }
    final unsent = await store.countUnsent();
    if (unsent > 0) return LocalDataConflict(ownerName: owner.name, unsentCount: unsent);
    // Tout a été envoyé : on efface le cache de l'autre compte.
    await store.clearPersonalData();
    await store.writeOwner(me);
    return const LocalDataReady(clearedPreviousOwner: true);
  }

  /// Choix explicite de l'utilisateur : les données non envoyées de l'autre
  /// compte sont perdues.
  Future<void> discardAndClaim({required String userId, required String userName}) async {
    await store.clearPersonalData();
    await store.writeOwner(LocalDataOwner(id: userId, name: userName));
  }

  /// Nombre d'éléments pas encore envoyés (avertissement à la déconnexion).
  Future<int> countUnsent() => store.countUnsent();
}

class SqliteLocalDataStore implements LocalDataStore {
  const SqliteLocalDataStore(this._database);

  final EncryptedLocalDatabase _database;

  static const _ownerIdKey = 'local_owner_user_id';
  static const _ownerNameKey = 'local_owner_name';

  @override
  Future<LocalDataOwner?> readOwner() async {
    final db = await _database.database;
    final rows = await db.query(
      'app_metadata',
      columns: ['key', 'value'],
      where: 'key IN (?, ?)',
      whereArgs: [_ownerIdKey, _ownerNameKey],
    );
    final values = {for (final r in rows) r['key'] as String: r['value'] as String};
    final id = values[_ownerIdKey];
    if (id == null || id.isEmpty) return null;
    return LocalDataOwner(id: id, name: values[_ownerNameKey] ?? 'un autre compte');
  }

  @override
  Future<void> writeOwner(LocalDataOwner owner) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = db.batch();
    for (final entry in {_ownerIdKey: owner.id, _ownerNameKey: owner.name}.entries) {
      batch.insert(
        'app_metadata',
        {'key': entry.key, 'value': entry.value, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> countUnsent() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_outbox WHERE status != ?',
      [SyncStatus.synced.value],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  @override
  Future<void> clearPersonalData() async {
    final db = await _database.database;
    await db.transaction((txn) async {
      // Enfants d'abord (clés étrangères).
      for (final table in const [
        'local_ai_responses',
        'local_otoscopic_images',
        'local_consultations',
        'local_patients',
        'sync_outbox',
        'notifications',
        'chat_messages_cache',
        'chat_conversations_cache',
      ]) {
        await txn.delete(table);
      }
    });
  }
}
