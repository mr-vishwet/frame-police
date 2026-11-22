import 'package:flutter_test/flutter_test.dart';
import 'package:frame_police/core/constants.dart';
import 'package:frame_police/engine/autofix.dart';
import 'package:frame_police/engine/inspector.dart';
import 'package:frame_police/engine/models.dart';
import 'package:frame_police/engine/registry.dart';

import 'test_fixtures.dart';

/// A hand-built finding for guidance tests.
Finding _finding({
  required String ruleCode,
  required double measuredValue,
  required double limitValue,
  String measuredLabel = 'measured',
  String limitLabel = 'limit',
  String timecode = '00:00:12:08',
}) =>
    Finding(
      id: ruleCode,
      ruleCode: ruleCode,
      ruleVersion: 'v1.0',
      title: 'Test finding.',
      kind: FindingKind.defect,
      timecode: timecode,
      measuredLabel: measuredLabel,
      measuredValue: measuredValue,
      limitLabel: limitLabel,
      limitValue: limitValue,
      detail: 'Test finding.',
    );

void main() {
  group('fixForRule guidance', () {
    test('every defect rule has guidance', () {
      final defects =
          defaultRules().where((r) => r.isDefect).toList();
      expect(defects.length, kDefectRuleCount);
      for (final rule in defects) {
        expect(
          fixForRule(rule.code),
          isNotNull,
          reason: '${rule.code} has no fix guidance',
        );
      }
    });

    test('suggestion rules have no guidance', () {
      for (final code in [
        kRuleLoudness,
        kRuleOpeningFrame,
        kRuleCaptionsFile,
      ]) {
        expect(fixForRule(code), isNull);
      }
    });

    test('guidance without a finding is generic but honest', () {
      final fix = fixForRule(kRuleSubtitleSafeArea)!;
      expect(fix.label, contains('Fix in your editor'));
      expect(fix.label, isNot(contains('Auto-fix')));
      expect(fix.detail, contains('Re-export and re-inspect'));
      expect(fix.detail, contains('stays open'));
    });

    test('subtitle guidance carries the exact values', () {
      final report = Inspector.inspect(
        file: twoDefectExport(),
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      final subtitle = report.defects.firstWhere(
        (f) => f.ruleCode == kRuleSubtitleSafeArea,
      );
      final fix = fixForRule(subtitle.ruleCode, finding: subtitle)!;
      expect(fix.label, contains('14 px'));
      expect(fix.detail, contains('1,066 px'));
      expect(fix.detail, contains('1,052 px'));
      expect(fix.detail, contains('00:00:12:08'));
      expect(fix.afterLabel, 'y ≤ 1,052 px');
    });

    test('audio peak guidance carries the exact values', () {
      final report = Inspector.inspect(
        file: knownBadExport(),
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      final peak = report.defects.firstWhere(
        (f) => f.ruleCode == kRuleAudioPeak,
      );
      final fix = fixForRule(peak.ruleCode, finding: peak)!;
      expect(fix.label, contains('0.4 dB'));
      expect(fix.detail, contains('−0.6 dBFS'));
      expect(fix.detail, contains('−1.0 dBFS'));
      expect(fix.afterLabel, contains('−1.0 dBFS'));
    });

    test('audio silence guidance is a different fix', () {
      final silence = _finding(
        ruleCode: kRuleAudioPeak,
        measuredValue: 2.1,
        limitValue: 1.5,
        measuredLabel: '2.1 s silence',
        limitLabel: '≤ 1.5 s',
      );
      final fix = fixForRule(silence.ruleCode, finding: silence)!;
      expect(fix.label, contains('dead air'));
      expect(fix.detail, contains('2.1 s'));
      expect(fix.detail, contains('1.5 s'));
      expect(fix.detail, isNot(contains('dBFS')));
    });

    test('black-frame guidance carries the count', () {
      final report = Inspector.inspect(
        file: singleDefectExport(),
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      final finding = report.defects.first;
      final fix = fixForRule(finding.ruleCode, finding: finding)!;
      expect(fix.label, contains('4 black frames'));
      expect(fix.afterLabel, '0 black frames');
    });

    test('caption-sync guidance carries offset and tolerance', () {
      final finding = _finding(
        ruleCode: kRuleCaptionSync,
        measuredValue: 90,
        limitValue: 120,
        measuredLabel: '90 ms offset',
        limitLabel: '±120 ms',
      );
      final fix = fixForRule(finding.ruleCode, finding: finding)!;
      expect(fix.label, contains('90 ms'));
      expect(fix.detail, contains('±120 ms'));
      expect(fix.afterLabel, 'Within ±120 ms');
    });

    test('aspect, frame-rate, and resolution guidance name the values',
        () {
      final aspect = _finding(
        ruleCode: kRuleAspectRatio,
        measuredValue: 16 / 9,
        limitValue: 9 / 16,
        measuredLabel: '16:9',
        limitLabel: '9:16',
      );
      expect(
        fixForRule(aspect.ruleCode, finding: aspect)!.label,
        contains('9:16'),
      );
      final frameRate = _finding(
        ruleCode: kRuleFrameRate,
        measuredValue: 30,
        limitValue: 24,
        measuredLabel: '30 fps',
        limitLabel: '24 fps',
      );
      final rateFix =
          fixForRule(frameRate.ruleCode, finding: frameRate)!;
      expect(rateFix.detail, contains('30 fps'));
      expect(rateFix.detail, contains('24 fps'));
      final resolution = _finding(
        ruleCode: kRuleMinResolution,
        measuredValue: 720,
        limitValue: 1080,
        measuredLabel: '720 px short edge',
        limitLabel: '≥ 1080 px short edge',
      );
      final resFix =
          fixForRule(resolution.ruleCode, finding: resolution)!;
      expect(resFix.detail, contains('720 px'));
      expect(resFix.detail, contains('1080 px'));
    });
  });

  group('guidance never mutates the probe', () {
    test('reading guidance leaves the export untouched and the finding open',
        () {
      final export = knownBadExport();
      final report = Inspector.inspect(
        file: export,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      expect(report.defects.length, 5);
      // Reading the guidance for every defect changes nothing.
      for (final finding in report.defects) {
        expect(
          fixForRule(finding.ruleCode, finding: finding),
          isNotNull,
        );
      }
      expect(export.probe.subtitleBottomY, 1080);
      expect(export.probe.peakDbfs, -0.6);
      expect(export.probe.blackFrameCount, 2);
      // Re-inspecting the same file still fails: the finding stays
      // open until a new file is re-exported and re-inspected.
      final recheck = Inspector.inspect(
        file: export,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      expect(recheck.defects.length, 5);
      expect(recheck.exitCode, kExitDefects);
    });
  });
}
