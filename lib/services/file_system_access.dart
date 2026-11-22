/// File System Access API — public facade.
///
/// On Chromium browsers, files are picked with `showOpenFilePicker` /
/// `showDirectoryPicker` instead of the plain file picker, and the
/// picked file's handle is persisted in IndexedDB. Re-inspection after
/// a restart re-reads the file from its stored handle (with a
/// permission prompt) instead of asking the user to pick the file
/// again. Folder pick additionally finds `.srt` sidecars by filename
/// stem, so the captions-file rule measures for real.
///
/// On non-Chromium browsers (and off the web) the API is absent and
/// the picker falls back to `file_picker` — see
/// [FilePickerService.pickExport]. The FSA pick itself cannot be
/// tested headlessly (the dialog needs a real user gesture); the
/// capability check and the IndexedDB handle store are covered by
/// tests, and the dialog flows need a human click in a real browser.
library;

import 'dart:typed_data';

import 'file_system_access_stub.dart'
    if (dart.library.js_interop) 'file_system_access_web.dart' as impl;

/// A file picked through the File System Access API.
class FsaPickedFile {
  /// Creates an [FsaPickedFile].
  const FsaPickedFile({
    required this.name,
    required this.bytes,
    this.handleKey,
    this.captionsFileAttached = false,
  });

  /// The file name.
  final String name;
  /// The file bytes.
  final Uint8List bytes;

  /// Key of the persisted handle in IndexedDB, for re-inspection after
  /// a restart. Null when the handle could not be persisted.
  final String? handleKey;

  /// True when an `.srt` sidecar with the same filename stem was found
  /// in the picked folder.
  final bool captionsFileAttached;
}

/// Video extensions the picker accepts.
const List<String> kVideoExtensions = ['mp4', 'mov', 'webm', 'mkv', 'm4v'];

/// Whether [fileName] has a video extension.
bool isVideoFile(String fileName) {
  final lower = fileName.toLowerCase();
  return kVideoExtensions.any((ext) => lower.endsWith('.$ext'));
}

/// The File System Access API. Static facade over the platform
/// implementation.
abstract final class FileSystemAccess {
  /// True on Chromium browsers, where `showOpenFilePicker` /
  /// `showDirectoryPicker` exist. False everywhere else.
  static bool get isSupported => impl.isSupported;

  /// Picks one video file with the system dialog. Returns null when
  /// the user cancels. Throws [ProbeException] when the picked file is
  /// not a video; other failures propagate to the caller, which falls
  /// back to the plain picker.
  static Future<FsaPickedFile?> pickVideoFile() => impl.pickVideoFile();

  /// Picks a folder and returns every video file in it (top level
  /// only, sorted by name), each with its bytes, persisted handle, and
  /// sidecar flag. Returns an empty list when the user cancels.
  static Future<List<FsaPickedFile>> pickDirectoryVideos() =>
      impl.pickDirectoryVideos();

  /// Re-reads a file from its persisted handle (re-requesting read
  /// permission when the browser asks). Returns null when the handle
  /// is gone or permission is denied.
  static Future<Uint8List?> readPersistedFile(String handleKey) =>
      impl.readPersistedFile(handleKey);

  /// Forgets a persisted handle.
  static Future<void> forgetHandle(String handleKey) =>
      impl.forgetHandle(handleKey);
}
