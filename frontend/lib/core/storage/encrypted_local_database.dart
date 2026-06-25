import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class EncryptedLocalDatabase {
  EncryptedLocalDatabase({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static final EncryptedLocalDatabase instance = EncryptedLocalDatabase();

  static const _databaseName = 'korai_offline.db';
  static const _databaseVersion = 3;
  static const _cipherKeyName = 'korai_sqlcipher_key';

  final FlutterSecureStorage _secureStorage;
  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final directory = await getApplicationSupportDirectory();
    final path = p.join(directory.path, _databaseName);
    final key = await _getOrCreateCipherKey();

    _database = await openDatabase(
      path,
      password: key,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    return _database!;
  }

  /// Migrations incrémentales de la base locale chiffrée.
  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    // v1 → v2 : empreinte clinique pour la déduplication/réutilisation IA.
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE local_consultations ADD COLUMN clinical_fingerprint TEXT',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS local_consultations_fingerprint_idx '
        'ON local_consultations(clinical_fingerprint, status)',
      );
    }

    // v2 → v3 : cache des notifications (serveur + locales de synchronisation).
    if (oldVersion < 3) {
      await _createNotificationsTable(db);
    }
  }

  Future<void> _createNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        consultation_id TEXT,
        patient_id TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        is_local INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX notifications_read_idx '
      'ON notifications(is_read, created_at)',
    );
  }

  Future<String> _getOrCreateCipherKey() async {
    final existing = await _secureStorage.read(key: _cipherKeyName);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64UrlEncode(bytes);
    await _secureStorage.write(key: _cipherKeyName, value: key);
    return key;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE clinical_reference_items (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        label TEXT NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        raw_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX clinical_reference_items_type_idx '
      'ON clinical_reference_items(type, sort_order, label)',
    );

    await db.execute('''
      CREATE TABLE local_patients (
        local_id TEXT PRIMARY KEY,
        server_id TEXT UNIQUE,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        birth_date TEXT,
        sex TEXT,
        consent_for_ai INTEGER NOT NULL DEFAULT 1,
        consent_for_tele_expertise INTEGER NOT NULL DEFAULT 1,
        is_validated INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL,
        last_sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX local_patients_sync_status_idx '
      'ON local_patients(sync_status, updated_at)',
    );

    await db.execute('''
      CREATE TABLE local_consultations (
        local_id TEXT PRIMARY KEY,
        server_id TEXT UNIQUE,
        local_patient_id TEXT NOT NULL,
        server_patient_id TEXT,
        clinical_narrative TEXT NOT NULL,
        clinical_notes TEXT,
        urgency TEXT NOT NULL,
        ear_side TEXT NOT NULL,
        show_sources INTEGER NOT NULL DEFAULT 1,
        request_specialist_review INTEGER NOT NULL DEFAULT 0,
        symptom_ids_json TEXT NOT NULL,
        symptom_labels_json TEXT NOT NULL,
        medical_history_ids_json TEXT NOT NULL,
        medical_history_labels_json TEXT NOT NULL,
        touch_check_ids_json TEXT NOT NULL,
        touch_check_labels_json TEXT NOT NULL,
        touch_observations_json TEXT NOT NULL,
        status TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        last_sync_error TEXT,
        clinical_fingerprint TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(local_patient_id) REFERENCES local_patients(local_id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX local_consultations_patient_idx '
      'ON local_consultations(local_patient_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX local_consultations_sync_status_idx '
      'ON local_consultations(sync_status, updated_at)',
    );
    await db.execute(
      'CREATE INDEX local_consultations_fingerprint_idx '
      'ON local_consultations(clinical_fingerprint, status)',
    );

    await db.execute('''
      CREATE TABLE local_otoscopic_images (
        local_id TEXT PRIMARY KEY,
        server_id TEXT,
        local_consultation_id TEXT NOT NULL,
        server_consultation_id TEXT,
        ear_side TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        file_name TEXT NOT NULL,
        bytes BLOB NOT NULL,
        byte_size INTEGER NOT NULL,
        sync_status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(local_consultation_id) REFERENCES local_consultations(local_id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX local_otoscopic_images_consultation_idx '
      'ON local_otoscopic_images(local_consultation_id)',
    );

    await db.execute('''
      CREATE TABLE local_ai_responses (
        local_id TEXT PRIMARY KEY,
        local_consultation_id TEXT NOT NULL,
        server_consultation_id TEXT,
        raw_json TEXT NOT NULL,
        image_opinion TEXT,
        rag_opinion TEXT,
        likely_diagnosis TEXT,
        confidence_label TEXT,
        warnings_json TEXT NOT NULL,
        sources_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(local_consultation_id) REFERENCES local_consultations(local_id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_conversations_cache (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        message_count INTEGER NOT NULL DEFAULT 0,
        last_message_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages_cache (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        sources_json TEXT NOT NULL,
        sequence INTEGER NOT NULL,
        delivery_status TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY(conversation_id) REFERENCES chat_conversations_cache(id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX chat_messages_conversation_sequence_idx '
      'ON chat_messages_cache(conversation_id, sequence)',
    );

    await db.execute('''
      CREATE TABLE sync_outbox (
        local_id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_local_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 100,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        locked_at TEXT,
        next_retry_at TEXT,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX sync_outbox_status_idx '
      'ON sync_outbox(status, priority, next_retry_at, created_at)',
    );

    // Table notifications : indispensable dès la première installation
    // (sinon NotificationCubit/SyncService échouent sur « no such table »).
    await _createNotificationsTable(db);
  }
}
