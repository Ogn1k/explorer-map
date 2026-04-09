// lib/db/database_helper.dart
//
// Two tables:
//   zone_states — only stores zones whose state differs from the default (enabled).
//                 Empty DB = all zones visible (fog on).
//   zone_names  — cache of continent/country/region resolved by NaturalEarthService.
//                 Grows only for zones the user has panned over.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models/marker_model.dart';
import '../models/zone_model.dart';

class DatabaseHelper {
  DatabaseHelper._({DatabaseFactory? databaseFactory, String? dbPath})
      : _databaseFactory = databaseFactory,
        _dbPathOverride = dbPath;
  static final DatabaseHelper instance = DatabaseHelper._();

  DatabaseHelper.test({
    required DatabaseFactory databaseFactory,
    required String dbPath,
  }) : _databaseFactory = databaseFactory,
       _dbPathOverride = dbPath;

  Database? _db;
  final DatabaseFactory? _databaseFactory;
  final String? _dbPathOverride;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path =
        _dbPathOverride ?? p.join(await getDatabasesPath(), 'fog_of_war.db');
    final factory = _databaseFactory ?? databaseFactory;
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE zone_states (
              id TEXT PRIMARY KEY,
              enabled INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE zone_names (
              id TEXT PRIMARY KEY,
              continent TEXT,
              country TEXT,
              region TEXT
            )
          ''');
          // Index for fast "get all named zones"
          await db.execute(
            'CREATE INDEX idx_zone_names_continent ON zone_names(continent)',
          );
          await db.execute('''
            CREATE TABLE markers (
              id TEXT PRIMARY KEY,
              lat REAL NOT NULL,
              lon REAL NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE markers (
                id TEXT PRIMARY KEY,
                lat REAL NOT NULL,
                lon REAL NOT NULL,
                created_at INTEGER NOT NULL
              )
            ''');
          }
        },
      ),
    );
  }

  // ── Zone states ─────────────────────────────────────────────────────────────

  /// Returns null when the zone is not in the table → caller should treat as default (true).
  Future<bool?> getZoneEnabled(String id) async {
    final d = await db;
    final rows = await d.query(
      'zone_states',
      columns: ['enabled'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return rows.first['enabled'] == 1;
  }

  /// Persists a zone state.
  /// If [enabled] == true (the default), the row is removed to keep the table minimal.
  Future<void> setZoneEnabled(String id, bool enabled) async {
    final d = await db;
    if (enabled) {
      await d.delete('zone_states', where: 'id = ?', whereArgs: [id]);
    } else {
      await d.insert(
        'zone_states',
        {'id': id, 'enabled': 0},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Batch-fetch states for a list of IDs. Missing IDs should be treated as default.
  Future<Map<String, bool>> getZoneStates(List<String> ids) async {
    if (ids.isEmpty) return {};
    final d = await db;
    final ph = List.filled(ids.length, '?').join(',');
    final rows = await d.rawQuery(
      'SELECT id, enabled FROM zone_states WHERE id IN ($ph)',
      ids,
    );
    return {
      for (final r in rows) r['id'] as String: (r['enabled'] as int) == 1,
    };
  }

  // ── Zone names ───────────────────────────────────────────────────────────────

  Future<({String? continent, String? country, String? region})?> getZoneName(
    String id,
  ) async {
    final d = await db;
    final rows = await d.query(
      'zone_names',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      continent: r['continent'] as String?,
      country: r['country'] as String?,
      region: r['region'] as String?,
    );
  }

  /// Inserts a name record; ignores conflicts (first write wins).
  Future<void> setZoneName(
    String id, {
    required String? continent,
    required String? country,
    required String? region,
  }) async {
    final d = await db;
    await d.insert(
      'zone_names',
      {
        'id': id,
        'continent': continent,
        'country': country,
        'region': region,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Loads every named zone together with its current state.
  /// Used at startup to re-populate the in-memory cache.
  Future<List<Zone>> getAllNamedZones() async {
    final d = await db;
    final names = await d.query('zone_names');
    if (names.isEmpty) return [];

    final ids = names.map((r) => r['id'] as String).toList();
    final states = await getZoneStates(ids);

    return names.map((r) {
      final id = r['id'] as String;
      final parsed = parseZoneId(id);
      return Zone(
        id: id,
        latIdx: parsed.latIdx,
        lonIdx: parsed.lonIdx,
        enabled: states[id] ?? true,
        continent: r['continent'] as String?,
        country: r['country'] as String?,
        region: r['region'] as String?,
      );
    }).toList();
  }

  // ── Markers ──────────────────────────────────────────────────────────────────

  Future<void> insertMarker(MarkerModel marker) async {
    final d = await db;
    await d.insert(
      'markers',
      marker.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MarkerModel>> getAllMarkers() async {
    final d = await db;
    final rows = await d.query('markers', orderBy: 'created_at ASC');
    return rows.map(MarkerModel.fromMap).toList();
  }

  Future<void> deleteMarker(String id) async {
    final d = await db;
    await d.delete('markers', where: 'id = ?', whereArgs: [id]);
  }
}
