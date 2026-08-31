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

/// Opens the system directory picker to select a folder path.
Future<String?> pickMusicFolder() async {
  // Use getDirectoryPath to let the user select a folder
  final String? selectedDirectoryPath = await FilePicker.getDirectoryPath(
    dialogTitle: 'Select Music Folder',
  );

  if (selectedDirectoryPath == null || selectedDirectoryPath.isEmpty) {
    return null; // User canceled
  }

  return selectedDirectoryPath;
}
