import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../data_structures/track_metadata_item.dart';
import 'interface.dart';

class SQLiteStorage implements IDatabaseStorage {
  Database? _db;
  Directory? _appSupportDir;

  @override
  Future<void> init() async {
    if (_db != null) return;

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _appSupportDir = await getApplicationSupportDirectory();
    debugPrint("App Support Dir: $_appSupportDir");
    final dbPath = p.join(_appSupportDir!.path, 'yl_music_player', 'app_data.db');

    final dbFile = File(dbPath);
    if (!await dbFile.parent.exists()) {
      await dbFile.parent.create(recursive: true);
    }

    _db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 3) {
          // Re-create isolated table structures to guarantee non-overlapping queries
          await db.execute('DROP TABLE IF EXISTS playlist');
          await db.execute('DROP TABLE IF EXISTS current_playlist');
          await db.execute('DROP TABLE IF EXISTS file_list');
          await _createTables(db);
        }
      },
    );
  }

  String _toRelativePath(String absolutePath) {
    if (_appSupportDir == null) return absolutePath;
    final rootPath = _appSupportDir!.path;
    if (absolutePath.startsWith(rootPath)) {
      return p.relative(absolutePath, from: rootPath);
    }
    if (absolutePath.contains('/Containers/Data/Application/')) {
      return p.basename(absolutePath);
    }
    return absolutePath;
  }

  String _toAbsolutePath(String relativePath) {
    if (_appSupportDir == null || p.isAbsolute(relativePath)) {
      return relativePath;
    }
    return p.join(_appSupportDir!.path, relativePath);
  }

  Database get _database {
    if (_db == null) {
      throw StateError('SQLiteStorage has not been initialized. Call init() first.');
    }
    return _db!;
  }

  // --- Current Active Queue / Playlist Operations ---

  @override
  Future<List<String>> loadPlaylist() async {
    final results = await _database.query(
      'current_playlist',
      orderBy: 'track_order ASC',
    );

    final List<String> validPaths = [];
    final List<String> deadRelativePaths = [];

    for (final row in results) {
      final storedPath = row['file_path'] as String;
      final absolutePath = _toAbsolutePath(storedPath);

      if (await File(absolutePath).exists()) {
        validPaths.add(absolutePath);
      } else {
        deadRelativePaths.add(storedPath);
        debugPrint('[SQLiteStorage] Pruning missing current_playlist file: $storedPath');
      }
    }

    if (deadRelativePaths.isNotEmpty) {
      await _database.delete(
        'current_playlist',
        where: 'file_path IN (${List.filled(deadRelativePaths.length, '?').join(',')})',
        whereArgs: deadRelativePaths,
      );
    }

    return validPaths;
  }

  @override
  Future<void> savePlaylist(List<String> paths) async {
    final db = _database;
    await db.transaction((txn) async {
      await txn.delete('current_playlist');
      final batch = txn.batch();
      for (int i = 0; i < paths.length; i++) {
        final relPath = _toRelativePath(paths[i]);
        batch.insert('current_playlist', {
          'file_path': relPath,
          'track_order': i,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  // --- File List Library Operations ---

  @override
  Future<List<TrackMetadataItem>> loadFileList() async {
    final results = await _database.query('file_list');
    final List<TrackMetadataItem> items = [];
    final List<String> deadRelativePaths = [];

    for (final row in results) {
      final storedPath = row['file_path'] as String;
      final absolutePath = _toAbsolutePath(storedPath);

      if (await File(absolutePath).exists()) {
        items.add(TrackMetadataItem(
          filePath: absolutePath,
          title: row['title'] as String? ?? '',
          artist: row['artist'] as String? ?? 'Unknown Artist',
          album: row['album'] as String? ?? '',
          compressedArtwork: row['artwork'] as Uint8List?,
        ));
      } else {
        deadRelativePaths.add(storedPath);
        debugPrint('[SQLiteStorage] Pruning missing file_list entry: $storedPath');
      }
    }

    if (deadRelativePaths.isNotEmpty) {
      await _database.delete(
        'file_list',
        where: 'file_path IN (${List.filled(deadRelativePaths.length, '?').join(',')})',
        whereArgs: deadRelativePaths,
      );
    }

    return items;
  }

  @override
  Future<void> saveFileList(List<TrackMetadataItem> items) async {
    final db = _database;
    await db.transaction((txn) async {
      await txn.delete('file_list');
      final batch = txn.batch();
      for (final item in items) {
        final relPath = _toRelativePath(item.filePath);
        batch.insert(
          'file_list',
          {
            'file_path': relPath,
            'title': item.title,
            'artist': item.artist,
            'album': item.album,
            'artwork': item.compressedArtwork,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  // --- Metadata Cache Operations ---

  @override
  Future<void> saveCachedMetadata(TrackMetadataItem metadata) async {
    final relPath = _toRelativePath(metadata.filePath);
    await _database.insert('metadata_cache', {
      'file_path': relPath,
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
      final storedPath = row['file_path'] as String;
      final absolutePath = _toAbsolutePath(storedPath);

      if (await File(absolutePath).exists()) {
        map[absolutePath] = TrackMetadataItem(
          filePath: absolutePath,
          title: row['title'] as String? ?? '',
          artist: row['artist'] as String? ?? 'Unknown Artist',
          compressedArtwork: row['artwork'] as Uint8List?,
        );
      }
    }
    return map;
  }

  Future<void> _createTables(Database db) async {
    // 1. Current playback queue table
    await db.execute('''
      CREATE TABLE current_playlist (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL UNIQUE,
        track_order INTEGER NOT NULL
      )
    ''');

    // 2. Main local music library metadata table
    await db.execute('''
      CREATE TABLE file_list (
        file_path TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        artwork BLOB
      )
    ''');

    // 3. Temporary fast-lookup cache table
    await db.execute('''
      CREATE TABLE metadata_cache (
        file_path TEXT PRIMARY KEY,
        title TEXT,
        artist TEXT,
        artwork BLOB
      )
    ''');
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
