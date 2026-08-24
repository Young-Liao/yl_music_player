import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../data_structures/track_metadata_item.dart';
import 'interface.dart';

class SQLiteStorage implements IDatabaseStorage {
  Database? _db;

  @override
  Future<void> init() async {
    if (_db != null) return;

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      // Ensure sqlite3_flutter_libs overrides default binding on macOS
      // await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      databaseFactory = databaseFactoryFfi;
    }

    final docDir = await getApplicationSupportDirectory();
    final dbPath = p.join(docDir.path, 'yl_music_player', 'app_data.db');

    // Ensure parent directory exists
    final dbFile = File(dbPath);
    if (!await dbFile.parent.exists()) {
      await dbFile.parent.create(recursive: true);
    }

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE playlist (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT NOT NULL UNIQUE,
            track_order INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE metadata_cache (
            file_path TEXT PRIMARY KEY,
            title TEXT,
            artist TEXT,
            artwork BLOB
          )
        ''');
      },
    );
  }

  Database get _database {
    if (_db == null) {
      throw StateError(
        'SQLiteStorage has not been initialized. Call init() first.',
      );
    }
    return _db!;
  }

  @override
  Future<List<String>> loadPlaylist() async {
    final results = await _database.query(
      'playlist',
      orderBy: 'track_order ASC',
    );
    return results.map((row) => row['file_path'] as String).toList();
  }

  @override
  Future<void> savePlaylist(List<String> paths) async {
    final db = _database;
    await db.transaction((txn) async {
      await txn.delete('playlist');
      final batch = txn.batch();
      for (int i = 0; i < paths.length; i++) {
        batch.insert('playlist', {'file_path': paths[i], 'track_order': i});
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> saveCachedMetadata(TrackMetadataItem metadata) async {
    await _database.insert('metadata_cache', {
      'file_path': metadata.filePath,
      'title': metadata.title,
      'artist': metadata.artist,
      'artwork': metadata.compressedArtwork,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, TrackMetadataItem>> loadAllCachedMetadata() async {
    final results = await _database.query('metadata_cache');
    final Map<String, TrackMetadataItem> map = {};

    for (final row in results) {
      final path = row['file_path'] as String;
      map[path] = TrackMetadataItem(
        filePath: path,
        title: row['title'] as String? ?? '',
        artist: row['artist'] as String? ?? 'Unknown Artist',
        compressedArtwork: row['artwork'] as Uint8List?,
      );
    }
    return map;
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
