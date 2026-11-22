/// File System Access API, web implementation (package:web +
/// dart:js_interop).
///
/// package:web 1.1.2 declares the handle types (`FileSystemHandle`,
/// `FileSystemFileHandle`, `FileSystemDirectoryHandle`) and IndexedDB,
/// but not `showOpenFilePicker` / `showDirectoryPicker`, directory
/// iteration, or handle permissions — those are declared here as small
/// `dart:js_interop` extension types.
///
/// Handles are persisted in IndexedDB (database `frame-police-fsa`,
/// store `handles`, keyed by an opaque `fsa_` key). A stored handle
/// survives restarts; re-reading it re-requests read permission when
/// the browser requires it. Nothing leaves the device: handles point
/// at the user's own files, and reads happen in the tab.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'file_system_access.dart';
import 'media_probe.dart';

// --- window entry points (not declared in package:web) --------------------

/// Probes for the File System Access entry points without calling them.
extension type _WindowFSAProbe(JSObject _) implements JSObject {
  external JSAny? get showOpenFilePicker;
  external JSAny? get showDirectoryPicker;
}

/// Options for `showOpenFilePicker`. The `types` filter is omitted
/// deliberately: building the MIME → extensions record needs unsafe
/// interop, and the extension is validated in Dart afterwards anyway.
extension type _OpenFilePickerOptions._(JSObject _) implements JSObject {
  external factory _OpenFilePickerOptions({bool multiple});
}

/// The picker entry points on [web.Window].
extension type _WindowFSA(web.Window _) implements web.Window {
  external JSPromise<JSArray<web.FileSystemFileHandle>> showOpenFilePicker([
    _OpenFilePickerOptions options,
  ]);
  external JSPromise<web.FileSystemDirectoryHandle> showDirectoryPicker();
}

/// Reads the `name` of a rejected JS error (to spot `AbortError` =
/// the user cancelled the dialog).
extension type _JSErrorName(JSObject _) implements JSObject {
  external String? get name;
}

// --- handle permissions (not declared in package:web) ---------------------

/// Options for `requestPermission` / `queryPermission`.
extension type _FileSystemPermissionOptions._(JSObject _)
    implements JSObject {
  external factory _FileSystemPermissionOptions({String mode});
}

/// `getFile` + permission methods, re-wrapped onto [web.FileSystemHandle]
/// (directory iteration yields plain handles, which cannot be cast to
/// the file subtype through the public API).
extension type _FileSystemHandleOps(web.FileSystemHandle _)
    implements web.FileSystemHandle {
  external JSPromise<web.File> getFile();
  external JSPromise<JSString> requestPermission([
    _FileSystemPermissionOptions options,
  ]);
}

// --- directory iteration (async iterators, not declared in package:web) ---

/// A JS async iterator (`{ next(): Promise<{value, done}> }`).
extension type _AsyncIterator<T extends JSAny?>(JSObject _)
    implements JSObject {
  external JSPromise<_IteratorResult<T>> next();
}

/// One step of an async iterator.
extension type _IteratorResult<T extends JSAny?>(JSObject _)
    implements JSObject {
  external T get value;
  external bool get done;
}

/// `values()` on a directory handle: an async iterator of handles.
extension type _DirectoryHandleIterable(web.FileSystemDirectoryHandle _)
    implements web.FileSystemDirectoryHandle {
  external JSObject values();
}

// --- IndexedDB handle store -------------------------------------------------

const String _dbName = 'frame-police-fsa';
const String _storeName = 'handles';
const int _dbVersion = 1;

/// Timeout for IndexedDB operations (open / read / write).
const Duration _idbTimeout = Duration(seconds: 10);

/// Opens (creating on first use) the handle database.
Future<web.IDBDatabase> _openDb() async {
  final request = web.window.indexedDB.open(_dbName, _dbVersion);
  final completer = Completer<web.IDBDatabase>();
  request.onupgradeneeded = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    if (!db.objectStoreNames.contains(_storeName)) {
      db.createObjectStore(_storeName);
    }
  }).toJS;
  request.onsuccess = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.complete(request.result as web.IDBDatabase);
    }
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(
        ProbeException('Could not open the local handle store.'),
      );
    }
  }).toJS;
  return completer.future.timeout(
    _idbTimeout,
    onTimeout: () => throw ProbeException(
      'Opening the local handle store timed out.',
    ),
  );
}

/// Awaits an [web.IDBRequest], resolving with [readResult].
Future<T> _idbRequest<T>(
  web.IDBRequest request,
  T Function(web.IDBRequest request) readResult,
) {
  final completer = Completer<T>();
  request.onsuccess = ((web.Event _) {
    if (!completer.isCompleted) completer.complete(readResult(request));
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(
        ProbeException('A local handle-store request failed.'),
      );
    }
  }).toJS;
  return completer.future.timeout(
    _idbTimeout,
    onTimeout: () =>
        throw ProbeException('A local handle-store request timed out.'),
  );
}

/// Persists [handle] under a fresh opaque key. Returns the key.
Future<String> _persistHandle(web.FileSystemHandle handle) async {
  final key =
      'fsa_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1 << 32).toRadixString(16)}';
  final db = await _openDb();
  try {
    final store = db
        .transaction(_storeName.toJS, 'readwrite')
        .objectStore(_storeName);
    await _idbRequest(store.put(handle, key.toJS), (_) => null);
  } finally {
    db.close();
  }
  return key;
}

/// Loads a persisted handle, or null when the key is unknown.
Future<web.FileSystemHandle?> _loadHandle(String handleKey) async {
  final db = await _openDb();
  try {
    final store =
        db.transaction(_storeName.toJS, 'readonly').objectStore(_storeName);
    final result = await _idbRequest(
      store.get(handleKey.toJS),
      (request) => request.result,
    );
    if (result == null) return null;
    return result as web.FileSystemHandle;
  } finally {
    db.close();
  }
}

// --- implementation ---------------------------------------------------------

/// True when both picker entry points exist (Chromium).
bool get isSupported {
  try {
    final probe = _WindowFSAProbe(web.window);
    return probe.showOpenFilePicker != null &&
        probe.showDirectoryPicker != null;
  } on Object catch (_) {
    return false;
  }
}

bool _isAbort(Object error) {
  if (error is JSObject) {
    try {
      return _JSErrorName(error).name == 'AbortError';
    } on Object catch (_) {
      return false;
    }
  }
  return false;
}

/// Reads a handle's file into memory.
Future<Uint8List> _readHandleBytes(web.FileSystemHandle handle) async {
  final file = await _FileSystemHandleOps(handle)
      .getFile()
      .toDart
      .timeout(const Duration(seconds: 30));
  final jsBuffer = await file
      .arrayBuffer()
      .toDart
      .timeout(const Duration(seconds: 120));
  final dartBuffer = jsBuffer.toDart;
  return Uint8List.view(dartBuffer, 0, dartBuffer.lengthInBytes);
}

/// Picks one video file with the system dialog. Null when the user
/// cancels; [ProbeException] when the picked file is not a video.
Future<FsaPickedFile?> pickVideoFile() async {
  final window = _WindowFSA(web.window);
  late final List<web.FileSystemFileHandle> handles;
  try {
    final jsHandles = await window
        .showOpenFilePicker(_OpenFilePickerOptions(multiple: false))
        .toDart;
    handles = jsHandles.toDart;
  } on Object catch (e) {
    if (_isAbort(e)) return null;
    rethrow;
  }
  if (handles.isEmpty) return null;
  final handle = handles.first;
  final name = handle.name;
  if (!isVideoFile(name)) {
    throw ProbeException(
      '"$name" is not a video file. Pick an mp4, mov, webm, mkv or '
      'm4v file.',
    );
  }
  final bytes = await _readHandleBytes(handle);
  String? handleKey;
  try {
    handleKey = await _persistHandle(handle);
  } on Object catch (_) {
    // A failed persist must not fail the pick: the file is picked and
    // inspected; only re-inspection-after-restart is lost.
    handleKey = null;
  }
  return FsaPickedFile(name: name, bytes: bytes, handleKey: handleKey);
}

/// Lists a directory's entries (top level, sorted by name).
Future<List<web.FileSystemHandle>> _listDirectory(
  web.FileSystemDirectoryHandle dir,
) async {
  final iterator = _AsyncIterator<web.FileSystemHandle>(
    _DirectoryHandleIterable(dir).values(),
  );
  final entries = <web.FileSystemHandle>[];
  while (true) {
    final step = await iterator.next().toDart;
    if (step.done) break;
    entries.add(step.value);
  }
  entries.sort((a, b) => a.name.compareTo(b.name));
  return entries;
}

/// Filename stem (name without its last extension), lowercased, for
/// `.srt` sidecar matching.
String _stem(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final stem = dot <= 0 ? fileName : fileName.substring(0, dot);
  return stem.toLowerCase();
}

/// Picks a folder and returns every video file in it (top level only,
/// sorted by name), each with its bytes, persisted handle, and sidecar
/// flag. Empty list when the user cancels.
Future<List<FsaPickedFile>> pickDirectoryVideos() async {
  final window = _WindowFSA(web.window);
  late final web.FileSystemDirectoryHandle dir;
  try {
    dir = await window.showDirectoryPicker().toDart;
  } on Object catch (e) {
    if (_isAbort(e)) return [];
    rethrow;
  }
  final entries = await _listDirectory(dir);
  final srtStems = <String>{};
  for (final entry in entries) {
    if (entry.kind == 'file' &&
        entry.name.toLowerCase().endsWith('.srt')) {
      srtStems.add(_stem(entry.name));
    }
  }
  final videos = <FsaPickedFile>[];
  for (final entry in entries) {
    if (entry.kind != 'file' || !isVideoFile(entry.name)) continue;
    try {
      final bytes = await _readHandleBytes(entry);
      String? handleKey;
      try {
        handleKey = await _persistHandle(entry);
      } on Object catch (_) {
        handleKey = null;
      }
      videos.add(FsaPickedFile(
        name: entry.name,
        bytes: bytes,
        handleKey: handleKey,
        captionsFileAttached: srtStems.contains(_stem(entry.name)),
      ));
    } on Object catch (_) {
      // One unreadable file must not take the whole folder down.
      continue;
    }
  }
  return videos;
}

/// Re-reads a file from its persisted handle (re-requesting read
/// permission when the browser asks). Null when the handle is gone or
/// permission is denied.
Future<Uint8List?> readPersistedFile(String handleKey) async {
  final handle = await _loadHandle(handleKey);
  if (handle == null) return null;
  final ops = _FileSystemHandleOps(handle);
  final permission = await ops
      .requestPermission(_FileSystemPermissionOptions(mode: 'read'))
      .toDart
      .timeout(const Duration(seconds: 30));
  if (permission.toDart != 'granted') return null;
  try {
    return await _readHandleBytes(handle);
  } on Object catch (_) {
    return null;
  }
}

/// Forgets a persisted handle.
Future<void> forgetHandle(String handleKey) async {
  final db = await _openDb();
  try {
    final store = db
        .transaction(_storeName.toJS, 'readwrite')
        .objectStore(_storeName);
    await _idbRequest(store.delete(handleKey.toJS), (_) => null);
  } finally {
    db.close();
  }
}
