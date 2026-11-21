/// File picking for exports to inspect.
///
/// Picks video files (mp4/mov/webm/mkv) via `file_picker`. On native
/// platforms the picked file's bytes are available but v0.1 does not
/// decode media — the probe is the deterministic demo probe (see
/// `Inspector.demoProbeFor`), labelled DEMO in the report. Duration,
/// dimensions, and frame count are derived deterministically from the
/// file's name and size for the same reason; the native media probe is
/// phase 2.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../engine/inspector.dart';
import '../engine/models.dart';

class FilePickerService {
  /// Picks one video file and builds an [ExportFile] for it with a
  /// deterministic demo probe. Returns null when the user cancels.
  Future<ExportFile?> pickExport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'webm', 'mkv', 'm4v'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    return exportFromPicked(
      name: file.name,
      sizeBytes: file.size,
    );
  }

  /// Builds an [ExportFile] from picked-file metadata. Pure function so
  /// tests can verify the derivation without the picker.
  static ExportFile exportFromPicked({
    required String name,
    required int sizeBytes,
  }) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode('$name|$sizeBytes')) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    // Deterministic stand-ins, labelled DEMO in the UI.
    final durationSeconds = 30 + (hash % 121); // 30–150 s
    final vertical = ((hash >> 8) & 0x1) == 1;
    final width = vertical ? 1080 : 1920;
    final height = vertical ? 1920 : 1080;
    const fps = 24;
    return ExportFile(
      id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      durationSeconds: durationSeconds,
      frameCount: durationSeconds * fps,
      width: width,
      height: height,
      fps: fps,
      sizeBytes: sizeBytes,
      addedAt: DateTime.now(),
      declaredAspect: vertical ? '9:16' : '16:9',
      probe: Inspector.demoProbeFor(name, sizeBytes),
    );
  }
}
