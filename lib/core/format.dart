/// Formatting helpers: timecodes, durations, decibels, byte sizes.
///
/// Pure functions, no Flutter dependency — safe to use from the engine,
/// the reporter, and tests.
library;

/// Formats a duration in seconds as `MM:SS`.
String formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// Formats a frame index as a timecode `HH:MM:SS:FF` at [fps].
String formatTimecode(int frame, int fps) {
  final totalSeconds = frame ~/ fps;
  final frames = frame % fps;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}:'
      '${frames.toString().padLeft(2, '0')}';
}

/// Formats a byte count as `86.4 MB` / `2.1 GB` / `480 KB`.
String formatBytes(int bytes) {
  if (bytes >= 1000000000) {
    return '${(bytes / 1000000000).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1000000) {
    return '${(bytes / 1000000).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1000) {
    return '${(bytes / 1000).toStringAsFixed(0)} KB';
  }
  return '$bytes B';
}

/// Formats a decibel value as `−0.8 dBFS` (minus sign, one decimal).
String formatDbfs(double value) {
  final text = value.toStringAsFixed(1).replaceFirst('-', '−');
  return '$text dBFS';
}

/// Formats an integer with thousands separators: `1,128`.
String formatInt(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Formats a [DateTime] as `12 Nov 2026, 09:41` (local time).
String formatTimestamp(DateTime when) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = when.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day ${months[local.month - 1]} ${local.year}, $hour:$minute';
}

/// Relative label for a timestamp: `just now`, `yesterday`, `2 days ago`.
String formatRelative(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 2) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 30) return '${diff.inDays} days ago';
  return formatTimestamp(when);
}
