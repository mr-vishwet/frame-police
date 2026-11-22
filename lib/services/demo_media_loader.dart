/// Demo media, loaded through the real pipeline.
///
/// On first launch the app ships three real videos (Sintel trailer,
/// CC-BY 3.0 — see `assets/demo/DEMO_MEDIA.md`): a clean 720p control,
/// a genuine 480p low-resolution file, and a constructed defective file
/// (black frames + clipped audio + burnt-in text defects). Each one is
/// loaded from assets and probed through the real Tier A probe, so the
/// demo exports carry measured values — not the old hash-derived seeds.
///
/// The defective file's black-frame and clipped-audio defects ARE
/// detected by the Tier A probe; its text-overflow and subtitle defects
/// honestly report unmeasured (they need OCR/vision = Tier B). Note the
/// clean file is a hot-mastered trailer: its true peak sits near
/// 0 dBFS, above the −1.0 dBFS ceiling, so a faithful probe reports one
/// audio-peak defect on it. That is the media telling the truth, not a
/// probe error — "clean" in the manifest means "no injected defects".
library;

import 'package:flutter/services.dart';

import '../engine/models.dart';
import 'file_picker_service.dart';
import 'media_probe.dart';

/// One demo video: its asset path, stable export id, and display name.
class DemoAsset {
  /// Creates a [DemoAsset].
  const DemoAsset({
    required this.assetPath,
    required this.exportId,
    required this.name,
  });

  /// The asset path.
  final String assetPath;
  /// The stable export id.
  final String exportId;
  /// The display name.
  final String name;
}

/// The three demo videos, in manifest order.
const List<DemoAsset> kDemoAssets = [
  DemoAsset(
    assetPath: 'assets/demo/frame-police-clean-720p.mp4',
    exportId: 'demo_clean_720p',
    name: 'frame-police-clean-720p.mp4',
  ),
  DemoAsset(
    assetPath: 'assets/demo/frame-police-lowres-480p.mp4',
    exportId: 'demo_lowres_480p',
    name: 'frame-police-lowres-480p.mp4',
  ),
  DemoAsset(
    assetPath: 'assets/demo/frame-police-defective-mixed.mp4',
    exportId: 'demo_defective_mixed',
    name: 'frame-police-defective-mixed.mp4',
  ),
];

/// Loads the demo videos through the real Tier A probe.
class DemoMediaLoader {
  /// Creates a [DemoMediaLoader].
  DemoMediaLoader({required FilePickerService picker}) : _picker = picker;

  final FilePickerService _picker;

  /// Loads and probes every demo video. Returns the probed exports
  /// (isDemo: true) with their bytes cached in the picker for later
  /// re-inspection. A video that fails to probe is skipped; the load
  /// only throws when NOTHING loads (or when the platform has no probe
  /// at all — see [ProbeException]).
  Future<List<ExportFile>> load() async {
    if (!MediaProbe.isSupported) {
      throw ProbeException(
        'Video inspection needs the web app — this device cannot '
        'decode video or audio.',
      );
    }
    final exports = <ExportFile>[];
    for (final asset in kDemoAssets) {
      try {
        final data = await rootBundle.load(asset.assetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final result = await MediaProbe.probeVideo(
          bytes,
          mimeType: 'video/mp4',
        );
        final export = _picker.exportFromProbe(
          name: asset.name,
          sizeBytes: bytes.lengthInBytes,
          result: result,
          isDemo: true,
          id: asset.exportId,
        );
        // The probe copies bytes before decoding audio, so these bytes
        // survive for later re-inspection.
        _picker.cacheBytes(export.id, bytes);
        exports.add(export);
      } on Object catch (_) {
        // One broken demo video must not take the other two down.
        // (In practice all three are known-good mp4s.)
        continue;
      }
    }
    if (exports.isEmpty) {
      throw ProbeException(
        'The demo videos could not be loaded. Pick a file to inspect.',
      );
    }
    return exports;
  }
}
