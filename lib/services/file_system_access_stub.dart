/// File System Access API, non-web implementation: unsupported.
///
/// The API exists only in Chromium browsers. Callers check
/// [isSupported] and fall back to the plain picker.
library;

import 'dart:typed_data';

import 'file_system_access.dart';

/// The File System Access API is not supported off the web.
bool get isSupported => false;

/// Never called (guarded by [isSupported]); throws if reached.
Future<FsaPickedFile?> pickVideoFile() async =>
    throw UnsupportedError('File System Access is not supported here.');

/// Never called (guarded by [isSupported]); throws if reached.
Future<List<FsaPickedFile>> pickDirectoryVideos() async =>
    throw UnsupportedError('File System Access is not supported here.');

/// No handles exist off the web.
Future<Uint8List?> readPersistedFile(String handleKey) async => null;

/// No handles exist off the web.
Future<void> forgetHandle(String handleKey) async {}
