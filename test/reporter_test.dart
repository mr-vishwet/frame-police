import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frame_police/core/constants.dart';
import 'package:frame_police/engine/demo_data.dart';
import 'package:frame_police/engine/inspector.dart';
import 'package:frame_police/engine/models.dart';
import 'package:frame_police/engine/registry.dart';
import 'package:frame_police/engine/reporter.dart';

void main() {
  late Report report;

  setUp(() {
    final teaser = demoExports().first;
    final inspected = Inspector.inspect(
      file: teaser,
      rules: defaultRules(),
      registryVersion: kRegistryVersion,
      now: DateTime.utc(2026, 11, 21, 12),
    );
    // Waive the subtitle defect so every format must carry the reason.
    final waiver = Waiver(
      reason: DemoFixture.waiverReason,
      tag: 'Client approved',
      createdAt: DateTime.utc(2026, 11, 21, 12, 5),
      waivedBy: 'Guest',
    );
    report = inspected.copyWith(
      findings: inspected.findings.map((f) {
        if (f.ruleCode == kRuleSubtitleSafeArea) {
          return f.copyWith(
            status: FindingStatus.waived,
            waiver: waiver,
          );
        }
        return f;
      }).toList(),
    );
  });

  group('JSON', () {
    test('is valid JSON with the report and the contract', () {
      final decoded =
          jsonDecode(Reporter.toJson(report)) as Map<String, dynamic>;
      expect(decoded['report']['exitCode'], 1);
      expect(decoded['report']['registryVersion'], kRegistryVersion);
      expect(decoded['exitCodeContract']['0'], contains('Clean'));
      expect(decoded['exitCodeContract']['1'], contains('Defects'));
      expect(decoded['exitCodeContract']['2'], contains('error'));
    });

    test('carries the waiver and its reason', () {
      final decoded =
          jsonDecode(Reporter.toJson(report)) as Map<String, dynamic>;
      final findings =
          decoded['report']['findings'] as List<dynamic>;
      final waived = findings.firstWhere(
        (f) => f['ruleCode'] == kRuleSubtitleSafeArea,
      ) as Map<String, dynamic>;
      expect(waived['status'], 'waived');
      expect(
        waived['waiver']['reason'],
        DemoFixture.waiverReason,
      );
    });
  });

  group('Markdown', () {
    test('carries verdict, registry, defects, and waiver', () {
      final md = Reporter.toMarkdown(report);
      expect(md, contains('exit code 1'));
      expect(md, contains(kRegistryVersion));
      expect(md, contains('SUB-SAFE-01'));
      expect(md, contains('AUD-PEAK-02'));
      expect(md, contains(DemoFixture.waiverReason));
      expect(md, contains('Suggestions (not blocking)'));
      expect(md, contains(report.fingerprint));
    });
  });

  group('TTY', () {
    test('carries verdict, defects, and waiver', () {
      final tty = Reporter.toTty(report);
      expect(tty, contains('exit 1'));
      expect(tty, contains('SUB-SAFE-01'));
      expect(tty, contains(DemoFixture.waiverReason));
      expect(tty, contains(report.fingerprint));
    });
  });

  group('HTML', () {
    test('is a standalone page with verdict and waiver', () {
      final html = Reporter.toHtml(report);
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('Exit 1'));
      expect(html, contains(kRegistryVersion));
      expect(html, contains(DemoFixture.waiverReason));
      expect(html, contains(report.fingerprint));
    });

    test('escapes HTML in the waiver reason', () {
      final evil = report.copyWith(
        findings: report.findings.map((f) {
          if (f.waiver == null) return f;
          return f.copyWith(
            waiver: Waiver(
              reason: '<script>alert(1)</script>',
              tag: 'x',
              createdAt: DateTime.utc(2026, 11, 21),
              waivedBy: 'x',
            ),
          );
        }).toList(),
      );
      final html = Reporter.toHtml(evil);
      expect(html, isNot(contains('<script>alert(1)</script>')));
      expect(html, contains('&lt;script&gt;'));
    });
  });

  group('render dispatch', () {
    test('every format renders without throwing', () {
      for (final format in ReportFormat.values) {
        final out = Reporter.render(report, format);
        expect(out.isNotEmpty, isTrue);
      }
    });
  });

  group('CI workflow YAML', () {
    test('pins the registry and the export path', () {
      expect(kCiWorkflowYaml, contains('registry: $kRegistryVersion'));
      expect(kCiWorkflowYaml, contains('exports/**/*.mp4'));
      expect(kCiWorkflowYaml, contains('frame-police/action@v2'));
    });
  });
}
