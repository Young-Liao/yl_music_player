String formatDuration(double seconds) {
  final duration = Duration(seconds: seconds.toInt());
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$secs';
}
