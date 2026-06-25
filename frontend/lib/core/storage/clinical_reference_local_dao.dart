import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../features/nurse/domain/clinical_reference_item.dart';
import 'encrypted_local_database.dart';

class ClinicalReferenceLocalDao {
  ClinicalReferenceLocalDao({
    EncryptedLocalDatabase? database,
  }) : _database = database ?? EncryptedLocalDatabase.instance;

  static final ClinicalReferenceLocalDao instance = ClinicalReferenceLocalDao();

  final EncryptedLocalDatabase _database;

  Future<void> cacheItems(
    String type,
    List<ClinicalReferenceItem> items,
  ) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final item in items) {
        await txn.insert(
          'clinical_reference_items',
          {
            'id': item.id,
            'type': item.type,
            'label': item.label,
            'description': item.description,
            'is_active': item.isActive ? 1 : 0,
            'sort_order': item.sortOrder,
            'raw_json': jsonEncode(_toJson(item)),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<ClinicalReferenceItem>> listItems(String type) async {
    final db = await _database.database;
    final rows = await db.query(
      'clinical_reference_items',
      where: 'type = ? AND is_active = 1',
      whereArgs: [type],
      orderBy: 'label ASC',
    );

    return rows.map((row) {
      final rawJson = row['raw_json']?.toString();
      if (rawJson != null && rawJson.isNotEmpty) {
        return ClinicalReferenceItem.fromJson(
          jsonDecode(rawJson) as Map<String, dynamic>,
        );
      }
      return ClinicalReferenceItem(
        id: row['id'].toString(),
        type: row['type'].toString(),
        label: row['label'].toString(),
        description: row['description']?.toString(),
        isActive: row['is_active'] == 1,
        sortOrder: int.tryParse(row['sort_order'].toString()) ?? 0,
      );
    }).toList();
  }

  Map<String, dynamic> _toJson(ClinicalReferenceItem item) => {
        'id': item.id,
        'type': item.type,
        'label': item.label,
        'description': item.description,
        'isActive': item.isActive,
        'sortOrder': item.sortOrder,
      };
}
