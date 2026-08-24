import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SettingsStorage {
  static final SettingsStorage instance = SettingsStorage._();
  SettingsStorage._();

  File? _settingsFile;
  Map<String, dynamic> _cache = {};
  Timer? _debounceTimer;

  static const Duration _saveDelay = Duration(milliseconds: 500);

  Future<void> init() async {
    // 1. Use ApplicationSupportDirectory to bypass Windows OneDrive Documents redirection
    final appSupportDir = await getApplicationSupportDirectory();
    final folderPath = p.join(appSupportDir.path, 'yl_music_player');

    // 2. Ensure target directory exists
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final filePath = p.join(folderPath, 'settings.json');
    _settingsFile = File(filePath);

    if (await _settingsFile!.exists()) {
      try {
        final content = await _settingsFile!.readAsString();
        _cache = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        _cache = {};
      }
    } else {
      await _saveNow();
    }
  }

  void _scheduleSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_saveDelay, () async {
      await _saveNow();
    });
  }

  Future<void> _saveNow() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (_settingsFile == null) return;
    try {
      if (!await _settingsFile!.parent.exists()) {
        await _settingsFile!.parent.create(recursive: true);
      }
      await _settingsFile!.writeAsString(jsonEncode(_cache));
    } catch (e) {
      // Handle write error
    }
  }

  // Key-Value API
  T? get<T>(String key) => _cache[key] as T?;

  Future<void> set(String key, dynamic value) async {
    _cache[key] = value;
    _scheduleSave();
  }

  // Common Getters/Setters
  int get themeIndex => get<int>('themeIndex') ?? 0;
  Future<void> setThemeIndex(int index) => set('themeIndex', index);

  double get volume => (get<num>('volume') ?? 1.0).toDouble();
  Future<void> setVolume(double volume) => set('volume', volume);

  int get lastTrackIndex => get<int>('lastTrackIndex') ?? 0;
  Future<void> setLastTrackIndex(int index) => set('lastTrackIndex', index);

  Future<void> flush() async {
    if (_debounceTimer?.isActive ?? false) {
      await _saveNow();
    }
  }
}
