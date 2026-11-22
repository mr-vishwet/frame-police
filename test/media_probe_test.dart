/// Tier A probe tests.
///
/// Two halves. The pure-math + contract tests run on the VM: dBFS
/// conversion, peak/silence/waveform analysis, black-frame pixel
/// tests, K-weighted loudness, fps snapping, and the Contract A/B
/// JSON + skip behavior. The probe tests are Chrome-only (skipped on
/// the VM): they load the three demo videos through the real Tier A
/// probe and assert measured differences.
///
/// The Chrome tests fetch the videos over HTTP from `test/fixtures/`
/// (byte-identical copies of `assets/demo/`, md5-verified) instead of
/// `rootBundle`: Flutter 3.50.1's `--platform chrome` test runner does
/// not serve `build/unit_test_assets` at all (verified in the
/// flutter_tools source — its shelf cascade has no handler for them),
/// so `rootBundle.load` hangs forever in Chrome tests, even for a 1 KB
/// SVG. The app's real path (`DemoMediaLoader` via `rootBundle`) is
/// unaffected — a built web app serves its assets normally.
///
/// Honesty note on the clean file's peak: the task brief asserted
/// `clean peakDbfs <= -1.0`, but the clean Sintel trailer is mastered
/// hot — ffmpeg `astats` measures its true peak at +0.76 dBFS, above
/// the −1.0 dBFS ceiling. No faithful probe can report it below −1.0.
/// The test therefore asserts the honest separation instead: the
/// defective file's peak exceeds the clean file's by a wide margin
/// (clipping), and the clean peak sits in the hot-master band near
/// 0 dBFS. See the report for the full numbers.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frame_police/core/constants.dart';
import 'package:frame_police/engine/inspector.dart';
import 'package:frame_police/engine/models.dart';
import 'package:frame_police/engine/registry.dart';
import 'package:frame_police/services/file_system_access.dart';
import 'package:frame_police/services/media_probe.dart';
import 'package:frame_police/services/probe_math.dart';

import 'fixture_loader.dart';

/// Synthetic RGBA pixels: every pixel the same [luminance] (grey).
Uint8List _greyPixels(int luminance, {int pixels = 100}) {
  final rgba = Uint8List(pixels * 4);
  for (var i = 0; i < pixels; i++) {
    rgba[i * 4] = luminance;
    rgba[i * 4 + 1] = luminance;
    rgba[i * 4 + 2] = luminance;
    rgba[i * 4 + 3] = 255;
  }
  return rgba;
}

/// A mono sine at [amplitude] and [frequencyHz], [seconds] long.
Float32List _sine({
  required double amplitude,
  required double frequencyHz,
  required double seconds,
  int sampleRate = 48000,
}) {
  final length = (seconds * sampleRate).round();
  final samples = Float32List(length);
  for (var i = 0; i < length; i++) {
    samples[i] =
        (amplitude * math.sin(2 * math.pi * frequencyHz * i / sampleRate))
            .toDouble();
  }
  return samples;
}

ExportFile _exportWithProbe(ProbeData probe) => ExportFile(
      id: 'exp_test',
      name: 'test.mp4',
      durationSeconds: 20,
      frameCount: 480,
      width: 1280,
      height: 720,
      fps: 24,
      sizeBytes: 1000000,
      addedAt: DateTime.utc(2026, 11, 22),
      probe: probe,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('probe math', () {
    test('amplitudeToDbfs converts and floors', () {
      expect(amplitudeToDbfs(1.0), closeTo(0, 0.001));
      expect(amplitudeToDbfs(0.5), closeTo(-6.0206, 0.001));
      expect(amplitudeToDbfs(0.1), closeTo(-20, 0.001));
      expect(amplitudeToDbfs(0), kDbfsFloor);
      expect(amplitudeToDbfs(-1), kDbfsFloor);
      // Clipped float audio above full scale stays positive.
      expect(amplitudeToDbfs(4.0), closeTo(12.0412, 0.001));
    });

    test('dbfsToAmplitude round-trips', () {
      expect(dbfsToAmplitude(amplitudeToDbfs(0.37)), closeTo(0.37, 0.001));
      expect(dbfsToAmplitude(-50), closeTo(0.0031623, 0.000001));
    });

    test('findPeak finds the loudest sample across channels', () {
      final left = Float32List.fromList([0.1, -0.9, 0.2]);
      final right = Float32List.fromList([0.1, 0.2, 0.5]);
      final peak = findPeak([left, right]);
      expect(peak.amplitude, closeTo(0.9, 0.001));
      expect(peak.sampleIndex, 1);
      expect(peak.dbfs, closeTo(-0.915, 0.01));
      expect(peak.timeSeconds(48000), closeTo(1 / 48000, 0.000001));
    });

    test('longestSilenceSeconds finds the longest dead-air run', () {
      // 1 s loud, 2 s silent, 0.5 s loud, 1 s silent — at 48 kHz.
      const sampleRate = 48000;
      final signal = Float32List(4 * sampleRate + sampleRate ~/ 2);
      for (var i = 0; i < sampleRate; i++) {
        signal[i] = 0.5;
      }
      for (var i = 3 * sampleRate; i < 3 * sampleRate + sampleRate ~/ 2; i++) {
        signal[i] = 0.5;
      }
      final silence = longestSilenceSeconds([signal], sampleRate);
      expect(silence, closeTo(2.0, 0.05));
    });

    test('longestSilenceSeconds is 0 for continuous audio', () {
      final signal = _sine(amplitude: 0.5, frequencyHz: 440, seconds: 1);
      expect(longestSilenceSeconds([signal], 48000), 0);
    });

    test('waveformPeaks normalizes to the overall peak', () {
      final signal = Float32List.fromList([0.0, 0.5, 0.0, 1.0, 0.0, 0.25]);
      final peaks = waveformPeaks([signal], buckets: 3);
      expect(peaks.length, 3);
      expect(peaks[0], closeTo(0.5, 0.001));
      expect(peaks[1], closeTo(1.0, 0.001));
      expect(peaks[2], closeTo(0.25, 0.001));
    });

    test('waveformPeaks is all zeros for silence', () {
      final peaks = waveformPeaks([Float32List(1000)], buckets: 200);
      expect(peaks.length, 200);
      expect(peaks.every((p) => p == 0), isTrue);
    });

    test('meanLuminance and darkFraction measure grey frames', () {
      expect(meanLuminance(_greyPixels(0)), 0);
      expect(meanLuminance(_greyPixels(255)), closeTo(255, 0.01));
      expect(darkFraction(_greyPixels(0)), 1.0);
      expect(darkFraction(_greyPixels(255)), 0.0);
      expect(darkFraction(_greyPixels(63)), 1.0);
      expect(darkFraction(_greyPixels(64)), 0.0);
    });

    test('isBlackFrame counts pure black and near-black with text', () {
      // Pure black.
      expect(isBlackFrame(_greyPixels(0)), isTrue);
      // Near-black with a few bright pixels (the defective demo
      // video's black frames carry overlaid white headline text —
      // ~0.25% bright pixels at full res, mean ~0.6).
      final withText = _greyPixels(0, pixels: 10000);
      for (var i = 0; i < 25; i++) {
        withText[i * 4] = 255;
        withText[i * 4 + 1] = 255;
        withText[i * 4 + 2] = 255;
      }
      expect(isBlackFrame(withText), isTrue);
      // Bright and mid-grey frames are not black.
      expect(isBlackFrame(_greyPixels(255)), isFalse);
      expect(isBlackFrame(_greyPixels(60)), isFalse);
    });

    test('countSustainedBlackFrames counts only sustained hard-cut runs',
        () {
      int count(List<bool> isBlack, List<double> means,
              {double openingMean = 0}) =>
          countSustainedBlackFrames(
            isBlack: isBlack,
            means: means,
            openingMean: openingMean,
          );

      // Sustained run after a hard cut: both frames count.
      expect(
        count(
          [false, true, true, false],
          [70, 0.5, 0.5, 100],
        ),
        2,
      );
      // Single isolated black frame (flash frame at a cut): not a defect.
      expect(
        count(
          [false, true, false],
          [75, 0, 23],
        ),
        0,
      );
      // Run fading in from a dark scene: editorial, not a defect.
      expect(
        count(
          [false, true, true, false],
          [9, 0.5, 0.5, 100],
        ),
        0,
      );
      // Two qualifying runs both count.
      expect(
        count(
          [false, true, true, false, true, true, false],
          [70, 0.5, 0.5, 100, 0.5, 0.5, 100],
        ),
        4,
      );
      // Run at the start uses the opening frame as predecessor: a black
      // opening (fade-in) excludes it, a bright opening counts it.
      expect(
        count(
          [true, true, false],
          [0.5, 0.5, 100],
          openingMean: 0,
        ),
        0,
      );
      expect(
        count(
          [true, true, false],
          [0.5, 0.5, 100],
          openingMean: 80,
        ),
        2,
      );
      // No black samples at all.
      expect(count([false, false], [50, 60]), 0);
    });

    test('kWeightedLoudness measures a stereo sine near theory', () {
      // Stereo 1 kHz sine at amplitude 0.5: per-channel mean square
      // 0.125, summed 0.25 → -6.02 − 0.691 ≈ -6.7 LUFS (K-weighting
      // is ~unity at 1 kHz). Loose band: the filter, not the exact
      // number, is what this pins.
      final sine = _sine(amplitude: 0.5, frequencyHz: 1000, seconds: 2);
      final loudness = kWeightedLoudness([sine, sine]);
      expect(loudness, greaterThan(-8.0));
      expect(loudness, lessThan(-5.0));
    });

    test('kWeightedLoudness floors silence', () {
      expect(kWeightedLoudness([Float32List(48000)]), kDbfsFloor);
      expect(kWeightedLoudness([]), kDbfsFloor);
    });

    test('snapFps snaps NTSC rates to nominal', () {
      expect(snapFps(23.976), 24);
      expect(snapFps(29.97), 30);
      expect(snapFps(59.94), 60);
      expect(snapFps(24.0), 24);
      expect(snapFps(23.4), 23);
      expect(snapFps(0), 0);
      expect(snapFps(-5), 0);
    });

    test('frameSampleTimes samples integer seconds from t=1', () {
      final times = frameSampleTimes(20.08);
      expect(times.length, 20);
      expect(times.first, 1.0);
      expect(times.last, 20.0);
      expect(frameSampleTimes(0.5), isEmpty);
      expect(frameSampleTimes(1.0), isEmpty);
      // Long videos cap at 120 samples.
      expect(frameSampleTimes(600).length, kMaxFrameSamples);
    });
  });

  group('probe contracts', () {
    test('unprobedProbe lists every rule as unmeasured', () {
      final probe = unprobedProbe();
      expect(probe.unmeasured.length, TierAProbe.allRules.length);
      expect(probe.unmeasured, containsAll(TierAProbe.allRules));
      expect(probe.isDemoProbe, isFalse);
    });

    test('needsProbe is true only before the first probe', () {
      expect(needsProbe(_exportWithProbe(unprobedProbe())), isTrue);
      // A completed Tier A probe measures BLACK-FR-01.
      final tierA = unprobedProbe().copyWith(
        unmeasured: TierAProbe.unmeasuredRules,
      );
      expect(needsProbe(_exportWithProbe(tierA)), isFalse);
      // Old demo-probe exports (unmeasured empty) are not re-probed
      // here — they keep their values until re-picked.
      const demoProbe = ProbeData(
        subtitleBottomY: 1000,
        subtitleTimecode: '00:00:00:00',
        peakDbfs: -2,
        peakTimecode: '00:00:00:00',
        longestSilenceSeconds: 0,
        blackFrameCount: 0,
        textOverflow: false,
        brandLogoPresent: true,
        brandColorsOk: true,
        captionSyncOffsetMs: 0,
        titleBottomY: 0,
        loudnessLufs: -14,
        openingFrameDarkness: 0,
        captionsFileAttached: false,
        isDemoProbe: true,
      );
      expect(needsProbe(_exportWithProbe(demoProbe)), isFalse);
    });

    test('ProbeData unmeasured round-trips through JSON', () {
      const probe = ProbeData(
        subtitleBottomY: 0,
        subtitleTimecode: '00:00:00:00',
        peakDbfs: -2,
        peakTimecode: '00:00:00:00',
        longestSilenceSeconds: 0,
        blackFrameCount: 0,
        textOverflow: false,
        brandLogoPresent: false,
        brandColorsOk: true,
        captionSyncOffsetMs: 0,
        titleBottomY: 0,
        loudnessLufs: -14,
        openingFrameDarkness: 0,
        captionsFileAttached: false,
        unmeasured: [kRuleSubtitleSafeArea, kRuleTextOverflow],
      );
      final roundTripped = ProbeData.fromJson(probe.toJson());
      expect(roundTripped.unmeasured,
          [kRuleSubtitleSafeArea, kRuleTextOverflow]);
      // Old JSON without the key defaults to [].
      final legacy = Map<String, dynamic>.from(probe.toJson())
        ..remove('unmeasured');
      expect(ProbeData.fromJson(legacy).unmeasured, isEmpty);
      // copyWith preserves unmeasured.
      expect(
        probe.copyWith(peakDbfs: -1).unmeasured,
        [kRuleSubtitleSafeArea, kRuleTextOverflow],
      );
    });

    test('ExportFile thumbnail + waveform round-trip, omitted when null',
        () {
      final withMedia = _exportWithProbe(unprobedProbe()).copyWith(
        frameThumbnailBase64: 'aGVsbG8=',
        waveformPeaks: [0.0, 0.5, 1.0],
      );
      final json = withMedia.toJson();
      expect(json['frameThumbnailBase64'], 'aGVsbG8=');
      expect(json['waveformPeaks'], [0.0, 0.5, 1.0]);
      final roundTripped = ExportFile.fromJson(json);
      expect(roundTripped.frameThumbnailBase64, 'aGVsbG8=');
      expect(roundTripped.waveformPeaks, [0.0, 0.5, 1.0]);

      final withoutMedia = _exportWithProbe(unprobedProbe());
      final bareJson = withoutMedia.toJson();
      expect(bareJson.containsKey('frameThumbnailBase64'), isFalse);
      expect(bareJson.containsKey('waveformPeaks'), isFalse);
      expect(ExportFile.fromJson(bareJson).frameThumbnailBase64, isNull);
      expect(ExportFile.fromJson(bareJson).waveformPeaks, isNull);
    });

    test('inspect skips unmeasured rules and records them', () {
      final probe = unprobedProbe().copyWith(
        unmeasured: TierAProbe.unmeasuredRules,
      );
      final file = _exportWithProbe(probe);
      final report = Inspector.inspect(
        file: file,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
        durationSeconds: 7,
      );
      // No finding for any unmeasured rule…
      for (final code in TierAProbe.unmeasuredRules) {
        expect(
          report.findings.where((f) => f.ruleCode == code),
          isEmpty,
          reason: '$code must not produce a finding when unmeasured',
        );
        expect(report.skippedRules, contains(code));
      }
      // …and the caller-measured duration is recorded, not the old 19.
      expect(report.durationSeconds, 7);
      // skippedRules round-trips through JSON + copyWith.
      expect(Report.fromJson(report.toJson()).skippedRules,
          report.skippedRules);
      expect(report.copyWith().skippedRules, report.skippedRules);
    });

    test('inspect with everything unmeasured finds nothing', () {
      final file = _exportWithProbe(unprobedProbe());
      final report = Inspector.inspect(
        file: file,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      expect(report.findings, isEmpty);
      expect(report.skippedRules.length, TierAProbe.allRules.length);
      expect(report.isClean, isTrue);
      expect(report.durationSeconds, 0);
    });
  });

  group('file system access', () {
    test('isVideoFile matches the picker extensions', () {
      expect(isVideoFile('clip.mp4'), isTrue);
      expect(isVideoFile('clip.MOV'), isTrue);
      expect(isVideoFile('clip.webm'), isTrue);
      expect(isVideoFile('clip.mkv'), isTrue);
      expect(isVideoFile('clip.m4v'), isTrue);
      expect(isVideoFile('clip.txt'), isFalse);
      expect(isVideoFile('clip.mp4.srt'), isFalse);
      expect(isVideoFile('mp4'), isFalse);
    });

    test(
      'unsupported off the web (stub)',
      () {
        expect(FileSystemAccess.isSupported, isFalse);
        expect(
          FileSystemAccess.readPersistedFile('fsa_nope'),
          completion(isNull),
        );
      },
      skip: kIsWeb ? 'web has the real API' : false,
    );

    test(
      'supported in Chrome; unknown handle keys read null',
      () async {
        expect(FileSystemAccess.isSupported, isTrue);
        // Exercises the whole IndexedDB path (open, create store,
        // transaction, get) without a real handle — a missing key
        // reads null instead of throwing.
        expect(
          await FileSystemAccess.readPersistedFile(
            'fsa_no_such_key_2026',
          ),
          isNull,
        );
        // And the delete path completes on a missing key.
        await FileSystemAccess.forgetHandle('fsa_no_such_key_2026');
      },
      skip: kIsWeb ? false : 'web-only FSA test',
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('Tier A probe on demo media', () {
    /// Loads a demo video from `test/fixtures/` (byte-identical to
    /// `assets/demo/`) and probes it. `rootBundle` cannot be used
    /// here — see the file header.
    Future<ProbeResult> probeFixture(String fileName) async {
      final bytes = await loadFixture(fileName);
      return MediaProbe.probeVideo(
        bytes,
        mimeType: 'video/mp4',
        onProgress: (stage, progress) {
          // Stage trace: shows where a slow probe spends its time.
          // ignore: avoid_print
          print('  probe $fileName: $stage '
              '${(progress * 100).round()}%');
        },
      );
    }

    void logResult(String label, ProbeResult result) {
      // Diagnostics for the report: the measured numbers, not just
      // pass/fail. Visible with `flutter test -d chrome -v` / reporter.
      // ignore: avoid_print
      print(
        '$label: ${result.width}x${result.height} ${result.fps}fps '
        '${result.durationSeconds}s peak=${result.probe.peakDbfs.toStringAsFixed(2)} dBFS '
        'black=${result.probe.blackFrameCount} '
        'silence=${result.probe.longestSilenceSeconds.toStringAsFixed(2)}s '
        'loudness=${result.probe.loudnessLufs.toStringAsFixed(1)} LUFS '
        'openingDark=${result.probe.openingFrameDarkness.toStringAsFixed(2)} '
        'unmeasured=${result.probe.unmeasured}',
      );
    }

    test(
      'defective video: black frames + clipped audio detected',
      () async {
        final result = await probeFixture(
          'frame-police-defective-mixed.mp4',
        );
        logResult('defective', result);
        expect(result.width, 1280);
        expect(result.height, 720);
        expect(result.fps, 24);
        // The sustained-run rule counts the t=5–6 injected run (2
        // sampled frames); assert >= 1 so sampling jitter cannot
        // flake the test.
        expect(result.probe.blackFrameCount, greaterThanOrEqualTo(1));
        expect(result.probe.peakDbfs, greaterThan(-1.0));
        // Tier B rules honestly unmeasured.
        expect(result.probe.unmeasured, contains(kRuleSubtitleSafeArea));
        expect(result.probe.unmeasured, contains(kRuleTextOverflow));
        expect(result.probe.unmeasured, contains(kRuleBrandLogo));
        expect(result.probe.unmeasured, contains(kRuleCaptionSync));
        expect(result.probe.unmeasured, contains(kRuleTitleSafeArea));
        // Thumbnail + waveform produced.
        expect(result.frameThumbnailBase64, isNotNull);
        expect(result.frameThumbnailBase64!.length, greaterThan(1000));
        expect(result.waveformPeaks, isNotNull);
        expect(result.waveformPeaks!.length, 200);
      },
      skip: kIsWeb ? false : 'web-only probe test',
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'clean video: no black frames, peak near 0 dBFS (hot master)',
      () async {
        final result =
            await probeFixture('frame-police-clean-720p.mp4');
        logResult('clean', result);
        expect(result.width, 1280);
        expect(result.height, 720);
        expect(result.fps, 24);
        // Clean by the sustained-run rule: its black samples are
        // fades, dark scenes, and one isolated t=18 flash frame.
        expect(result.probe.blackFrameCount, 0);
        // The clean trailer peaks near 0 dBFS (ffmpeg astats: +0.76) —
        // above the −1.0 dBFS ceiling. A faithful probe reports that;
        // the band below pins the honest value instead of the brief's
        // unachievable <= −1.0.
        expect(result.probe.peakDbfs, greaterThan(-2.0));
        expect(result.probe.peakDbfs, lessThan(2.0));
        expect(result.frameThumbnailBase64, isNotNull);
        expect(result.waveformPeaks, isNotNull);
      },
      skip: kIsWeb ? false : 'web-only probe test',
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'defective peak exceeds clean peak by a wide margin',
      () async {
        final clean =
            await probeFixture('frame-police-clean-720p.mp4');
        final defective = await probeFixture(
          'frame-police-defective-mixed.mp4',
        );
        logResult('clean', clean);
        logResult('defective', defective);
        // 4x linear gain ≈ +12 dB: the clipping signature.
        expect(
          defective.probe.peakDbfs - clean.probe.peakDbfs,
          greaterThan(6.0),
        );
        expect(
          defective.probe.blackFrameCount,
          greaterThan(clean.probe.blackFrameCount),
        );
      },
      skip: kIsWeb ? false : 'web-only probe test',
      timeout: const Timeout(Duration(minutes: 4)),
    );

    test(
      'low-res video: 854x480 measured',
      () async {
        final result =
            await probeFixture('frame-police-lowres-480p.mp4');
        logResult('lowres', result);
        expect(result.width, 854);
        expect(result.height, 480);
        expect(result.fps, 24);
        expect(result.probe.blackFrameCount, 0);
      },
      skip: kIsWeb ? false : 'web-only probe test',
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'probed export inspects with skipped rules recorded',
      () async {
        final result =
            await probeFixture('frame-police-clean-720p.mp4');
        final file = ExportFile(
          id: 'exp_probe_test',
          name: 'clean.mp4',
          durationSeconds: result.durationSeconds,
          frameCount: result.frameCount,
          width: result.width,
          height: result.height,
          fps: result.fps,
          sizeBytes: 3105557,
          addedAt: DateTime.utc(2026, 11, 22),
          probe: result.probe,
          isDemo: true,
          frameThumbnailBase64: result.frameThumbnailBase64,
          waveformPeaks: result.waveformPeaks,
        );
        final report = Inspector.inspect(
          file: file,
          rules: defaultRules(),
          registryVersion: kRegistryVersion,
          durationSeconds: 6,
        );
        expect(report.skippedRules, contains(kRuleSubtitleSafeArea));
        expect(report.skippedRules, contains(kRuleTextOverflow));
        expect(report.skippedRules, contains(kRuleBrandLogo));
        expect(report.skippedRules, contains(kRuleBrandColor));
        expect(report.skippedRules, contains(kRuleCaptionSync));
        expect(report.skippedRules, contains(kRuleTitleSafeArea));
        // The measured rules did run: aspect, resolution, frame rate
        // all pass on the 1280x720/24fps file.
        expect(
          report.findings
              .where((f) => f.ruleCode == kRuleAspectRatio)
              .isEmpty,
          isTrue,
        );
        expect(report.durationSeconds, 6);
      },
      skip: kIsWeb ? false : 'web-only probe test',
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
