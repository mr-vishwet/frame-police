/// Hand-built test fixtures: probe values written out as literals.
///
/// No demo data, no seeded state — these are the engine's test inputs,
/// built directly from [ProbeData] so tests never depend on seeded
/// exports. The values are chosen so the rule engine produces known
/// verdicts (see each builder).
library;

import 'package:frame_police/engine/models.dart';

/// A waiver reason used across tests (a test string, not product data).
const String kTestWaiverReason =
    'Client approved the lower-third placement for this cut — '
    'the safe area is advisory here, not a platform rule.';

/// A 1080x1920 vertical export whose probe breaches exactly two defect
/// rules (subtitle safe area, audio peak) and all three suggestion
/// rules: 2 defects, 3 suggestions, score 82, exit 1.
ExportFile twoDefectExport() => ExportFile(
      id: 'exp_test_two_defect',
      name: 'Test Teaser — v3.mp4',
      durationSeconds: 47,
      frameCount: 1128,
      width: 1080,
      height: 1920,
      fps: 24,
      sizeBytes: 86400000,
      addedAt: DateTime.utc(2026, 11, 21, 12),
      declaredAspect: '9:16',
      probe: const ProbeData(
        subtitleBottomY: 1066,
        subtitleTimecode: '00:00:12:08',
        peakDbfs: -0.8,
        peakTimecode: '00:00:31:22',
        longestSilenceSeconds: 0.8,
        blackFrameCount: 0,
        textOverflow: false,
        brandLogoPresent: true,
        brandColorsOk: true,
        captionSyncOffsetMs: 40,
        titleBottomY: 620,
        loudnessLufs: -13.2,
        openingFrameDarkness: 0.62,
        captionsFileAttached: false,
      ),
    );

/// The two-defect export after the fixes were made in the editor and
/// the file re-exported: subtitle at y = 1,040 px (inside the safe
/// area), peak at −1.4 dBFS (inside the limit). Re-inspecting this
/// file passes both rules.
ExportFile fixedTwoDefectExport() => ExportFile(
      id: 'exp_test_two_defect',
      name: 'Test Teaser — v3.mp4',
      durationSeconds: 47,
      frameCount: 1128,
      width: 1080,
      height: 1920,
      fps: 24,
      sizeBytes: 86400000,
      addedAt: DateTime.utc(2026, 11, 21, 12),
      declaredAspect: '9:16',
      probe: const ProbeData(
        subtitleBottomY: 1040,
        subtitleTimecode: '00:00:12:08',
        peakDbfs: -1.4,
        peakTimecode: '00:00:31:22',
        longestSilenceSeconds: 0.8,
        blackFrameCount: 0,
        textOverflow: false,
        brandLogoPresent: true,
        brandColorsOk: true,
        captionSyncOffsetMs: 40,
        titleBottomY: 620,
        loudnessLufs: -13.2,
        openingFrameDarkness: 0.62,
        captionsFileAttached: false,
      ),
    );

/// The two-defect export with only the peak fixed in the editor
/// (−1.4 dBFS); the subtitle still breaches. Used for the
/// waiver-carries-forward test.
ExportFile peakFixedExport() => ExportFile(
      id: 'exp_test_two_defect',
      name: 'Test Teaser — v3.mp4',
      durationSeconds: 47,
      frameCount: 1128,
      width: 1080,
      height: 1920,
      fps: 24,
      sizeBytes: 86400000,
      addedAt: DateTime.utc(2026, 11, 21, 12),
      declaredAspect: '9:16',
      probe: const ProbeData(
        subtitleBottomY: 1066,
        subtitleTimecode: '00:00:12:08',
        peakDbfs: -1.4,
        peakTimecode: '00:00:31:22',
        longestSilenceSeconds: 0.8,
        blackFrameCount: 0,
        textOverflow: false,
        brandLogoPresent: true,
        brandColorsOk: true,
        captionSyncOffsetMs: 40,
        titleBottomY: 620,
        loudnessLufs: -13.2,
        openingFrameDarkness: 0.62,
        captionsFileAttached: false,
      ),
    );

/// A 1080x1920 vertical export breaching five defect rules (subtitle
/// safe area, audio peak, black frames, text overflow, brand logo) and
/// all three suggestion rules: 5 defects, 3 suggestions, score 55,
/// exit 1.
ExportFile knownBadExport() => ExportFile(
      id: 'exp_test_known_bad',
      name: 'Test reel — known-bad.mp4',
      durationSeconds: 32,
      frameCount: 768,
      width: 1080,
      height: 1920,
      fps: 24,
      sizeBytes: 48000000,
      addedAt: DateTime.utc(2026, 11, 21, 12),
      declaredAspect: '9:16',
      probe: const ProbeData(
        subtitleBottomY: 1080,
        subtitleTimecode: '00:00:09:14',
        peakDbfs: -0.6,
        peakTimecode: '00:00:21:10',
        longestSilenceSeconds: 1.1,
        blackFrameCount: 2,
        textOverflow: true,
        brandLogoPresent: false,
        brandColorsOk: true,
        captionSyncOffsetMs: 90,
        titleBottomY: 800,
        loudnessLufs: -12.8,
        openingFrameDarkness: 0.71,
        captionsFileAttached: false,
      ),
    );

/// A 1920x1080 landscape export passing every rule: 0 defects,
/// 0 suggestions, score 100, exit 0.
ExportFile cleanExport() => ExportFile(
      id: 'exp_test_clean',
      name: 'Test Demo — v2.mp4',
      durationSeconds: 72,
      frameCount: 1728,
      width: 1920,
      height: 1080,
      fps: 24,
      sizeBytes: 142000000,
      addedAt: DateTime.utc(2026, 11, 21, 12),
      declaredAspect: '16:9',
      probe: const ProbeData(
        subtitleBottomY: 560,
        subtitleTimecode: '00:00:08:12',
        peakDbfs: -2.1,
        peakTimecode: '00:00:44:02',
        longestSilenceSeconds: 0.6,
        blackFrameCount: 0,
        textOverflow: false,
        brandLogoPresent: true,
        brandColorsOk: true,
        captionSyncOffsetMs: 30,
        titleBottomY: 300,
        loudnessLufs: -14.1,
        openingFrameDarkness: 0.35,
        captionsFileAttached: true,
      ),
    );

/// A 1080x1920 vertical export with exactly one defect (4 black
/// frames): 1 defect, 0 suggestions, score 91, exit 1.
ExportFile singleDefectExport() => ExportFile(
      id: 'exp_test_single_defect',
      name: 'Test Story — cut 4.mp4',
      durationSeconds: 123,
      frameCount: 2952,
      width: 1080,
      height: 1920,
      fps: 24,
      sizeBytes: 210000000,
      addedAt: DateTime.utc(2026, 11, 21, 12),
      declaredAspect: '9:16',
      probe: const ProbeData(
        subtitleBottomY: 1010,
        subtitleTimecode: '00:01:02:18',
        peakDbfs: -1.8,
        peakTimecode: '00:00:58:06',
        longestSilenceSeconds: 0.9,
        blackFrameCount: 4,
        textOverflow: false,
        brandLogoPresent: true,
        brandColorsOk: true,
        captionSyncOffsetMs: 55,
        titleBottomY: 700,
        loudnessLufs: -14.3,
        openingFrameDarkness: 0.41,
        captionsFileAttached: true,
      ),
    );
