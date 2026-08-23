import 'package:file_picker/file_picker.dart';

/// Opens the system file picker to select multiple music tracks.
Future<List<String>> pickMultipleMusicFiles() async {
  // Direct static call returning List<PlatformFile>
  final List<PlatformFile> files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg'],
  );

  if (files.isEmpty) {
    return []; // User canceled
  }

  // Extract non-null file paths (Desktop & Mobile)
  return files
      .map((file) => file.path)
      .whereType<String>()
      .toList();
}
