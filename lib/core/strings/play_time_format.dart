/// "0:48": a play time in minutes and seconds. The same in every language
/// (the app keeps Western digits).
String formatPlayTime(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
