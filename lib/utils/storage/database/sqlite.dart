import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../data_structures/group.dart';
import '../../data_structures/track_metadata_item.dart';
import 'interface.dart';

class SQLiteStorage implements IDatabaseStorage {
  Database? _db;
  Directory? _appSupportDir;

  Database get _database {
    if (_db == null) {
      throw StateError('SQLiteStorage has not been initialized.');
    }
    return _db!;
  }

  @override
  Future<void> init() async {
    if (_db != null) return;

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _appSupportDir = await getApplicationSupportDirectory();
    final dbPath = p.join(
      _appSupportDir!.path,
      'yl_music_player',
      'app_data.db',
    );

    final dbFile = File(dbPath);
    if (!await dbFile.parent.exists()) {
      await dbFile.parent.create(recursive: true);
    }

    _db = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 6) {
          await db.execute('DROP TABLE IF EXISTS group_items');
          await db.execute('DROP TABLE IF EXISTS file_groups');
          await db.execute('DROP TABLE IF EXISTS groups');
          await db.execute('DROP TABLE IF EXISTS file_list');
          await _createTables(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS current_playlist (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      file_path TEXT NOT NULL UNIQUE,
      track_order INTEGER NOT NULL
    )
  ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS metadata_cache (
      file_path TEXT PRIMARY KEY,
      title TEXT,
      artist TEXT,
      artwork BLOB
    )
  ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS groups (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      parent_id INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (parent_id) REFERENCES groups (id) ON DELETE CASCADE
    )
  ''');

    await db.execute('''
    INSERT OR IGNORE INTO groups (id, name, parent_id) 
    VALUES (0, 'Root', 0)
  ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS file_list (
      file_path TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      artist TEXT NOT NULL,
      album TEXT NOT NULL,
      artwork BLOB,
      group_id INTEGER NOT NULL DEFAULT 0,
      track_order INTEGER DEFAULT 0,
      FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE SET DEFAULT
    )
  ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_file_list_group ON file_list(group_id, track_order)',
    );
  }

  // --- Relational Group Operations ---

  @override
  Future<int> insertGroup(String name, {int? parentId}) async {
    return await _database.insert('groups', {
      'name': name,
      'parent_id': parentId ?? 0,
    });
  }

  @override
  Future<List<GroupEntity>> fetchSubGroups({int? parentId}) async {
    final targetParentId = parentId ?? 0;
    final results = await _database.query(
      'groups',
      where: 'parent_id = ? AND id != 0',
      whereArgs: [targetParentId],
      orderBy: 'name ASC',
    );

    return results
        .map(
          (r) => GroupEntity(
        id: r['id'] as int,
        name: r['name'] as String,
        parentId: r['parent_id'] as int?,
      ),
    )
        .toList();
  }

  @override
  Future<void> assignTracksToGroup(List<String> filePaths, int? groupId) async {
    final db = _database;
    final targetGroupId = groupId ?? 0;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final path in filePaths) {
        final relPath = _toRelativePath(path);
        batch.update(
          'file_list',
          {'group_id': targetGroupId},
          where: 'file_path = ?',
          whereArgs: [relPath],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> removeTrackFromGroup(String filePath) async {
    final relPath = _toRelativePath(filePath);
    await _database.update(
      'file_list',
      {'group_id': 0},
      where: 'file_path = ?',
      whereArgs: [relPath],
    );
  }

  @override
  Future<void> renameGroup(int groupId, String newName) async {
    await _database.update(
      'groups',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }

  @override
  Future<int> fetchGroupTrackCount(int groupId) async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) as count FROM file_list WHERE group_id = ?',
      [groupId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<List<GroupedTrackMetadataItem>> fetchGroupTracksWindow(
      int groupId, {
        required int offset,
        required int limit,
      }) async {
    final results = await _database.query(
      'file_list',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'track_order ASC, title ASC',
      limit: limit,
      offset: offset,
    );

    final List<GroupedTrackMetadataItem> items = [];
    for (final row in results) {
      final storedPath = row['file_path'] as String;
      final absolutePath = _toAbsolutePath(storedPath);

      items.add(
        GroupedTrackMetadataItem(
          id: 0,
          groupId: groupId,
          filePath: absolutePath,
          title: row['title'] as String? ?? '',
          artist: row['artist'] as String? ?? 'Unknown Artist',
          album: row['album'] as String? ?? '',
          compressedArtwork: row['artwork'] as Uint8List?,
        ),
      );
    }
    return items;
  }

  @override
  Future<void> saveGroupTracksBatch(
      int groupId,
      List<GroupedTrackMetadataItem> items,
      ) async {
    final db = _database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final relPath = _toRelativePath(item.filePath);
        batch.insert(
          'file_list',
          {
            'file_path': relPath,
            'title': item.title,
            'artist': item.artist,
            'album': item.album,
            'artwork': item.compressedArtwork,
            'group_id': groupId,
            'track_order': i,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> deleteGroup(int groupId) async {
    await _database.delete('groups', where: 'id = ?', whereArgs: [groupId]);
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
      }
    }

    if (deadRelativePaths.isNotEmpty) {
      await _database.delete(
        'current_playlist',
        where:
        'file_path IN (${List.filled(deadRelativePaths.length, '?').join(',')})',
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
    final results = await _database.query(
      'file_list',
      orderBy: 'track_order ASC, title ASC',
    );
    final List<TrackMetadataItem> items = [];
    final List<String> deadRelativePaths = [];

    for (final row in results) {
      final storedPath = row['file_path'] as String;
      final absolutePath = _toAbsolutePath(storedPath);

      if (await File(absolutePath).exists()) {
        final groupId = row['group_id'] as int? ?? 0;
        items.add(
          GroupedTrackMetadataItem(
            id: 0,
            groupId: groupId,
            filePath: absolutePath,
            title: row['title'] as String? ?? '',
            artist: row['artist'] as String? ?? 'Unknown Artist',
            album: row['album'] as String? ?? '',
            compressedArtwork: row['artwork'] as Uint8List?,
          ),
        );
      } else {
        deadRelativePaths.add(storedPath);
      }
    }

    if (deadRelativePaths.isNotEmpty) {
      await _database.delete(
        'file_list',
        where:
        'file_path IN (${List.filled(deadRelativePaths.length, '?').join(',')})',
        whereArgs: deadRelativePaths,
      );
    }

    return items;
  }

  @override
  Future<void> saveFileList(List<TrackMetadataItem> items) async {
    final db = _database;
    await db.transaction((txn) async {
      final keepRelPaths = <String>{};

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final relPath = _toRelativePath(item.filePath);
        keepRelPaths.add(relPath);

        final targetGroupId =
        item is GroupedTrackMetadataItem ? item.groupId : 0;

        await txn.rawInsert('''
          INSERT INTO file_list (file_path, title, artist, album, artwork, group_id, track_order)
          VALUES (?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(file_path) DO UPDATE SET
            title = excluded.title,
            artist = excluded.artist,
            album = excluded.album,
            artwork = excluded.artwork,
            track_order = excluded.track_order,
            group_id = CASE WHEN excluded.group_id != 0 THEN excluded.group_id ELSE file_list.group_id END
        ''', [
          relPath,
          item.title,
          item.artist,
          item.album,
          item.compressedArtwork,
          targetGroupId,
          i,
        ]);
      }

      // Delete tracks removed from FileListManager without clearing existing tracks
      if (keepRelPaths.isNotEmpty) {
        final placeholders = List.filled(keepRelPaths.length, '?').join(',');
        await txn.delete(
          'file_list',
          where: 'file_path NOT IN ($placeholders)',
          whereArgs: keepRelPaths.toList(),
        );
      } else {
        await txn.delete('file_list');
      }
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

  // --- Helpers ---

  String _toRelativePath(String absolutePath) {
    if (_appSupportDir == null) return absolutePath;
    final rootPath = _appSupportDir!.path;
    if (absolutePath.startsWith(rootPath)) {
      return p.relative(absolutePath, from: rootPath);
    }
    return absolutePath;
  }

  String _toAbsolutePath(String relativePath) {
    if (_appSupportDir == null || p.isAbsolute(relativePath)) {
      return relativePath;
    }
    return p.join(_appSupportDir!.path, relativePath);
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // --- Relational Group Operations (Extended) ---

  @override
  Future<void> updateGroupParent(int groupId, int? parentId) async {
    final targetParentId = parentId ?? 0;
    await _database.update(
      'groups',
      {'parent_id': targetParentId},
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }

  @override
  Future<void> deleteGroupTracksByGroupId(int groupId) async {
    // Reset group_id to default root (0) or remove track associations
    await _database.update(
      'file_list',
      {'group_id': 0},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }
}
