/// File picking for exports to inspect.
///
/// Picks video files (mp4/mov/webm/mkv) via `file_picker` with
/// `withData: true`, so the picked file's bytes are in memory — or, on
/// Chromium, via the File System Access API
/// (`services/file_system_access.dart`), which additionally persists
/// the file's handle so re-inspection survives a restart. The bytes
/// are read for real: container metadata (duration, dimensions) comes
/// from the Tier A probe's `<video>` element at pick time, and the
/// full probe runs over the same bytes at inspection time.
///
/// The bytes live in a session-only cache ([bytesFor]) keyed by export
/// id. They are never persisted — local storage cannot hold video — so
/// a restart drops them and a stored export must be re-picked (or
/// re-read from its persisted FSA handle) to re-measure. Nothing is
/// ever uploaded: the probe runs entirely in the browser, on the
/// device.
///
/// Off the web there is no `<video>` element and no WebAudio, so
/// picking fails honestly with "Video inspection needs the web app"
/// instead of inventing metadata.
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../engine/models.dart';
import 'file_system_access.dart';
import 'media_probe.dart';

/// File picker service.
class FilePickerService {
  /// Session-only bytes cache: export id → file bytes. Dropped on
  /// restart (see the library doc comment).
  final Map<String, Uint8List> _bytesByExportId = {};

  /// Bytes for a previously picked export, or null when the export was
  /// loaded from storage in this session (bytes were never persisted)
  /// or the id is unknown.
  Uint8List? bytesFor(String exportId) => _bytesByExportId[exportId];

  /// Caches [bytes] for [exportId] (used by the demo loader, which
  /// reads its videos from assets rather than the picker).
  void cacheBytes(String exportId, Uint8List bytes) {
    _bytesByExportId[exportId] = bytes;
  }

  /// Drops cached bytes for [exportId].
  void dropBytes(String exportId) {
    _bytesByExportId.remove(exportId);
  }

  /// Picks one video file and builds an [ExportFile] for it with real
  /// container metadata and the unprobed placeholder probe (the full
  /// Tier A probe runs at inspection time, over the cached bytes).
  /// Returns null when the user cancels. Throws [ProbeException] when
  /// the file cannot be read — including off the web, where video
  /// inspection is unavailable.
  ///
  /// On Chromium the pick goes through the File System Access API, so
  /// the file's handle is persisted and re-inspection survives a
  /// restart. Any FSA failure (except the user cancelling, and except
  /// the honest "not a video" error) falls back to the plain picker.
  Future<ExportFile?> pickExport() async {
    if (!MediaProbe.isSupported) {
      // Fail before opening the picker: there is no point picking a
      // file this platform cannot measure.
      throw ProbeException(
        'Video inspection needs the web app — this device cannot read '
        'video metadata. Open Frame Police in a browser to inspect '
        'files.',
      );
    }
    if (FileSystemAccess.isSupported) {
      // The pick itself is fallible (API quirk, permissions); a failed
      // pick falls back to the plain picker. A user cancel returns
      // null and must NOT open a second dialog — hence the flag.
      FsaPickedFile? picked;
      var fsaFailed = false;
      try {
        picked = await FileSystemAccess.pickVideoFile();
      } on ProbeException {
        // Honest errors (not a video) surface — no fallback dialog.
        rethrow;
      } on Object catch (_) {
        fsaFailed = true;
      }
      if (!fsaFailed) {
        if (picked == null) return null;
        return exportFromBytes(
          name: picked.name,
          bytes: picked.bytes,
          fsaHandleKey: picked.handleKey,
        );
      }
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'webm', 'mkv', 'm4v'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = await _bytesOf(file);
    return exportFromBytes(name: file.name, bytes: bytes);
  }

  /// Bytes for a picked file. `withData: true` preloads them on web
  /// (file_picker 8.x reads the whole file via FileReader); the stream
  /// path covers a file returned with a read stream instead.
  Future<Uint8List> _bytesOf(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    final stream = file.readStream;
    if (stream != null) {
      final chunks = <int>[];
      await for (final chunk in stream) {
        chunks.addAll(chunk);
      }
      return Uint8List.fromList(chunks);
    }
    throw ProbeException(
      'Could not read ${file.name}. The picker returned no file data.',
    );
  }

  /// Builds an [ExportFile] from picked-file bytes: reads real
  /// container metadata via the Tier A probe and returns the export
  /// with the unprobed placeholder probe (every rule unmeasured,
  /// fps/frameCount 0 until the inspection-time probe runs). The bytes
  /// are cached under the export's id for that probe.
  ///
  /// Throws [ProbeException] when the file cannot be read (corrupt,
  /// unsupported, or a non-web platform).
  Future<ExportFile> exportFromBytes({
    required String name,
    required Uint8List bytes,
    bool isDemo = false,
    String? id,
    String? fsaHandleKey,
  }) async {
    final metadata = await MediaProbe.readMetadata(
      bytes,
      mimeType: MediaProbe.mimeTypeFor(name),
    );
    final export = ExportFile(
      id: id ?? 'exp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      durationSeconds: metadata.durationSeconds,
      // Unknown until the inspection-time probe estimates fps.
      frameCount: 0,
      width: metadata.width,
      height: metadata.height,
      fps: 0,
      sizeBytes: bytes.lengthInBytes,
      addedAt: DateTime.now(),
      // declaredAspect defaults to the export's own real aspect.
      probe: unprobedProbe(),
      isDemo: isDemo,
      fsaHandleKey: fsaHandleKey,
    );
    cacheBytes(export.id, bytes);
    return export;
  }

  /// Builds an [ExportFile] from a completed Tier A [ProbeResult]
  /// (the demo loader's path: the probe already ran, so the export
  /// carries measured values, a thumbnail, and a waveform).
  ExportFile exportFromProbe({
    required String name,
    required int sizeBytes,
    required ProbeResult result,
    bool isDemo = false,
    String? id,
  }) =>
      ExportFile(
        id: id ?? 'exp_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        durationSeconds: result.durationSeconds,
        frameCount: result.frameCount,
        width: result.width,
        height: result.height,
        fps: result.fps,
        sizeBytes: sizeBytes,
        addedAt: DateTime.now(),
        probe: result.probe,
        isDemo: isDemo,
        frameThumbnailBase64: result.frameThumbnailBase64,
        waveformPeaks: result.waveformPeaks,
      );
}
