/// The inspection engine: evaluates versioned rules against probe data.
///
/// The engine is deterministic: same probe data + same registry version =
/// same report. It never touches raw media — rules evaluate ONLY against
/// [ProbeData], which is what makes inspections reproducible and testable.
///
/// v0.1 honesty note: seeded demo exports carry measured probe data. For
/// user-picked files, [demoProbeFor] derives a deterministic probe from
/// the file's name and size — labelled DEMO in the report until the
/// native media probe (frame/audio decode) lands in phase 2. The rule
/// engine, scoring, waivers, and exit-code mapping are the real product
/// and are fully tested.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/constants.dart';
import '../core/format.dart';
import 'autofix.dart';
import 'exit_codes.dart';
import 'models.dart';

/// Thrown when an inspection cannot run (unreadable file, probe failure,
/// registry mismatch). Maps to exit code 2 — distinct from a defect.
class InspectionException implements Exception {
  InspectionException(this.message);

  final String message;

  @override
  String toString() => 'InspectionException: $message';
}

/// The subtitle safe-area limit on a 1920 px frame at the 90% margin
/// setting is y ≤ 1,052 px (the demo canon: subtitle at 1,066 px breaches
/// by 14 px). The limit scales linearly with the margin setting, so the
/// factor below anchors the 90% setting to 1,052 px and every other
/// setting follows from it.
const double _subtitleLimitFactorAt90 = 1052 / 1920;

/// Silence longer than this is a defect (AUD-PEAK-02).
const double kSilenceLimitSeconds = 1.5;

/// Loudness deviation from target that earns a suggestion (SUG-LOUD-01).
const double kLoudnessToleranceLufs = 0.5;

class Inspector {
  Inspector._();

  /// Subtitle safe-area limit in px for a frame of [frameHeight] at a
  /// margin of [marginPercent] (the rule's limit value).
  static double subtitleLimitY(double frameHeight, double marginPercent) =>
      frameHeight * _subtitleLimitFactorAt90 * (marginPercent / 90);

  /// Title safe-area limit in px: the margin percentage of frame height.
  static double titleLimitY(double frameHeight, double marginPercent) =>
      frameHeight * (marginPercent / 100);

  /// Evaluates one [rule] against [file]. Returns a [Finding] when the
  /// rule fails, null when it passes. Disabled rules are never evaluated.
  static Finding? evaluateRule(Rule rule, ExportFile file) {
    if (!rule.enabled) return null;
    final probe = file.probe;
    switch (rule.code) {
      case kRuleSubtitleSafeArea: {
        final limitY = subtitleLimitY(
          file.height.toDouble(),
          rule.limitValue,
        );
        if (probe.subtitleBottomY <= limitY) return null;
        final breach = probe.subtitleBottomY - limitY;
        return _defect(
          rule: rule,
          title: 'Subtitle sits below the safe area.',
          timecode: probe.subtitleTimecode,
          measuredLabel: 'y = ${probe.subtitleBottomY.toStringAsFixed(0)} px',
          measuredValue: probe.subtitleBottomY,
          limitLabel: 'y ≤ ${limitY.toStringAsFixed(0)} px',
          limitValue: limitY,
          detail: 'The subtitle bottom edge is ${breach.toStringAsFixed(0)} px '
              'below the safe-area line at ${probe.subtitleTimecode}.',
        );
      }
      case kRuleAudioPeak: {
        if (probe.peakDbfs > rule.limitValue) {
          final over = probe.peakDbfs - rule.limitValue;
          return _defect(
            rule: rule,
            title: 'One peak, ${over.toStringAsFixed(1)} dB over the limit.',
            timecode: probe.peakTimecode,
            measuredLabel: formatDbfs(probe.peakDbfs),
            measuredValue: probe.peakDbfs,
            limitLabel: '${formatDbfs(rule.limitValue)} limit',
            limitValue: rule.limitValue,
            detail: 'A single peak at ${probe.peakTimecode} reaches '
                '${formatDbfs(probe.peakDbfs)} — '
                '${over.toStringAsFixed(1)} dB over the '
                '${formatDbfs(rule.limitValue)} ceiling.',
          );
        }
        if (probe.longestSilenceSeconds > kSilenceLimitSeconds) {
          return _defect(
            rule: rule,
            title: 'Dead air longer than the silence limit.',
            timecode: probe.peakTimecode,
            measuredLabel:
                '${probe.longestSilenceSeconds.toStringAsFixed(1)} s silence',
            measuredValue: probe.longestSilenceSeconds,
            limitLabel: '≤ ${kSilenceLimitSeconds.toStringAsFixed(1)} s',
            limitValue: kSilenceLimitSeconds,
            detail: 'A stretch of dead air lasts '
                '${probe.longestSilenceSeconds.toStringAsFixed(1)} s — '
                'longer than the ${kSilenceLimitSeconds.toStringAsFixed(1)} s '
                'silence limit.',
          );
        }
        return null;
      }
      case kRuleAspectRatio: {
        final actual = file.aspectLabel;
        if (actual == file.declaredAspect) return null;
        return _defect(
          rule: rule,
          title: 'Aspect ratio does not match the project.',
          timecode: '00:00:00:00',
          measuredLabel: actual,
          measuredValue: file.width / file.height,
          limitLabel: file.declaredAspect,
          limitValue: rule.limitValue,
          detail: 'The export is $actual; the project declares '
              '${file.declaredAspect}.',
        );
      }
      case kRuleBlackFrames: {
        if (probe.blackFrameCount <= 0) return null;
        return _defect(
          rule: rule,
          title: '${probe.blackFrameCount} black frames.',
          timecode: '00:00:00:00',
          measuredLabel: '${probe.blackFrameCount} black frames',
          measuredValue: probe.blackFrameCount.toDouble(),
          limitLabel: '0 black frames',
          limitValue: 0,
          detail: '${probe.blackFrameCount} fully black frames — usually a '
              'render gap or a missing clip.',
        );
      }
      case kRuleTextOverflow: {
        if (!probe.textOverflow) return null;
        return _defect(
          rule: rule,
          title: 'On-screen text overflows the frame.',
          timecode: probe.subtitleTimecode,
          measuredLabel: 'Text crosses frame edge',
          measuredValue: 1,
          limitLabel: 'No overflow',
          limitValue: 0,
          detail: 'A text bounding box crosses the frame edge at '
              '${probe.subtitleTimecode}.',
        );
      }
      case kRuleBrandLogo: {
        if (probe.brandLogoPresent) return null;
        return _defect(
          rule: rule,
          title: 'Brand mark missing.',
          timecode: '00:00:00:00',
          measuredLabel: 'Mark absent',
          measuredValue: 0,
          limitLabel: 'Mark present',
          limitValue: 1,
          detail: 'The brand mark does not appear anywhere in the export.',
        );
      }
      case kRuleBrandColor: {
        if (probe.brandColorsOk) return null;
        return _defect(
          rule: rule,
          title: 'Off-palette colours in the export.',
          timecode: '00:00:00:00',
          measuredLabel: 'Off-palette fill found',
          measuredValue: 1,
          limitLabel: 'Palette only',
          limitValue: 0,
          detail: 'A fill or lower-third uses a colour outside the brand '
              'palette.',
        );
      }
      case kRuleCaptionSync: {
        if (probe.captionSyncOffsetMs.abs() <= rule.limitValue) return null;
        return _defect(
          rule: rule,
          title: 'Captions out of sync.',
          timecode: probe.subtitleTimecode,
          measuredLabel:
              '${probe.captionSyncOffsetMs.toStringAsFixed(0)} ms offset',
          measuredValue: probe.captionSyncOffsetMs,
          limitLabel: '±${rule.limitValue.toStringAsFixed(0)} ms',
          limitValue: rule.limitValue,
          detail: 'Burned-in captions sit '
              '${probe.captionSyncOffsetMs.toStringAsFixed(0)} ms off the '
              'spoken audio — outside the ±${rule.limitValue.toStringAsFixed(0)} '
              'ms tolerance.',
        );
      }
      case kRuleTitleSafeArea: {
        final limitY = titleLimitY(
          file.height.toDouble(),
          rule.limitValue,
        );
        if (probe.titleBottomY <= limitY) return null;
        return _defect(
          rule: rule,
          title: 'Title sits below the title-safe area.',
          timecode: '00:00:00:00',
          measuredLabel: 'y = ${probe.titleBottomY.toStringAsFixed(0)} px',
          measuredValue: probe.titleBottomY,
          limitLabel: 'y ≤ ${limitY.toStringAsFixed(0)} px',
          limitValue: limitY,
          detail: 'The title bottom edge crosses the title-safe line.',
        );
      }
      case kRuleFrameRate: {
        if (file.fps == rule.limitValue.toInt()) return null;
        return _defect(
          rule: rule,
          title: 'Frame rate does not match the project.',
          timecode: '00:00:00:00',
          measuredLabel: '${file.fps} fps',
          measuredValue: file.fps.toDouble(),
          limitLabel: '${rule.limitValue.toStringAsFixed(0)} fps',
          limitValue: rule.limitValue,
          detail: 'The export is ${file.fps} fps; the project is '
              '${rule.limitValue.toStringAsFixed(0)} fps.',
        );
      }
      case kRuleMinResolution: {
        final shortEdge =
            file.width < file.height ? file.width : file.height;
        if (shortEdge >= rule.limitValue) return null;
        return _defect(
          rule: rule,
          title: 'Resolution below the minimum.',
          timecode: '00:00:00:00',
          measuredLabel: '$shortEdge px short edge',
          measuredValue: shortEdge.toDouble(),
          limitLabel: '≥ ${rule.limitValue.toStringAsFixed(0)} px short edge',
          limitValue: rule.limitValue,
          detail: 'The short edge is $shortEdge px — below the '
              '${rule.limitValue.toStringAsFixed(0)} px minimum. The export '
              'will look soft on modern phones.',
        );
      }
      case kRuleLoudness: {
        final deviation = (probe.loudnessLufs - rule.limitValue).abs();
        if (deviation <= kLoudnessToleranceLufs) return null;
        return _suggestion(
          rule: rule,
          title: 'Loudness is ${deviation.toStringAsFixed(1)} LUFS '
              '${probe.loudnessLufs > rule.limitValue ? 'hot' : 'quiet'}',
          timecode: '00:00:00:00',
          measuredLabel: '${probe.loudnessLufs.toStringAsFixed(1)} LUFS',
          measuredValue: probe.loudnessLufs,
          limitLabel: '${rule.limitValue.toStringAsFixed(1)} LUFS target',
          limitValue: rule.limitValue,
          detail: 'Measured ${probe.loudnessLufs.toStringAsFixed(1)} LUFS '
              'integrated; the ${rule.limitValue.toStringAsFixed(1)} LUFS '
              'target keeps the export consistent with the rest of the '
              'channel.',
        );
      }
      case kRuleOpeningFrame: {
        if (probe.openingFrameDarkness <= rule.limitValue) return null;
        final pct = (probe.openingFrameDarkness * 100).toStringAsFixed(0);
        return _suggestion(
          rule: rule,
          title: 'Opening frame is $pct% dark',
          timecode: '00:00:00:00',
          measuredLabel: '$pct% dark',
          measuredValue: probe.openingFrameDarkness,
          limitLabel: '< ${(rule.limitValue * 100).toStringAsFixed(0)}% dark',
          limitValue: rule.limitValue,
          detail: 'The opening frame is the thumbnail on most players — '
              'a very dark opening frame underperforms.',
        );
      }
      case kRuleCaptionsFile: {
        if (probe.captionsFileAttached) return null;
        return _suggestion(
          rule: rule,
          title: 'No captions file attached',
          timecode: '00:00:00:00',
          measuredLabel: 'No .srt found',
          measuredValue: 0,
          limitLabel: '.srt attached',
          limitValue: 1,
          detail: 'No .srt was found alongside the export. Captions '
              'improve reach and accessibility; the burned-in subtitles '
              'do not replace them.',
        );
      }
    }
    return null;
  }

  static Finding _defect({
    required Rule rule,
    required String title,
    required String timecode,
    required String measuredLabel,
    required double measuredValue,
    required String limitLabel,
    required double limitValue,
    required String detail,
  }) =>
      Finding(
        id: rule.code,
        ruleCode: rule.code,
        ruleVersion: rule.version,
        title: title,
        kind: FindingKind.defect,
        timecode: timecode,
        measuredLabel: measuredLabel,
        measuredValue: measuredValue,
        limitLabel: limitLabel,
        limitValue: limitValue,
        detail: detail,
        fix: fixForRule(rule.code),
      );

  static Finding _suggestion({
    required Rule rule,
    required String title,
    required String timecode,
    required String measuredLabel,
    required double measuredValue,
    required String limitLabel,
    required double limitValue,
    required String detail,
  }) =>
      Finding(
        id: rule.code,
        ruleCode: rule.code,
        ruleVersion: rule.version,
        title: title,
        kind: FindingKind.suggestion,
        timecode: timecode,
        measuredLabel: measuredLabel,
        measuredValue: measuredValue,
        limitLabel: limitLabel,
        limitValue: limitValue,
        detail: detail,
      );

  /// Score for a finding list: 100 minus 9 per blocking defect.
  /// Suggestions never affect the score.
  static int scoreFor(Iterable<Finding> findings) {
    final openDefects =
        findings.where((f) => f.blocksRelease).length;
    final score = kMaxScore - kPointsPerDefect * openDefects;
    return score < 0 ? 0 : score;
  }

  /// Runs a full inspection of [file] against [rules].
  ///
  /// [previousReport] carries waivers and fixed findings forward on
  /// re-inspection: waived findings stay waived (with their reason),
  /// fixed findings that now pass become confirmed, and fixed findings
  /// that still fail re-open. Suggestions are only evaluated when
  /// [suggestionsEnabled].
  static Report inspect({
    required ExportFile file,
    required List<Rule> rules,
    required String registryVersion,
    bool suggestionsEnabled = true,
    Report? previousReport,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final findings = <Finding>[];
    final previous = <String, Finding>{};
    if (previousReport != null) {
      for (final finding in previousReport.findings) {
        previous[finding.ruleCode] = finding;
      }
    }

    for (final rule in rules) {
      if (!rule.enabled) continue;
      if (rule.kind == FindingKind.suggestion && !suggestionsEnabled) {
        continue;
      }
      final finding = evaluateRule(rule, file);
      if (finding == null) {
        // Rule passes now. If the previous report had this finding
        // fixed, the fix is confirmed — record it.
        final prev = previous[rule.code];
        if (prev != null && prev.status == FindingStatus.fixed) {
          findings.add(prev.copyWith(status: FindingStatus.confirmed));
        }
        continue;
      }
      final prev = previous[rule.code];
      if (prev != null && prev.status == FindingStatus.waived) {
        // Still failing, still waived — the waiver carries forward.
        findings.add(finding.copyWith(
          status: FindingStatus.waived,
          waiver: prev.waiver,
        ));
      } else {
        findings.add(finding);
      }
    }

    final score = scoreFor(findings);
    final exitCode = exitCodeForFindings(findings);
    final report = Report(
      id: 'rep_${timestamp.millisecondsSinceEpoch}',
      exportId: file.id,
      exportName: file.name,
      createdAt: timestamp,
      registryVersion: registryVersion,
      findings: findings,
      score: score,
      exitCode: exitCode,
      durationSeconds: 19,
      framesProbed: file.frameCount,
      fingerprint: '',
      demoProbe: file.probe.isDemoProbe,
    );
    return report.copyWith(fingerprint: fingerprintFor(report));
  }

  /// SHA-256 fingerprint of a report's canonical JSON (excluding the
  /// fingerprint itself). Any edit after the run changes the hash.
  static String fingerprintFor(Report report) {
    final canonical = Map<String, dynamic>.from(report.toJson())
      ..remove('fingerprint');
    final bytes = utf8.encode(jsonEncode(canonical));
    return sha256.convert(bytes).toString();
  }

  /// Applies auto-fixes to a working copy of [file]: the probe values
  /// (and, for frame-rate / resolution / aspect fixes, the export
  /// metadata) are adjusted to their post-fix values. The original file
  /// is untouched — v0.1 fixes operate on probe data and metadata, not
  /// media bytes; real media rewriting is phase 2.
  static ExportFile applyFixesToExport(
    ExportFile file,
    Iterable<Finding> fixed,
  ) {
    var probe = file.probe;
    var width = file.width;
    var height = file.height;
    var fps = file.fps;
    var declaredAspect = file.declaredAspect;
    for (final finding in fixed) {
      switch (finding.ruleCode) {
        case kRuleSubtitleSafeArea:
          probe = probe.copyWith(
            subtitleBottomY: finding.limitValue - 12,
          );
        case kRuleAudioPeak:
          probe = probe.copyWith(
            peakDbfs: DemoFixture.peakFixedDbfs,
            longestSilenceSeconds: 0,
          );
        case kRuleAspectRatio:
          // Re-crop to the declared aspect at canonical dimensions, so
          // the re-inspection passes exactly (rounding height * w / h
          // can land a pixel off and still fail the rule).
          if (declaredAspect == '9:16') {
            width = 1080;
            height = 1920;
          } else if (declaredAspect == '16:9') {
            width = 1920;
            height = 1080;
          } else {
            final parts = declaredAspect.split(':');
            final w = int.parse(parts[0]);
            final h = int.parse(parts[1]);
            width = (height * w / h).round();
          }
        case kRuleBlackFrames:
          probe = probe.copyWith(blackFrameCount: 0);
        case kRuleTextOverflow:
          probe = probe.copyWith(textOverflow: false);
        case kRuleBrandLogo:
          probe = probe.copyWith(brandLogoPresent: true);
        case kRuleBrandColor:
          probe = probe.copyWith(brandColorsOk: true);
        case kRuleCaptionSync:
          probe = probe.copyWith(captionSyncOffsetMs: 0);
        case kRuleTitleSafeArea:
          probe = probe.copyWith(titleBottomY: height * 0.5);
        case kRuleFrameRate:
          fps = 24;
        case kRuleMinResolution:
          final shortEdge = width < height ? width : height;
          if (shortEdge < 1080) {
            final scale = 1080 / shortEdge;
            width = (width * scale).round();
            height = (height * scale).round();
          }
        default:
          break;
      }
    }
    return ExportFile(
      id: file.id,
      name: file.name,
      durationSeconds: file.durationSeconds,
      frameCount: file.frameCount,
      width: width,
      height: height,
      fps: fps,
      sizeBytes: file.sizeBytes,
      addedAt: file.addedAt,
      probe: probe,
      isDemo: file.isDemo,
      declaredAspect: declaredAspect,
    );
  }

  /// Deterministic demo probe for a user-picked file, derived from the
  /// file's name and size with FNV-1a (Dart's `String.hashCode` is not
  /// stable across runs, so it cannot be used). Same file = same probe
  /// = same report. Labelled DEMO everywhere it shows.
  static ProbeData demoProbeFor(String name, int sizeBytes) {
    var hash = 0x811c9dc5;
    final bytes = utf8.encode('$name|$sizeBytes');
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    double pick(int slot, double min, double max) {
      final slice = (hash >> (slot * 5)) & 0x1F;
      return min + (max - min) * (slice / 31);
    }

    final hasSubtitleBreach = (hash & 0x1) == 1;
    final hasPeakBreach = ((hash >> 1) & 0x1) == 1;
    return ProbeData(
      subtitleBottomY:
          hasSubtitleBreach ? pick(2, 1053, 1090) : pick(2, 980, 1040),
      subtitleTimecode: '00:00:12:08',
      peakDbfs: hasPeakBreach ? pick(3, -0.9, -0.4) : pick(3, -3.0, -1.2),
      peakTimecode: '00:00:31:22',
      longestSilenceSeconds: pick(4, 0.2, 1.4),
      blackFrameCount: ((hash >> 4) & 0x1) == 1 ? 2 : 0,
      textOverflow: ((hash >> 5) & 0x1) == 1,
      brandLogoPresent: ((hash >> 6) & 0x1) == 1,
      brandColorsOk: ((hash >> 7) & 0x1) == 1,
      captionSyncOffsetMs: pick(8, 0, 90),
      titleBottomY: pick(9, 400, 900),
      loudnessLufs: pick(10, -15.5, -12.5),
      openingFrameDarkness: pick(11, 0.2, 0.8),
      captionsFileAttached: ((hash >> 12) & 0x1) == 1,
      isDemoProbe: true,
    );
  }
}
