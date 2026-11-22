/// Non-web Tier A probe: an honest failure, never fake metadata.
///
/// Video inspection needs the browser's `<video>` element, canvas, and
/// WebAudio — none of which exist off the web. Callers surface
/// [ProbeException]'s message ("Video inspection needs the web app")
/// instead of inventing measurements.
library;

import 'dart:typed_data';

import 'media_probe.dart';

/// The probe is not supported off the web.
bool get isSupported => false;

/// Always throws: no browser APIs off the web.
Future<ContainerMetadata> readMetadata(
  Uint8List bytes, {
  required String mimeType,
}) async =>
    throw ProbeException(
      'Video inspection needs the web app — this device cannot read '
      'video metadata. Open Frame Police in a browser to inspect files.',
    );

/// Always throws: no browser APIs off the web.
Future<ProbeResult> probeVideo(
  Uint8List bytes, {
  required String mimeType,
  bool captionsFileAttached = false,
  ProbeProgressCallback? onProgress,
  ShouldCancel? shouldCancel,
}) async =>
    throw ProbeException(
      'Video inspection needs the web app — this device cannot decode '
      'video or audio. Open Frame Police in a browser to inspect files.',
    );
