import 'package:flutter_test/flutter_test.dart';
import 'package:frame_police/core/constants.dart';
import 'package:frame_police/engine/autofix.dart';
import 'package:frame_police/engine/demo_data.dart';
import 'package:frame_police/engine/inspector.dart';
import 'package:frame_police/engine/registry.dart';

void main() {
  group('fixForRule', () {
    test('every defect rule has a fix', () {
      final defects =
          defaultRules().where((r) => r.isDefect).toList();
      expect(defects.length, kDefectRuleCount);
      for (final rule in defects) {
        expect(
          fixForRule(rule.code),
          isNotNull,
          reason: '${rule.code} has no auto-fix',
        );
      }
    });

    test('suggestion rules have no fix', () {
      for (final code in [
        kRuleLoudness,
        kRuleOpeningFrame,
        kRuleCaptionsFile,
      ]) {
        expect(fixForRule(code), isNull);
      }
    });

    test('subtitle fix nudges 14 px to y = 1,040 px', () {
      final fix = fixForRule(kRuleSubtitleSafeArea)!;
      expect(fix.label, contains('14 px'));
      expect(fix.afterLabel, contains('1,040 px'));
    });

    test('audio fix applies a limiter at −1.0 dBFS', () {
      final fix = fixForRule(kRuleAudioPeak)!;
      expect(fix.label, contains('limiter'));
      expect(fix.afterLabel, contains('−1.4 dBFS'));
    });
  });

  group('applyFixesToExport', () {
    test('subtitle fix moves the subtitle inside the safe area', () {
      final teaser = demoExports().first;
      final report = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      final subtitle = report.defects.firstWhere(
        (f) => f.ruleCode == kRuleSubtitleSafeArea,
      );
      final fixed = Inspector.applyFixesToExport(teaser, [subtitle]);
      expect(fixed.probe.subtitleBottomY, 1040);
      expect(fixed.probe.subtitleBottomY, lessThanOrEqualTo(1052));
    });

    test('audio fix tames the peak to −1.4 dBFS', () {
      final teaser = demoExports().first;
      final report = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      final peak = report.defects.firstWhere(
        (f) => f.ruleCode == kRuleAudioPeak,
      );
      final fixed = Inspector.applyFixesToExport(teaser, [peak]);
      expect(fixed.probe.peakDbfs, DemoFixture.peakFixedDbfs);
    });

    test('black-frame fix trims to zero', () {
      final founder = demoExports()[2];
      final report = Inspector.inspect(
        file: founder,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      final fixed = Inspector.applyFixesToExport(
        founder,
        report.defects,
      );
      expect(fixed.probe.blackFrameCount, 0);
    });

    test('the original export is untouched', () {
      final teaser = demoExports().first;
      final report = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      Inspector.applyFixesToExport(teaser, report.defects);
      expect(teaser.probe.subtitleBottomY, 1066);
      expect(teaser.probe.peakDbfs, -0.8);
    });

    test('fixed working copy passes re-inspection', () {
      final teaser = demoExports().first;
      final report = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      final fixed = Inspector.applyFixesToExport(
        teaser,
        report.defects,
      );
      final recheck = Inspector.inspect(
        file: fixed,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      expect(recheck.defects, isEmpty);
      expect(recheck.exitCode, kExitClean);
    });
  });
}
