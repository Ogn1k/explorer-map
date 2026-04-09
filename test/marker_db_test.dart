import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:explorer/db/database_helper.dart';
import 'package:explorer/models/marker_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<String> _tempDbPath() async {
    final dir = await Directory.systemTemp.createTemp('explorer_db_test');
    return p.join(dir.path, 'fog_of_war.db');
  }

  Future<void> _createV1Schema(Database db) async {
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
    await db.execute(
      'CREATE INDEX idx_zone_names_continent ON zone_names(continent)',
    );
  }

  test('migrates v1 DB to v2 and creates markers table', () async {
    final path = await _tempDbPath();
    final factory = databaseFactoryFfi;

    final dbV1 = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await _createV1Schema(db);
        },
      ),
    );
    await dbV1.close();

    final helper = DatabaseHelper.test(
      databaseFactory: factory,
      dbPath: path,
    );
    final dbV2 = await helper.db;

    final tables = await dbV2.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='markers'",
    );

    expect(tables.length, 1);
    expect(await dbV2.getVersion(), 2);
    await dbV2.close();
  });

  test('marker persists after restart with same coordinates', () async {
    final path = await _tempDbPath();
    final factory = databaseFactoryFfi;

    final helper1 = DatabaseHelper.test(
      databaseFactory: factory,
      dbPath: path,
    );
    final marker = MarkerModel(
      id: 'm_test',
      lat: 55.0,
      lon: 37.0,
      createdAt: 1234567890,
    );
    await helper1.insertMarker(marker);
    final db1 = await helper1.db;
    await db1.close();

    final helper2 = DatabaseHelper.test(
      databaseFactory: factory,
      dbPath: path,
    );
    final markers = await helper2.getAllMarkers();

    expect(markers.length, 1);
    expect(markers.first.lat, closeTo(marker.lat, 1e-9));
    expect(markers.first.lon, closeTo(marker.lon, 1e-9));
    expect(markers.first.createdAt, marker.createdAt);
    await (await helper2.db).close();
  });
}
