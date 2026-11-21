/// Seeded demo data: the four demo exports, past history reports, and
/// the CI run list.
///
/// Everything here is SEEDED DEMO CONTENT — the product's demo story
/// from the V7 design — labelled DEMO wherever it shows. It seeds the
/// store on first launch so the app is explorable without a backend;
/// real inspections append real reports alongside it. Nothing here is
/// presented as measured usage.
library;

import '../core/constants.dart';
import 'inspector.dart';
import 'models.dart';
import 'registry.dart';

/// The four demo exports from the V7 design.
List<ExportFile> demoExports() {
  final now = DateTime.now();
  return [
    ExportFile(
      id: 'exp_teaser_v3',
      name: DemoFixture.teaserName,
      durationSeconds: DemoFixture.teaserDurationSeconds,
      frameCount: DemoFixture.teaserFrames,
      width: DemoFixture.teaserWidth,
      height: DemoFixture.teaserHeight,
      fps: DemoFixture.teaserFps,
      sizeBytes: DemoFixture.teaserSizeBytes,
      addedAt: now.subtract(const Duration(minutes: 12)),
      declaredAspect: '9:16',
      isDemo: true,
      probe: const ProbeData(
        subtitleBottomY: DemoFixture.subtitleBottomY,
        subtitleTimecode: DemoFixture.subtitleTimecode,
        peakDbfs: DemoFixture.peakDbfs,
        peakTimecode: DemoFixture.peakTimecode,
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
    ),
    ExportFile(
      id: 'exp_demo_v2',
      name: 'Product Demo — v2.mp4',
      durationSeconds: 72,
      frameCount: 1728,
      width: 1920,
      height: 1080,
      fps: 24,
      sizeBytes: 142000000,
      addedAt: now.subtract(const Duration(days: 1, hours: 3)),
      declaredAspect: '16:9',
      isDemo: true,
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
    ),
    ExportFile(
      id: 'exp_founder_cut4',
      name: 'Founder Story — cut 4.mp4',
      durationSeconds: 123,
      frameCount: 2952,
      width: 1080,
      height: 1920,
      fps: 24,
      sizeBytes: 210000000,
      addedAt: now.subtract(const Duration(days: 2, hours: 5)),
      declaredAspect: '9:16',
      isDemo: true,
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
    ),
    ExportFile(
      id: 'exp_known_bad',
      name: 'Demo reel — known-bad.mp4',
      durationSeconds: 32,
      frameCount: 768,
      width: 1080,
      height: 1920,
      fps: 24,
      sizeBytes: 48000000,
      addedAt: now.subtract(const Duration(days: 3)),
      declaredAspect: '9:16',
      isDemo: true,
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
    ),
  ];
}

/// Seeded past history reports, built by running the real inspector over
/// the demo exports at staggered times. The scores are the stored
/// records of those runs — the V7 history (88, 91, 86, 96, 82) is the
/// design's story; these seeded runs are the app's own past, computed
/// by the same engine that runs new inspections.
List<Report> demoHistoryReports() {
  final rules = defaultRules();
  final exports = demoExports();
  final now = DateTime.now();
  final runs = <(ExportFile, Duration)>[
    (exports[0], const Duration(minutes: 12)),
    (exports[1], const Duration(days: 1, hours: 2)),
    (exports[2], const Duration(days: 2, hours: 4)),
    (exports[1], const Duration(days: 3, hours: 1)),
    (exports[2], const Duration(days: 4, hours: 6)),
  ];
  return runs
      .map((run) => Inspector.inspect(
            file: run.$1,
            rules: rules,
            registryVersion: kRegistryVersion,
            now: now.subtract(run.$2),
          ))
      .toList();
}

/// Seeded recent CI runs (demo). The totals (248 runs, 31 failed, 217
/// clean) live in [DemoFixture]; this list is the recent detail.
List<CiRun> demoCiRuns() {
  final now = DateTime.now();
  CiRun run({
    required int number,
    required int prNumber,
    required String prTitle,
    required String exportName,
    required int exitCode,
    required Duration ago,
  }) =>
      CiRun(
        id: 'ci_$number',
        number: number,
        prNumber: prNumber,
        prTitle: prTitle,
        exportName: exportName,
        exitCode: exitCode,
        registryVersion: kRegistryVersion,
        createdAt: now.subtract(ago),
        isDemo: true,
      );
  return [
    run(
      number: 248,
      prNumber: 142,
      prTitle: 'Launch teaser v3 — final cut',
      exportName: DemoFixture.teaserName,
      exitCode: kExitDefects,
      ago: const Duration(minutes: 12),
    ),
    run(
      number: 247,
      prNumber: 142,
      prTitle: 'Launch teaser v3 — final cut',
      exportName: 'Launch Teaser — v3.mp4 (re-export)',
      exitCode: kExitDefects,
      ago: const Duration(hours: 2),
    ),
    run(
      number: 246,
      prNumber: 141,
      prTitle: 'Teaser — 6s bumper',
      exportName: 'Teaser — 6s bumper.mp4',
      exitCode: kExitClean,
      ago: const Duration(hours: 5),
    ),
    run(
      number: 245,
      prNumber: 139,
      prTitle: 'Product demo v2',
      exportName: 'Product Demo — v2.mp4',
      exitCode: kExitClean,
      ago: const Duration(days: 1),
    ),
    run(
      number: 244,
      prNumber: 138,
      prTitle: 'Founder story cut 4',
      exportName: 'Founder Story — cut 4.mp4',
      exitCode: kExitDefects,
      ago: const Duration(days: 1, hours: 6),
    ),
    run(
      number: 243,
      prNumber: 137,
      prTitle: 'Founder story cut 3',
      exportName: 'Founder Story — cut 3.mp4',
      exitCode: kExitClean,
      ago: const Duration(days: 2),
    ),
    run(
      number: 242,
      prNumber: 136,
      prTitle: 'Launch teaser v2',
      exportName: 'Launch Teaser — v2.mp4',
      exitCode: kExitClean,
      ago: const Duration(days: 2, hours: 8),
    ),
    run(
      number: 241,
      prNumber: 135,
      prTitle: 'Product demo v1',
      exportName: 'Product Demo — v1.mp4',
      exitCode: kExitDefects,
      ago: const Duration(days: 3),
    ),
  ];
}
