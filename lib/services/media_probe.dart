/// Tier A browser-native media probe — public facade.
///
/// The probe measures real media with browser APIs only (no ffmpeg, no
/// backend, no upload): an HTML `<video>` element for container
/// metadata, canvas sampling for frames, `requestVideoFrameCallback`
/// for frame rate, and WebAudio `decodeAudioData` for audio.
///
/// Platform split (conditional import below): the web implementation
/// measures for real; every other platform returns an honest failure —
/// the pick flow surfaces "Video inspection needs the web app" and
/// never fabricates metadata.
///
/// Rule-code → measured/unmeasured mapping lives here, in ONE place
/// ([TierAProbe]). Tier A measures: duration/dimensions/fps, peak
/// dBFS + peak timecode, silence, black frames, opening darkness,
/// loudness (K-weighted approximation), waveform + thumbnail, and
/// captions-file-attached (true only when an .srt sidecar was actually
/// picked). Tier A does NOT measure (Tier B — OCR/vision):
/// subtitleBottomY/timecode, textOverflow, brandLogoPresent,
/// captionSyncOffsetMs, titleBottomY — plus brand colors, which have no
/// configured palette to compare against, so no defensible measurement
/// exists.
library;

import 'dart:typed_data';

import '../core/constants.dart';
import '../engine/models.dart';
import 'media_probe_stub.dart'
    if (dart.library.js_interop) 'media_probe_web.dart' as impl;

/// Progress callback: [stage] is a human-readable phase label
/// ("Probing video…") and [progress] is 0..1 within the whole probe.
typedef ProbeProgressCallback = void Function(String stage, double progress);

/// Cancellation check, polled between probe stages. Return true to
/// abort the probe (throws [ProbeCancelledException]).
typedef ShouldCancel = bool Function();

/// Thrown when the probe cannot run or the media cannot be read.
/// Surfaces to the user as an inspection error (exit code 2), never as
/// fake measurements.
class ProbeException implements Exception {
  /// Creates a [ProbeException].
  ProbeException(this.message);

  /// The message.
  final String message;

  @override
  String toString() => 'ProbeException: $message';
}

/// Thrown when the user cancels a probe in progress. Not an error —
/// the inspection simply does not produce a report.
class ProbeCancelledException implements Exception {}

/// Container metadata from the `<video>` element: real duration and
/// dimensions, read at pick time so the pre-inspection screen shows
/// facts before the full probe runs.
class ContainerMetadata {
  /// Creates a [ContainerMetadata].
  const ContainerMetadata({
    required this.durationSeconds,
    required this.width,
    required this.height,
  });

  /// Duration in seconds (rounded).
  final int durationSeconds;
  /// Video width in pixels.
  final int width;
  /// Video height in pixels.
  final int height;
}

/// Everything the Tier A probe measures for one file.
class ProbeResult {
  /// Creates a [ProbeResult].
  const ProbeResult({
    required this.probe,
    required this.durationSeconds,
    required this.width,
    required this.height,
    required this.fps,
    required this.frameCount,
    required this.framesSampled,
    this.frameThumbnailBase64,
    this.waveformPeaks,
  });

  /// Measured probe data (Tier B rules listed in `unmeasured`).
  final ProbeData probe;
  /// Duration in seconds (rounded).
  final int durationSeconds;
  /// Video width in pixels.
  final int width;
  /// Video height in pixels.
  final int height;
  /// Measured fps, 0 when the frame-rate estimate failed.
  final int fps;
  /// Frame count (`durationSeconds * fps`), 0 when fps is unknown.
  final int frameCount;
  /// Number of frames actually sampled by the canvas pass.
  final int framesSampled;
  /// Frame thumbnail: JPEG bytes as base64, ~320 px wide.
  final String? frameThumbnailBase64;
  /// Waveform peaks: ~200 samples normalized 0..1.
  final List<double>? waveformPeaks;
}

/// The Tier A measured/unmeasured mapping — the ONE place that decides
/// which rules a Tier A probe can and cannot measure.
abstract final class TierAProbe {
  /// Rules Tier A never measures. SUB-SAFE-01, TXT-OVER-01,
  /// BRAND-LOGO-01, CAP-SYNC-01, TITLE-SAFE-01 need OCR/vision
  /// (Tier B). BRAND-COL-01 needs a brand palette to compare against
  /// and the app configures none, so no defensible measurement exists.
  static const List<String> unmeasuredRules = [
    kRuleSubtitleSafeArea,
    kRuleTextOverflow,
    kRuleBrandLogo,
    kRuleBrandColor,
    kRuleCaptionSync,
    kRuleTitleSafeArea,
  ];

  /// Every rule code. An export that has never been probed lists all
  /// of these in `unmeasured`, so the inspector skips everything until
  /// the probe runs.
  static const List<String> allRules = [
    kRuleSubtitleSafeArea,
    kRuleAudioPeak,
    kRuleAspectRatio,
    kRuleBlackFrames,
    kRuleTextOverflow,
    kRuleBrandLogo,
    kRuleBrandColor,
    kRuleCaptionSync,
    kRuleTitleSafeArea,
    kRuleFrameRate,
    kRuleMinResolution,
    kRuleLoudness,
    kRuleOpeningFrame,
    kRuleCaptionsFile,
  ];
}

/// Placeholder probe for a picked-but-not-yet-probed export: every rule
/// unmeasured, neutral values that no rule ever evaluates (the
/// inspector skips unmeasured rules). The export's fps/frameCount stay
/// 0 until the probe runs; the UI must not divide by them.
ProbeData unprobedProbe() => const ProbeData(
      subtitleBottomY: 0,
      subtitleTimecode: '00:00:00:00',
      peakDbfs: -120,
      peakTimecode: '00:00:00:00',
      longestSilenceSeconds: 0,
      blackFrameCount: 0,
      textOverflow: false,
      brandLogoPresent: false,
      brandColorsOk: true,
      captionSyncOffsetMs: 0,
      titleBottomY: 0,
      loudnessLufs: -120,
      openingFrameDarkness: 0,
      captionsFileAttached: false,
      unmeasured: TierAProbe.allRules,
    );

/// Whether [file] still needs its first probe. A completed Tier A probe
/// always measures BLACK-FR-01 (black frames come from the video
/// frames, which every successful probe samples), so its presence in
/// `unmeasured` means the probe never ran. Old demo-probe exports
/// (unmeasured empty) do NOT need a probe here — they keep their demo
/// values until the user re-picks the file.
bool needsProbe(ExportFile file) =>
    file.probe.unmeasured.contains(kRuleBlackFrames);

/// The Tier A probe. Static facade over the platform implementation.
abstract final class MediaProbe {
  /// True on web, where the browser APIs exist. False everywhere else.
  static bool get isSupported => impl.isSupported;

  /// Reads container metadata (duration, dimensions) from [bytes]
  /// without running the full probe. Used at pick time. Throws
  /// [ProbeException] when the media cannot be read.
  static Future<ContainerMetadata> readMetadata(
    Uint8List bytes, {
    required String mimeType,
  }) =>
      impl.readMetadata(bytes, mimeType: mimeType);

  /// Runs the full Tier A probe over [bytes].
  ///
  /// [captionsFileAttached] is true only when an .srt sidecar was
  /// actually picked alongside the video. [onProgress] reports the
  /// live stage; [shouldCancel] aborts between stages (throws
  /// [ProbeCancelledException]). Throws [ProbeException] when the
  /// media cannot be read at all; a missing audio track does NOT throw
  /// — the audio rules are reported unmeasured instead.
  static Future<ProbeResult> probeVideo(
    Uint8List bytes, {
    required String mimeType,
    bool captionsFileAttached = false,
    ProbeProgressCallback? onProgress,
    ShouldCancel? shouldCancel,
  }) =>
      impl.probeVideo(
        bytes,
        mimeType: mimeType,
        captionsFileAttached: captionsFileAttached,
        onProgress: onProgress,
        shouldCancel: shouldCancel,
      );

  /// MIME type for a video file extension. Unknown extensions fall back
  /// to `video/mp4` — the browser sniffs the container from the bytes
  /// when the type is wrong, so a wrong guess degrades gracefully.
  static String mimeTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.m4v')) return 'video/mp4';
    return 'video/mp4';
  }
}
