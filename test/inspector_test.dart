import 'package:flutter_test/flutter_test.dart';
import 'package:frame_police/core/constants.dart';
import 'package:frame_police/engine/demo_data.dart';
import 'package:frame_police/engine/inspector.dart';
import 'package:frame_police/engine/models.dart';
import 'package:frame_police/engine/registry.dart';

void main() {
  group('demo teaser inspection (V7 canon)', () {
    late ExportFile teaser;
    late Report report;

    setUp(() {
      teaser = demoExports().first;
      report = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
        now: DateTime.utc(2026, 11, 21, 12),
      );
    });

    test('finds exactly 2 defects and 3 suggestions', () {
      expect(report.defects.length, 2);
      expect(report.suggestions.length, 3);
      expect(report.findings.length, 5);
    });

    test('subtitle defect carries the canonical evidence', () {
      final subtitle = report.defects.firstWhere(
        (f) => f.ruleCode == kRuleSubtitleSafeArea,
      );
      expect(subtitle.timecode, DemoFixture.subtitleTimecode);
      expect(subtitle.measuredValue, DemoFixture.subtitleBottomY);
      expect(subtitle.limitValue, DemoFixture.subtitleLimitY);
      expect(subtitle.measuredValue - subtitle.limitValue, 14);
    });

    test('audio defect carries the canonical evidence', () {
      final peak = report.defects.firstWhere(
        (f) => f.ruleCode == kRuleAudioPeak,
      );
      expect(peak.timecode, DemoFixture.peakTimecode);
      expect(peak.measuredValue, DemoFixture.peakDbfs);
      expect(peak.limitValue, DemoFixture.peakLimitDbfs);
    });

    test('score is 82 and exit code is 1', () {
      expect(report.score, 82);
      expect(report.exitCode, kExitDefects);
    });

    test('registry version is recorded', () {
      expect(report.registryVersion, kRegistryVersion);
    });

    test('inspection is deterministic', () {
      final again = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
        now: DateTime.utc(2026, 11, 21, 12),
      );
      expect(again.fingerprint, report.fingerprint);
      expect(again.score, report.score);
      expect(again.exitCode, report.exitCode);
    });
  });

  group('clean export', () {
    test('Product Demo v2 is clean: exit 0, score 100', () {
      final demo = demoExports()[1];
      final report = Inspector.inspect(
        file: demo,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      expect(report.defects, isEmpty);
      expect(report.suggestions, isEmpty);
      expect(report.exitCode, kExitClean);
      expect(report.score, 100);
    });
  });

  group('other demo exports', () {
    test('Founder Story cut 4 has 1 defect (black frames)', () {
      final founder = demoExports()[2];
      final report = Inspector.inspect(
        file: founder,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      expect(report.defects.length, 1);
      expect(report.defects.first.ruleCode, kRuleBlackFrames);
      expect(report.score, 91);
      expect(report.exitCode, kExitDefects);
    });

    test('known-bad reel has 5 defects and 3 suggestions', () {
      final bad = demoExports()[3];
      final report = Inspector.inspect(
        file: bad,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      expect(report.defects.length, 5);
      expect(report.suggestions.length, 3);
      expect(report.score, 55);
      expect(report.exitCode, kExitDefects);
    });
  });

  group('suggestions never block', () {
    test('suggestions-only run is exit 0 with score 100', () {
      final teaser = demoExports().first;
      // Disable all defect rules: only suggestions can fire.
      final rules = defaultRules()
          .map((r) => r.isDefect ? r.copyWith(enabled: false) : r)
          .toList();
      final report = Inspector.inspect(
        file: teaser,
        rules: rules,
        registryVersion: kRegistryVersion,
      );
      expect(report.suggestions.length, 3);
      expect(report.defects, isEmpty);
      expect(report.exitCode, kExitClean);
      expect(report.score, 100);
    });

    test('suggestions disabled removes them from the report', () {
      final teaser = demoExports().first;
      final report = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
        suggestionsEnabled: false,
      );
      expect(report.suggestions, isEmpty);
      expect(report.defects.length, 2);
    });
  });

  group('score', () {
    test('score drops 9 points per blocking defect', () {
      expect(Inspector.scoreFor(const []), 100);
      final one = _defect(status: FindingStatus.open);
      expect(Inspector.scoreFor([one]), 91);
      expect(Inspector.scoreFor([one, one]), 82);
    });

    test('fixed-but-unconfirmed defects still cost points', () {
      final fixed = _defect(status: FindingStatus.fixed);
      expect(Inspector.scoreFor([fixed]), 91);
    });

    test('waived and confirmed defects cost nothing', () {
      final waived = _defect(status: FindingStatus.waived);
      final confirmed = _defect(status: FindingStatus.confirmed);
      expect(Inspector.scoreFor([waived, confirmed]), 100);
    });
  });

  group('fix + re-inspection', () {
    test('fixing both defects and re-inspecting lands exit 0', () {
      final teaser = demoExports().first;
      final first = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      expect(first.exitCode, kExitDefects);

      // Mark both fixed, apply the fixes to the working copy.
      final fixedReport = first.copyWith(
        findings: first.findings
            .map((f) => f.isDefect
                ? f.copyWith(status: FindingStatus.fixed)
                : f)
            .toList(),
      );
      final workingCopy = Inspector.applyFixesToExport(
        teaser,
        fixedReport.fixedAwaiting,
      );
      final second = Inspector.inspect(
        file: workingCopy,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
        previousReport: fixedReport,
      );
      expect(second.exitCode, kExitClean);
      expect(second.score, 100);
      expect(
        second.findings
            .where((f) => f.status == FindingStatus.confirmed)
            .length,
        2,
      );
    });

    test('a waiver carries forward across re-inspection', () {
      final teaser = demoExports().first;
      final first = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      final waiver = Waiver(
        reason: DemoFixture.waiverReason,
        tag: 'Client approved',
        createdAt: DateTime.utc(2026, 11, 21, 12),
        waivedBy: 'Guest',
      );
      final updated = first.copyWith(
        findings: first.findings.map((f) {
          if (f.ruleCode == kRuleSubtitleSafeArea) {
            return f.copyWith(
              status: FindingStatus.waived,
              waiver: waiver,
            );
          }
          if (f.ruleCode == kRuleAudioPeak) {
            return f.copyWith(status: FindingStatus.fixed);
          }
          return f;
        }).toList(),
      );
      final workingCopy = Inspector.applyFixesToExport(
        teaser,
        updated.fixedAwaiting,
      );
      final second = Inspector.inspect(
        file: workingCopy,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
        previousReport: updated,
      );
      expect(second.exitCode, kExitClean);
      expect(second.score, 100);
      expect(second.waivedDefects.length, 1);
      expect(
        second.waivedDefects.first.waiver!.reason,
        DemoFixture.waiverReason,
      );
      expect(
        second.findings
            .where((f) => f.status == FindingStatus.confirmed)
            .length,
        1,
      );
    });

    test('a fix that does not hold re-opens the defect', () {
      final teaser = demoExports().first;
      final first = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
      );
      // Marked fixed but the working copy was NOT actually fixed.
      final fixedReport = first.copyWith(
        findings: first.findings
            .map((f) => f.isDefect
                ? f.copyWith(status: FindingStatus.fixed)
                : f)
            .toList(),
      );
      final second = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
        previousReport: fixedReport,
      );
      expect(second.exitCode, kExitDefects);
      expect(
        second.defects
            .where((f) => f.status == FindingStatus.open)
            .length,
        2,
      );
    });
  });

  group('demo probe', () {
    test('same file gives the same probe', () {
      final a = Inspector.demoProbeFor('clip.mp4', 123456);
      final b = Inspector.demoProbeFor('clip.mp4', 123456);
      expect(a.subtitleBottomY, b.subtitleBottomY);
      expect(a.peakDbfs, b.peakDbfs);
      expect(a.blackFrameCount, b.blackFrameCount);
      expect(a.isDemoProbe, isTrue);
    });

    test('different files usually differ', () {
      final a = Inspector.demoProbeFor('a.mp4', 100);
      final b = Inspector.demoProbeFor('b.mp4', 200);
      expect(
        a.subtitleBottomY != b.subtitleBottomY ||
            a.peakDbfs != b.peakDbfs,
        isTrue,
      );
    });
  });

  group('fingerprint', () {
    test('same report content gives the same fingerprint', () {
      final teaser = demoExports().first;
      final a = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
        now: DateTime.utc(2026, 11, 21, 12),
      );
      final b = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
        now: DateTime.utc(2026, 11, 21, 12),
      );
      expect(a.fingerprint, b.fingerprint);
      expect(a.fingerprint.length, 64);
    });

    test('different findings give a different fingerprint', () {
      final teaser = demoExports().first;
      final bad = demoExports()[3];
      final a = Inspector.inspect(
        file: teaser,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
        now: DateTime.utc(2026, 11, 21, 12),
      );
      final b = Inspector.inspect(
        file: bad,
        rules: defaultRules(),
        registryVersion: kRegistryVersion,
        now: DateTime.utc(2026, 11, 21, 12),
      );
      expect(a.fingerprint, isNot(b.fingerprint));
    });
  });

  group('subtitle limit', () {
    test('90% margin on a 1920 px frame is y ≤ 1,052 px', () {
      expect(Inspector.subtitleLimitY(1920, 90), closeTo(1052, 0.001));
    });

    test('limit scales with the margin setting', () {
      expect(
        Inspector.subtitleLimitY(1920, 85),
        lessThan(Inspector.subtitleLimitY(1920, 90)),
      );
      expect(
        Inspector.subtitleLimitY(1920, 93),
        greaterThan(Inspector.subtitleLimitY(1920, 90)),
      );
    });
  });
}

Finding _defect({required FindingStatus status}) => Finding(
      id: kRuleSubtitleSafeArea,
      ruleCode: kRuleSubtitleSafeArea,
      ruleVersion: 'v1.2',
      title: 'Subtitle sits below the safe area.',
      kind: FindingKind.defect,
      timecode: '00:00:12:08',
      measuredLabel: 'y = 1,066 px',
      measuredValue: 1066,
      limitLabel: 'y ≤ 1,052 px',
      limitValue: 1052,
      detail: 'Test defect.',
      status: status,
    );
