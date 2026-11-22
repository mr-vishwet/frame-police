/// Tier A probe, web implementation (package:web + dart:js_interop).
///
/// Measures real media with browser APIs only — no ffmpeg, no backend,
/// no upload. The file bytes stay in the tab: an object URL feeds a
/// `<video>` element (metadata, frame rate, canvas sampling) and
/// WebAudio `decodeAudioData` (peak, silence, loudness, waveform).
///
/// How each measurement is made (thresholds live in `probe_math.dart`,
/// tuned against the demo media with ffmpeg):
///
/// * Metadata — `<video>` `loadeddata`: duration, videoWidth,
///   videoHeight. A file the browser cannot decode throws
///   [ProbeException]; it is never guessed.
/// * Frame rate — `requestVideoFrameCallback` over ~2 s of muted
///   playback: presented frames divided by media-time span (exact —
///   wall-clock timing reads a frame low in headless Chrome), snapped
///   to the nearest standard rate. If playback or rVFC fails, fps is
///   0 and FRAMERATE-01 is unmeasured.
/// * Black frames — canvas samples at ~1 fps from t = 1 s (the opening
///   second is skipped: opening fades are editorial). A black sample
///   counts only inside a sustained hard-cut run: at least two
///   consecutive black samples whose run starts with a hard cut from
///   a bright frame ([countSustainedBlackFrames] in `probe_math.dart`).
///   That is why the clean Sintel trailer scores 0 — its black samples
///   are fades, dark scenes, and one isolated flash frame at t = 18 s
///   — while the defective file's injected t = 5–6 s run counts.
/// * Opening darkness — the t = 0 frame's dark-pixel fraction.
/// * Audio — `decodeAudioData` over the whole file: peak dBFS + peak
///   timecode, longest silence below −50 dBFS (10 ms windows), waveform
///   peaks (200 buckets), and K-weighted loudness (BS.1770 filters,
///   ungated approximation). A file with no decodable audio does not
///   fail the probe — AUD-PEAK-02 and SUG-LOUD-01 are unmeasured.
/// * Thumbnail — the sampled frame nearest 25% of the duration, as a
///   ~320 px JPEG (base64).
///
/// Everything the probe cannot measure is listed in
/// [ProbeData.unmeasured]; the inspector skips those rules.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../core/constants.dart';
import '../core/format.dart';
import '../engine/models.dart';
import 'media_probe.dart';
import 'probe_math.dart';

/// The probe is supported on web.
bool get isSupported => true;

/// Width of the sampling canvas in pixels. 320 px keeps the black-frame
/// pixel test honest (downscale bleed at 160 px would blur the
/// defective file's overlaid headline text into the black test) and
/// doubles as the thumbnail width.
const int _sampleWidth = 320;

/// How long the fps estimate plays before it has enough frames.
const Duration _fpsSampleWindow = Duration(milliseconds: 2000);

/// Watchdog for the fps estimate: no frames in this long means
/// playback or rVFC is broken.
const Duration _fpsWatchdog = Duration(seconds: 5);

/// Per-seek timeout while sampling frames.
const Duration _seekTimeout = Duration(seconds: 5);

/// Timeout for the video to load metadata / first frame.
const Duration _loadTimeout = Duration(seconds: 15);

/// Reads container metadata from [bytes] without running the full
/// probe. Used at pick time so the pre-inspection screen shows real
/// duration and dimensions.
Future<ContainerMetadata> readMetadata(
  Uint8List bytes, {
  required String mimeType,
}) async {
  final (:video, :objectUrl) = _createVideo(bytes, mimeType);
  try {
    await _waitForEvent(video, 'loadedmetadata');
    if (!video.duration.isFinite ||
        video.duration <= 0 ||
        video.videoWidth <= 0 ||
        video.videoHeight <= 0) {
      throw ProbeException(
        'Could not read this video file. It may be corrupt or in an '
        'unsupported format.',
      );
    }
    return ContainerMetadata(
      durationSeconds: video.duration.round(),
      width: video.videoWidth,
      height: video.videoHeight,
    );
  } finally {
    _releaseVideo(video, objectUrl);
  }
}

/// Runs the full Tier A probe over [bytes]. See the library doc comment
/// for what each stage measures.
Future<ProbeResult> probeVideo(
  Uint8List bytes, {
  required String mimeType,
  bool captionsFileAttached = false,
  ProbeProgressCallback? onProgress,
  ShouldCancel? shouldCancel,
}) async {
  void checkCancelled() {
    if (shouldCancel?.call() == true) throw ProbeCancelledException();
  }

  void report(String stage, double progress) =>
      onProgress?.call(stage, progress);

  final (:video, :objectUrl) = _createVideo(bytes, mimeType);
  try {
    report('Reading video…', 0.02);
    await _waitForEvent(video, 'loadeddata');
    checkCancelled();
    final duration = video.duration;
    if (!duration.isFinite ||
        duration <= 0 ||
        video.videoWidth <= 0 ||
        video.videoHeight <= 0) {
      throw ProbeException(
        'Could not read this video file. It may be corrupt or in an '
        'unsupported format.',
      );
    }
    final width = video.videoWidth;
    final height = video.videoHeight;
    final durationSeconds = duration.round();

    // Sampling canvas (320 px wide, aspect preserved). Also the
    // thumbnail source: the frame nearest 25% of the duration.
    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    final sampleHeight = math.max(1, (_sampleWidth * height / width).round());
    canvas.width = _sampleWidth;
    canvas.height = sampleHeight;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;

    Uint8List grabPixels() {
      ctx.drawImage(video, 0, 0, _sampleWidth, sampleHeight);
      final data =
          ctx.getImageData(0, 0, _sampleWidth, sampleHeight).data.toDart;
      return Uint8List.view(
        data.buffer,
        data.offsetInBytes,
        data.lengthInBytes,
      );
    }

    // Opening frame (t = 0): darkness for SUG-OPEN-01, mean luminance
    // as the first sample's predecessor, and the fallback thumbnail.
    final openingPixels = grabPixels();
    final openingDarkness = darkFraction(openingPixels);
    final openingMean = meanLuminance(openingPixels);
    String? thumbnail = _jpegBase64(canvas);

    // Frame rate, from ~2 s of muted playback.
    report('Measuring frame rate…', 0.12);
    final fpsEstimate = await _estimateFps(video, shouldCancel);
    checkCancelled();
    final fps = snapFps(fpsEstimate);
    final unmeasured = <String>[...TierAProbe.unmeasuredRules];
    if (fps <= 0) unmeasured.add(kRuleFrameRate);

    // Frame sampling at ~1 fps.
    report('Sampling frames…', 0.25);
    final times = frameSampleTimes(duration);
    var thumbnailIndex = -1;
    if (times.isNotEmpty) {
      final target = duration * 0.25;
      var bestGap = double.infinity;
      for (var i = 0; i < times.length; i++) {
        final gap = (times[i] - target).abs();
        if (gap < bestGap) {
          bestGap = gap;
          thumbnailIndex = i;
        }
      }
    }
    var framesSampled = 0;
    final sampleIsBlack = <bool>[];
    final sampleMeans = <double>[];
    for (var i = 0; i < times.length; i++) {
      checkCancelled();
      await _seekTo(video, times[i]);
      final pixels = grabPixels();
      sampleIsBlack.add(isBlackFrame(pixels));
      sampleMeans.add(meanLuminance(pixels));
      framesSampled++;
      if (i == thumbnailIndex) thumbnail = _jpegBase64(canvas);
      report(
        'Sampling frames…',
        0.25 + 0.5 * (i + 1) / times.length,
      );
    }
    // Black frames count only inside sustained hard-cut runs (a single
    // isolated black sample is a flash frame at a scene cut, and a run
    // fading in from a dark scene is editorial — see probe_math).
    final blackFrames = countSustainedBlackFrames(
      isBlack: sampleIsBlack,
      means: sampleMeans,
      openingMean: openingMean,
    );

    // Audio, decoded last: it is the slowest stage for long files, and
    // running it after the video stages keeps progress monotonic.
    report('Decoding audio…', 0.82);
    var peakDbfs = kDbfsFloor;
    var peakTimecode = '00:00:00:00';
    var longestSilence = 0.0;
    var loudness = kDbfsFloor;
    List<double>? waveform;
    var hasAudio = false;
    try {
      final audio = await _decodeAudio(bytes);
      if (audio != null) {
        hasAudio = true;
        final channels = audio.channels;
        final sampleRate = audio.sampleRate;
        final peak = findPeak(channels);
        peakDbfs = peak.dbfs;
        final timecodeFps = fps > 0 ? fps : 24;
        peakTimecode = formatTimecode(
          (peak.timeSeconds(sampleRate) * timecodeFps).round(),
          timecodeFps,
        );
        longestSilence = longestSilenceSeconds(channels, sampleRate);
        loudness = kWeightedLoudness(channels);
        waveform = waveformPeaks(channels);
      }
    } on Object catch (_) {
      // No audio track, or audio the browser cannot decode: the audio
      // rules are unmeasured, not zero. The video measurements stand.
      hasAudio = false;
    }
    if (!hasAudio) {
      unmeasured.add(kRuleAudioPeak);
      unmeasured.add(kRuleLoudness);
    }
    checkCancelled();
    report('Finishing…', 1.0);

    return ProbeResult(
      probe: ProbeData(
        subtitleBottomY: 0,
        subtitleTimecode: '00:00:00:00',
        peakDbfs: peakDbfs,
        peakTimecode: peakTimecode,
        longestSilenceSeconds: longestSilence,
        blackFrameCount: blackFrames,
        textOverflow: false,
        brandLogoPresent: false,
        brandColorsOk: true,
        captionSyncOffsetMs: 0,
        titleBottomY: 0,
        loudnessLufs: loudness,
        openingFrameDarkness: openingDarkness,
        captionsFileAttached: captionsFileAttached,
        unmeasured: unmeasured,
      ),
      durationSeconds: durationSeconds,
      width: width,
      height: height,
      fps: fps,
      frameCount: fps > 0 ? (duration * fps).round() : 0,
      framesSampled: framesSampled,
      frameThumbnailBase64: thumbnail,
      waveformPeaks: waveform,
    );
  } finally {
    _releaseVideo(video, objectUrl);
  }
}

/// Creates an off-DOM muted `<video>` element fed by an object URL over
/// [bytes]. The element is never attached to the document: metadata,
/// seeking, canvas capture, and muted playback all work off-DOM.
({web.HTMLVideoElement video, String objectUrl}) _createVideo(
  Uint8List bytes,
  String mimeType,
) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  final video =
      web.document.createElement('video') as web.HTMLVideoElement;
  video.muted = true;
  video.playsInline = true;
  video.preload = 'auto';
  video.src = objectUrl;
  return (video: video, objectUrl: objectUrl);
}

/// Releases a probe video: stop playback, drop the source, revoke the
/// object URL so the browser can free the bytes.
void _releaseVideo(web.HTMLVideoElement video, String objectUrl) {
  video.pause();
  video.removeAttribute('src');
  video.load();
  web.URL.revokeObjectURL(objectUrl);
}

/// Waits for [type] on [target] (or an `error`, which fails the probe).
/// Throws [ProbeException] on error or timeout.
Future<void> _waitForEvent(
  web.EventTarget target,
  String type,
) async {
  final completer = Completer<void>();
  void onEvent(JSAny? _) {
    if (!completer.isCompleted) completer.complete();
  }

  void onError(JSAny? _) {
    if (!completer.isCompleted) {
      completer.completeError(ProbeException(
        'Could not read this video file. It may be corrupt or in an '
        'unsupported format.',
      ));
    }
  }

  final eventFn = onEvent.toJS;
  final errorFn = onError.toJS;
  target.addEventListener(type, eventFn);
  target.addEventListener('error', errorFn);
  try {
    await completer.future.timeout(_loadTimeout);
  } on TimeoutException {
    throw ProbeException('Loading the video timed out.');
  } finally {
    target.removeEventListener(type, eventFn);
    target.removeEventListener('error', errorFn);
  }
}

/// The `VideoFrameMetadata` dictionary passed to a
/// `requestVideoFrameCallback` handler. Not declared in package:web
/// (its `VideoFrameRequestCallback` is an untyped `JSFunction`).
extension type _VideoFrameMetadata(JSObject _) implements JSObject {
  /// The media timestamp of the presented frame, in seconds.
  external double get mediaTime;

  /// The number of frames presented so far.
  external int get presentedFrames;
}

/// Estimates the frame rate from ~2 s of muted playback via
/// `requestVideoFrameCallback`: presented frames divided by media-time
/// span, both read from the callback metadata. Media timestamps are
/// exact — the earlier wall-clock version read 23 fps for a 24 fps
/// file in headless Chrome, because callback invocation lags stretch
/// the measured span. Falls back to wall-clock counting when the
/// metadata is unavailable. Returns 0 when playback or rVFC fails
/// (fps is then unmeasured).
Future<double> _estimateFps(
  web.HTMLVideoElement video,
  ShouldCancel? shouldCancel,
) async {
  final completer = Completer<double>();
  var count = 0;
  var firstMs = 0.0;
  var lastMs = 0.0;
  var firstMediaTime = -1.0;
  var lastMediaTime = 0.0;
  var firstPresented = 0;
  var lastPresented = 0;
  var useMetadata = true;
  var done = false;

  double currentEstimate() {
    if (useMetadata) {
      final frames = lastPresented - firstPresented;
      final span = lastMediaTime - firstMediaTime;
      if (frames > 0 && span > 0) return frames / span;
      return 0;
    }
    if (count < 2) return 0;
    final spanSeconds = (lastMs - firstMs) / 1000;
    if (spanSeconds <= 0) return 0;
    return (count - 1) / spanSeconds;
  }

  void finish() {
    if (done) return;
    done = true;
    if (!completer.isCompleted) completer.complete(currentEstimate());
  }

  late final void Function(JSAny?, JSAny?) frameCallback;
  frameCallback = (JSAny? now, JSAny? metadata) {
    if (done) return;
    final t = (now as JSNumber).toDartDouble;
    if (count == 0) firstMs = t;
    lastMs = t;
    count++;
    if (useMetadata) {
      try {
        final meta = _VideoFrameMetadata(metadata as JSObject);
        final mediaTime = meta.mediaTime;
        final presented = meta.presentedFrames;
        if (firstMediaTime < 0) {
          firstMediaTime = mediaTime;
          firstPresented = presented;
        }
        lastMediaTime = mediaTime;
        lastPresented = presented;
      } on Object catch (_) {
        // Metadata unreadable (old browser): wall-clock fallback.
        useMetadata = false;
      }
    }
    final spanReached = useMetadata
        ? lastMediaTime - firstMediaTime >=
            _fpsSampleWindow.inMilliseconds / 1000
        : lastMs - firstMs >= _fpsSampleWindow.inMilliseconds;
    if (shouldCancel?.call() == true || spanReached) {
      finish();
      return;
    }
    video.requestVideoFrameCallback(frameCallback.toJS);
  };

  void onEnded(JSAny? _) => finish();
  final endedFn = onEnded.toJS;
  video.addEventListener('ended', endedFn);
  final watchdog = Timer(_fpsWatchdog, finish);
  try {
    try {
      // Headless browsers can leave play() pending (no compositor to
      // begin playback): time it out rather than hanging the probe.
      await video
          .play()
          .toDart
          .timeout(const Duration(seconds: 5));
    } on Object catch (_) {
      // Playback refused or never started (autoplay policy, decode
      // error, headless): no fps.
      return 0;
    }
    try {
      video.requestVideoFrameCallback(frameCallback.toJS);
    } on Object catch (_) {
      // rVFC unsupported: no fps.
      return 0;
    }
    return await completer.future;
  } finally {
    watchdog.cancel();
    video.removeEventListener('ended', endedFn);
    video.pause();
  }
}

/// Seeks [video] to [time] seconds and waits for the `seeked` event.
/// A no-op when already there (setting `currentTime` to its own value
/// fires no event).
Future<void> _seekTo(web.HTMLVideoElement video, double time) async {
  if ((video.currentTime - time).abs() < 0.01) return;
  final completer = Completer<void>();
  void onSeeked(JSAny? _) {
    if (!completer.isCompleted) completer.complete();
  }

  void onError(JSAny? _) {
    if (!completer.isCompleted) {
      completer.completeError(
        ProbeException('Could not seek the video.'),
      );
    }
  }

  final seekedFn = onSeeked.toJS;
  final errorFn = onError.toJS;
  video.addEventListener('seeked', seekedFn);
  video.addEventListener('error', errorFn);
  try {
    video.currentTime = time;
    await completer.future.timeout(_seekTimeout);
  } on TimeoutException {
    throw ProbeException('Seeking the video timed out.');
  } finally {
    video.removeEventListener('seeked', seekedFn);
    video.removeEventListener('error', errorFn);
  }
}

/// Decodes the audio track from the container bytes. Returns null when
/// the file has no audio track; throws when the audio cannot be
/// decoded. The input buffer is copied before decoding (see
/// [_arrayBufferOf]), so the caller's bytes survive.
Future<({List<Float32List> channels, int sampleRate})?> _decodeAudio(
  Uint8List bytes,
) async {
  final context = web.AudioContext();
  try {
    // Decode of a long file can take a while; 60 s is the safety net
    // — a timeout surfaces as "no audio" (unmeasured), not a hang.
    final buffer = await context
        .decodeAudioData(_arrayBufferOf(bytes))
        .toDart
        .timeout(const Duration(seconds: 60));
    if (buffer.numberOfChannels == 0 || buffer.length == 0) return null;
    final channels = <Float32List>[];
    for (var c = 0; c < buffer.numberOfChannels; c++) {
      channels.add(buffer.getChannelData(c).toDart);
    }
    return (channels: channels, sampleRate: buffer.sampleRate.round());
  } finally {
    // Close the context (Chrome caps concurrent contexts); never let a
    // stuck close hang the probe.
    try {
      await context.close().toDart.timeout(const Duration(seconds: 5));
    } on Object catch (_) {
      // A failed close leaks one context; the probe result stands.
    }
  }
}

/// Extension to reach the `buffer` property of a [JSUint8Array], which
/// `dart:js_interop` does not expose as a getter. `decodeAudioData`
/// needs the underlying [JSArrayBuffer].
extension type _JSUint8ArrayBuffer(JSUint8Array _) implements JSObject {
  external JSArrayBuffer get buffer;
}

/// The [JSArrayBuffer] for [bytes]. Always a COPY: `decodeAudioData`
/// detaches its input buffer, and the caller's bytes must survive the
/// probe — the picker cache holds them for re-inspection.
JSArrayBuffer _arrayBufferOf(Uint8List bytes) =>
    _JSUint8ArrayBuffer(Uint8List.fromList(bytes).toJS).buffer;

/// The canvas as a JPEG data URL, returned as raw base64 (no prefix).
/// Null when the canvas cannot be exported.
String? _jpegBase64(web.HTMLCanvasElement canvas) {
  try {
    final url = canvas.toDataURL('image/jpeg', 0.7.toJS);
    const prefix = 'data:image/jpeg;base64,';
    if (url.startsWith(prefix)) return url.substring(prefix.length);
    return null;
  } on Object catch (_) {
    return null;
  }
}
