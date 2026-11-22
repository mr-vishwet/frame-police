/// Pure probe math for the Tier A browser-native probe.
///
/// Everything here is platform-independent and unit-testable on the VM:
/// dBFS conversion, peak/silence/waveform analysis over decoded PCM,
/// frame-luminance tests over RGBA pixels, K-weighted loudness, and fps
/// snapping. The web probe (`media_probe_web.dart`) gathers the raw
/// samples (canvas pixels, decoded audio); this file decides what they
/// mean. No `dart:html`, no `package:web` — safe to import from tests.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Silence threshold: audio below this is dead air (AUD-PEAK-02).
const double kSilenceThresholdDbfs = -50.0;

/// dBFS floor for silence / zero amplitude. -120 dBFS is effectively
/// digital silence; it keeps the log domain finite.
const double kDbfsFloor = -120.0;

/// A frame counts as black when its mean luminance is at most this
/// (0..255 scale) AND at least [kBlackPixelFraction] of its pixels are
/// at most [kBlackPixelLuminance]. Tuned against the demo media with
/// ffmpeg (see `media_probe.dart`): the defective file's injected black
/// runs measure mean 0.58 / 99.75% dark, the clean file's dark scenes
/// measure mean 0.54–0.93 / 99.66–100% dark — pixel values alone cannot
/// tell a render gap from a dark scene, so the sustained-run rule
/// ([countSustainedBlackFrames]) does that job.
const double kBlackMeanLuminance = 2.0;

/// Pixel luminance ceiling for the black-frame pixel test.
const double kBlackPixelLuminance = 16.0;

/// Minimum fraction of pixels at or below [kBlackPixelLuminance].
const double kBlackPixelFraction = 0.99;

/// A black run counts as a render gap only when the sampled frame
/// before the run was brighter than this mean luminance — a hard cut
/// into black. A run that fades in from a dark scene is editorial,
/// not a defect.
const double kHardCutPreviousLuminance = 30.0;

/// Minimum length of a black run (in ~1 fps samples) for it to count
/// as a render gap. A single isolated black sample is a flash frame at
/// a scene cut — the clean demo trailer has one at t=18 (mean 0.00,
/// bright frames either side) — not a defect. A run of two or more
/// samples is black for at least a second: a render gap or missing
/// media.
const int kMinBlackRunSamples = 2;

/// Pixel luminance below this counts as dark for the opening-frame
/// darkness fraction (SUG-OPEN-01).
const double kDarkPixelLuminance = 64.0;

/// Maximum frame samples per probe. A 20 s video samples ~1 fps
/// (19 frames); longer videos spread the same budget evenly.
const int kMaxFrameSamples = 120;

/// Converts a linear amplitude (0..1, may exceed 1 for clipped float
/// audio) to dBFS, floored at [kDbfsFloor].
double amplitudeToDbfs(double amplitude) {
  if (amplitude <= 0) return kDbfsFloor;
  final db = 20 * math.log(amplitude) / math.ln10;
  return db < kDbfsFloor ? kDbfsFloor : db;
}

/// Converts dBFS back to a linear amplitude.
double dbfsToAmplitude(double dbfs) => math.pow(10, dbfs / 20).toDouble();

/// The loudest sample across all channels.
class AudioPeak {
  /// Creates an [AudioPeak].
  const AudioPeak({required this.amplitude, required this.sampleIndex});

  /// Peak linear amplitude (max |sample|).
  final double amplitude;

  /// Sample index of the peak (in the first channel that reaches it).
  final int sampleIndex;

  /// Peak in dBFS.
  double get dbfs => amplitudeToDbfs(amplitude);

  /// Peak time in seconds at [sampleRate].
  double timeSeconds(int sampleRate) => sampleIndex / sampleRate;
}

/// Finds the peak across [channels] (each a mono Float32List of the
/// same length). Returns amplitude 0 / index 0 for empty input.
AudioPeak findPeak(List<Float32List> channels) {
  var peak = 0.0;
  var index = 0;
  for (final channel in channels) {
    for (var i = 0; i < channel.length; i++) {
      final value = channel[i].abs();
      if (value > peak) {
        peak = value;
        index = i;
      }
    }
  }
  return AudioPeak(amplitude: peak, sampleIndex: index);
}

/// Longest stretch of dead air in seconds: consecutive 10 ms windows
/// whose peak stays below [thresholdDbfs]. Windowed (not
/// sample-by-sample) so a single stray sample does not break a silence.
double longestSilenceSeconds(
  List<Float32List> channels,
  int sampleRate, {
  double thresholdDbfs = kSilenceThresholdDbfs,
}) {
  if (channels.isEmpty || sampleRate <= 0) return 0;
  final length = channels.first.length;
  if (length == 0) return 0;
  final threshold = dbfsToAmplitude(thresholdDbfs);
  // 10 ms windows, at least 1 sample.
  final window = math.max(1, sampleRate ~/ 100);
  final windowSeconds = window / sampleRate;
  var longest = 0.0;
  var run = 0.0;
  for (var start = 0; start < length; start += window) {
    final end = math.min(start + window, length);
    var silent = true;
    for (final channel in channels) {
      for (var i = start; i < end; i++) {
        if (channel[i].abs() >= threshold) {
          silent = false;
          break;
        }
      }
      if (!silent) break;
    }
    if (silent) {
      run += windowSeconds;
      if (run > longest) longest = run;
    } else {
      run = 0;
    }
  }
  return longest;
}

/// Waveform peaks for the report view: [buckets] values in 0..1, each
/// the max |sample| in its slice, normalized by the overall peak.
/// Returns all zeros for silent input.
List<double> waveformPeaks(
  List<Float32List> channels, {
  int buckets = 200,
}) {
  if (channels.isEmpty || buckets <= 0) return const [];
  final length = channels.first.length;
  if (length == 0) return List<double>.filled(buckets, 0);
  final peak = findPeak(channels).amplitude;
  final result = List<double>.filled(buckets, 0);
  for (var b = 0; b < buckets; b++) {
    final start = (b * length / buckets).floor();
    final end = ((b + 1) * length / buckets).floor();
    var max = 0.0;
    for (final channel in channels) {
      for (var i = start; i < end && i < channel.length; i++) {
        final value = channel[i].abs();
        if (value > max) max = value;
      }
    }
    result[b] = peak > 0 ? max / peak : 0;
  }
  return result;
}

// --- K-weighted loudness (BS.1770 approximation) ------------------------
//
// Two biquad filters in series (48 kHz coefficients from BS.1770-4,
// as published in libebur128): a high-frequency shelving filter, then
// a high-pass. Integrated loudness is -0.691 + 10*log10 of the summed
// per-channel mean square after filtering. This is an UNGATED
// approximation: BS.1770's absolute/relative gating is not implemented,
// so quiet passages pull the number down slightly. For typical
// mastered exports the ungated value sits within ~1 LU of the gated
// one; the value is labelled an approximation wherever it shows.
// At sample rates other than 48 kHz the fixed coefficients shift the
// shelf corner slightly — still a defensible approximation for
// 44.1/48 kHz content, which covers real exports.

/// K-weighting stage 1 (shelving) b coefficients.
const List<double> _kShelfB = [
  1.53512485958697,
  -2.69169618940638,
  1.19839281085285,
];

/// K-weighting stage 1 (shelving) a coefficients (a0 = 1).
const List<double> _kShelfA = [1.0, -1.69065929318241, 0.73248077421585];

/// K-weighting stage 2 (high-pass) b coefficients.
const List<double> _kHpB = [1.0, -2.0, 1.0];

/// K-weighting stage 2 (high-pass) a coefficients (a0 = 1).
const List<double> _kHpA = [1.0, -1.99004745483398, 0.99007225036621];

/// BS.1770 calibration offset.
const double _kLoudnessOffset = -0.691;

/// Integrated loudness in LUFS (K-weighted, ungated approximation).
/// Returns [kDbfsFloor] for silent input.
double kWeightedLoudness(List<Float32List> channels) {
  if (channels.isEmpty) return kDbfsFloor;
  final length = channels.first.length;
  if (length == 0) return kDbfsFloor;
  var sumMeanSquare = 0.0;
  for (final channel in channels) {
    // Direct Form I biquad state, per stage.
    var x1s = 0.0;
    var x2s = 0.0;
    var y1s = 0.0;
    var y2s = 0.0;
    var x1h = 0.0;
    var x2h = 0.0;
    var y1h = 0.0;
    var y2h = 0.0;
    var sumSquares = 0.0;
    for (var i = 0; i < channel.length; i++) {
      final x = channel[i].toDouble();
      // Stage 1: shelving.
      final yShelf = _kShelfB[0] * x +
          _kShelfB[1] * x1s +
          _kShelfB[2] * x2s -
          _kShelfA[1] * y1s -
          _kShelfA[2] * y2s;
      x2s = x1s;
      x1s = x;
      y2s = y1s;
      y1s = yShelf;
      // Stage 2: high-pass.
      final y = _kHpB[0] * yShelf +
          _kHpB[1] * x1h +
          _kHpB[2] * x2h -
          _kHpA[1] * y1h -
          _kHpA[2] * y2h;
      x2h = x1h;
      x1h = yShelf;
      y2h = y1h;
      y1h = y;
      sumSquares += y * y;
    }
    sumMeanSquare += sumSquares / channel.length;
  }
  if (sumMeanSquare <= 0) return kDbfsFloor;
  return _kLoudnessOffset + 10 * math.log(sumMeanSquare) / math.ln10;
}

// --- frame pixels ---------------------------------------------------------

/// Rec. 709 luminance of one pixel (0..255).
double _luminance(int r, int g, int b) =>
    0.2126 * r + 0.7152 * g + 0.0722 * b;

/// Mean luminance of RGBA pixel data (0..255). [rgba] is row-major,
/// 4 bytes per pixel (canvas `getImageData` layout).
double meanLuminance(Uint8List rgba) {
  if (rgba.isEmpty) return 0;
  final pixels = rgba.length ~/ 4;
  var sum = 0.0;
  for (var i = 0; i < pixels; i++) {
    final o = i * 4;
    sum += _luminance(rgba[o], rgba[o + 1], rgba[o + 2]);
  }
  return sum / pixels;
}

/// Fraction of pixels darker than [threshold] (0..1). The opening-frame
/// darkness measure.
double darkFraction(Uint8List rgba, {double threshold = kDarkPixelLuminance}) {
  if (rgba.isEmpty) return 0;
  final pixels = rgba.length ~/ 4;
  var dark = 0;
  for (var i = 0; i < pixels; i++) {
    final o = i * 4;
    if (_luminance(rgba[o], rgba[o + 1], rgba[o + 2]) < threshold) dark++;
  }
  return dark / pixels;
}

/// Whether a frame is black by pixels alone: mean luminance at most
/// [kBlackMeanLuminance] and at least [kBlackPixelFraction] of pixels at
/// most [kBlackPixelLuminance]. Deliberately has NO max-pixel test: the
/// defective demo video's black frames carry overlaid white headline
/// text, so a max test would miss real render gaps.
bool isBlackFrame(Uint8List rgba) {
  if (rgba.isEmpty) return false;
  final pixels = rgba.length ~/ 4;
  var sum = 0.0;
  var darkPixels = 0;
  for (var i = 0; i < pixels; i++) {
    final o = i * 4;
    final lum = _luminance(rgba[o], rgba[o + 1], rgba[o + 2]);
    sum += lum;
    if (lum <= kBlackPixelLuminance) darkPixels++;
  }
  return sum / pixels <= kBlackMeanLuminance &&
      darkPixels / pixels >= kBlackPixelFraction;
}

/// Counts the sampled black frames that belong to a render gap.
///
/// [isBlack] / [means] are the per-sample results in time order
/// (one sample per second, from t=1); [openingMean] is the t=0
/// frame's mean luminance, the predecessor of the first sample.
///
/// A maximal run of consecutive black samples counts when BOTH hold:
///  - the run is at least [kMinBlackRunSamples] long (sustained black,
///    not a single flash frame at a scene cut), and
///  - the sample before the run was bright (mean above
///    [kHardCutPreviousLuminance] — a hard cut into black, not a fade
///    out of a dark scene).
/// The count is the number of sampled frames inside qualifying runs.
///
/// Measured against the demo media (ffmpeg, 320 px): clean/lowres
/// score 0 (their black samples are fades, dark scenes, or the single
/// t=18 flash frame); the defective file scores 2 (its t=5–6 injected
/// run). Its second injected run (t=12–13) sits inside a dark scene,
/// so no luminance rule can tell it from the scene — an honest limit
/// of 1 fps sampling, not a rule bug.
int countSustainedBlackFrames({
  required List<bool> isBlack,
  required List<double> means,
  required double openingMean,
}) {
  assert(isBlack.length == means.length);
  var count = 0;
  var i = 0;
  while (i < isBlack.length) {
    if (!isBlack[i]) {
      i++;
      continue;
    }
    // Start of a black run; find its end.
    var j = i;
    while (j < isBlack.length && isBlack[j]) {
      j++;
    }
    final runLength = j - i;
    final previousMean = i == 0 ? openingMean : means[i - 1];
    if (runLength >= kMinBlackRunSamples &&
        previousMean > kHardCutPreviousLuminance) {
      count += runLength;
    }
    i = j;
  }
  return count;
}

// --- sampling + fps -------------------------------------------------------

/// Frame sample times in seconds: integer seconds from t = 1.0 (the
/// opening second is skipped — opening fades are editorial, and the
/// opening frame is measured separately for SUG-OPEN-01). Capped at
/// [kMaxFrameSamples] by widening the step for long videos.
List<double> frameSampleTimes(double durationSeconds) {
  if (durationSeconds <= 1) return const [];
  // Sample at t = 1, 2, ..., while t < duration.
  final times = <double>[];
  var t = 1.0;
  while (t < durationSeconds) {
    times.add(t);
    t += 1;
  }
  if (times.length <= kMaxFrameSamples) return times;
  final step = durationSeconds / kMaxFrameSamples;
  final sparse = <double>[];
  var s = 1.0;
  while (s < durationSeconds && sparse.length < kMaxFrameSamples) {
    sparse.add(s);
    s += step;
  }
  return sparse;
}

/// Snaps an fps estimate to the nearest standard rate when within
/// 0.5 fps (covers NTSC 23.976/29.97/59.94, which snap to 24/30/60),
/// otherwise rounds. Returns 0 for a non-positive estimate.
int snapFps(double estimate) {
  if (estimate <= 0) return 0;
  const standardRates = [24.0, 25.0, 30.0, 48.0, 50.0, 60.0];
  for (final rate in standardRates) {
    if ((estimate - rate).abs() <= 0.5) return rate.toInt();
  }
  return estimate.round();
}
