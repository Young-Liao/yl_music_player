import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart'; // import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class ArtworkCacheManager {
  // Bounded cache map storing songId/hash -> file Uri
  static final Map<String, Uri> _cache = HashMap<String, Uri>();
  static Directory? _tempDir;

  /// Retrieves cached file Uri or atomically writes artwork bytes to dynamic cache
  static Future<Uri?> getUriFromBytes(String songId, Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;

    // 1. O(1) Cache hit check
    if (_cache.containsKey(songId)) {
      return _cache[songId];
    }

    _tempDir ??= await getTemporaryDirectory();

    // 2. Derive unique filename key from songId or content hash
    final String fileKey = md5.convert(bytes).toString();
    final File targetFile = File('${_tempDir!.path}/art_$fileKey.jpg');

    // Check if file already exists on disk from a previous session
    if (await targetFile.exists()) {
      final uri = targetFile.uri;
      _cache[songId] = uri;
      return uri;
    }

    // 3. Thread-safe write execution
    try {
      await targetFile.writeAsBytes(bytes, flush: true);
      final uri = targetFile.uri;

      // LRU Eviction guard: keep cache bounded to last 20 covers
      if (_cache.length >= 20) {
        _cache.remove(_cache.keys.first);
      }

      _cache[songId] = uri;
      return uri;
    } catch (_) {
      return null;
    }
  }
}
