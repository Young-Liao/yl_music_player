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

  // Time guard delay configuration
  static const Duration _saveDelay = Duration(milliseconds: 500);

  Future<void> init() async {
    final docDir = await getApplicationDocumentsDirectory();
    final path = p.join(docDir.path, 'yl_music_player', 'settings.json');
    _settingsFile = File(path);

    if (await _settingsFile!.exists()) {
      try {
        final content = await _settingsFile!.readAsString();
        _cache = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        _cache = {};
      }
    } else {
      await _settingsFile!.parent.create(recursive: true);
      await _saveNow();
    }
  }

  /// Schedules a write to disk after [_saveDelay].
  /// Rapid calls restart the timer, writing only once after activity stops.
  void _scheduleSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_saveDelay, () async {
      await _saveNow();
    });
  }

  /// Performs immediate, un-debounced write (useful on app exit/pause)
  Future<void> _saveNow() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (_settingsFile == null) return;
    try {
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

  /// Flushes pending changes directly to disk synchronously/immediately
  Future<void> flush() async {
    if (_debounceTimer?.isActive ?? false) {
      await _saveNow();
    }
  }
}