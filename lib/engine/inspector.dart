/// The inspection engine: evaluates versioned rules against probe data.
///
/// The engine is deterministic: same probe data + same registry version =
/// same report. It never touches raw media — rules evaluate ONLY against
/// [ProbeData], which is what makes inspections reproducible and testable.
///
/// The probe is the real Tier A browser-native probe (see
/// `services/media_probe.dart`). Rules whose inputs the probe did not
/// measure are listed in [ProbeData.unmeasured]; [inspect] skips them
/// (no finding, no pass) and records them in [Report.skippedRules] —
/// the report says what was not measured instead of pretending it
/// passed. Exports picked before the real probe landed still carry the
/// old hash-derived demo probe, flagged by `isDemoProbe`.
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
  /// Creates an [InspectionException].
  InspectionException(this.message);

  /// The message.
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

/// Inspector.
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
  ///
  /// Rules listed in `file.probe.unmeasured` are SKIPPED — no finding,
  /// no pass — and recorded in the report's [Report.skippedRules]. A
  /// skipped rule carries nothing forward from a previous report: with
  /// nothing measured, there is nothing to confirm or waive.
  ///
  /// [durationSeconds] is the caller-measured inspection duration (the
  /// old hardcoded 19 s is gone); 0 when the caller did not measure it.
  static Report inspect({
    required ExportFile file,
    required List<Rule> rules,
    required String registryVersion,
    bool suggestionsEnabled = true,
    Report? previousReport,
    DateTime? now,
    int? durationSeconds,
  }) {
    final timestamp = now ?? DateTime.now();
    final findings = <Finding>[];
    final skippedRules = <String>[];
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
      if (file.probe.unmeasured.contains(rule.code)) {
        // Not measured by this probe: skip honestly, record it.
        skippedRules.add(rule.code);
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
      durationSeconds: durationSeconds ?? 0,
      framesProbed: file.frameCount,
      fingerprint: '',
      demoProbe: file.probe.isDemoProbe,
      skippedRules: skippedRules,
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

}
