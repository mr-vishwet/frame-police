/// The reporter: renders a [Report] as HTML, JSON, Markdown, or TTY.
///
/// Every format carries the same findings, the same evidence, the
/// registry version, the exit code, and every waiver with its reason.
/// The report is the record — nothing in it can be edited after the run,
/// and the SHA-256 fingerprint covers the canonical JSON.
library;

import 'dart:convert';

import '../core/constants.dart';
import '../core/format.dart';
import 'exit_codes.dart';
import 'models.dart';

/// The four export formats.
enum ReportFormat { html, json, markdown, tty }

extension ReportFormatLabel on ReportFormat {
  String get label {
    switch (this) {
      case ReportFormat.html:
        return 'HTML report';
      case ReportFormat.json:
        return 'JSON';
      case ReportFormat.markdown:
        return 'Markdown';
      case ReportFormat.tty:
        return 'TTY';
    }
  }

  String get description {
    switch (this) {
      case ReportFormat.html:
        return 'Shareable page with frame overlays';
      case ReportFormat.json:
        return 'Machine-readable · for CI and tooling';
      case ReportFormat.markdown:
        return 'Paste into a PR, a doc, a ticket';
      case ReportFormat.tty:
        return 'Terminal output · colour-coded, pipeable';
    }
  }

  String get fileExtension {
    switch (this) {
      case ReportFormat.html:
        return 'html';
      case ReportFormat.json:
        return 'json';
      case ReportFormat.markdown:
        return 'md';
      case ReportFormat.tty:
        return 'txt';
    }
  }
}

class Reporter {
  Reporter._();

  /// Renders [report] in [format].
  static String render(Report report, ReportFormat format) {
    switch (format) {
      case ReportFormat.html:
        return toHtml(report);
      case ReportFormat.json:
        return toJson(report);
      case ReportFormat.markdown:
        return toMarkdown(report);
      case ReportFormat.tty:
        return toTty(report);
    }
  }

  /// Canonical JSON: the report object plus the exit-code contract note.
  static String toJson(Report report) {
    final doc = {
      'framePolice': 'v0.1',
      'report': report.toJson(),
      'exitCodeContract': {
        '0': 'Clean — no open defects',
        '1': 'Defects — one or more open defects',
        '2': 'Inspection error',
      },
      'note': 'Suggestions never affect the exit code. Waived defects '
          'carry their reason in the report.',
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  /// Markdown: paste into a PR, a doc, or a ticket.
  static String toMarkdown(Report report) {
    final buffer = StringBuffer();
    final verdict = report.isClean ? 'passed' : 'failed';
    buffer.writeln('# Frame Police — inspection $verdict '
        '(exit ${report.exitCode})');
    buffer.writeln();
    buffer.writeln('**${report.exportName}** · registry '
        '${report.registryVersion} · ${formatTimestamp(report.createdAt)}');
    buffer.writeln();
    buffer.writeln('| | |');
    buffer.writeln('|---|---|');
    buffer.writeln('| Exit code | **${report.exitCode}** — '
        '${exitCodeLabel(report.exitCode)} |');
    buffer.writeln('| Score | ${report.score}/100 (illustrative — the '
        'exit code is the verdict) |');
    buffer.writeln('| Defects | ${report.defects.length} '
        '(${report.openDefects.length} open, '
        '${report.fixedAwaiting.length} fixed awaiting re-inspection, '
        '${report.waivedDefects.length} waived) |');
    buffer.writeln('| Suggestions | ${report.suggestions.length} '
        '(never blocking) |');
    buffer.writeln('| Frames probed | ${formatInt(report.framesProbed)} |');
    if (report.demoProbe) {
      buffer.writeln('| Probe | DEMO probe — values derived, not measured |');
    }
    buffer.writeln();
    if (report.defects.isNotEmpty) {
      buffer.writeln('## Defects');
      buffer.writeln();
      for (final finding in report.defects) {
        buffer.writeln('### ${finding.ruleCode} — ${finding.title}');
        buffer.writeln();
        buffer.writeln('- Timecode: `${finding.timecode}`');
        buffer.writeln('- Measured: `${finding.measuredLabel}`');
        buffer.writeln('- Limit: `${finding.limitLabel}`');
        buffer.writeln('- Rule: `${finding.ruleCode} ${finding.ruleVersion}`');
        buffer.writeln('- Status: ${finding.status.name}');
        if (finding.waiver != null) {
          buffer.writeln('- Waived: "${finding.waiver!.reason}" '
              '(${finding.waiver!.tag}, ${finding.waiver!.waivedBy}, '
              '${formatTimestamp(finding.waiver!.createdAt)})');
        }
        if (finding.fix != null &&
            finding.status == FindingStatus.fixed) {
          buffer.writeln('- Fix applied: ${finding.fix!.label} — '
              '${finding.fix!.afterLabel}');
        }
        buffer.writeln();
      }
    }
    if (report.suggestions.isNotEmpty) {
      buffer.writeln('## Suggestions (not blocking)');
      buffer.writeln();
      for (final finding in report.suggestions) {
        buffer.writeln('- **${finding.ruleCode}** — ${finding.title}: '
            '${finding.detail}');
      }
      buffer.writeln();
    }
    buffer.writeln('---');
    buffer.writeln('Fingerprint (SHA-256): `${report.fingerprint}`');
    return buffer.toString();
  }

  /// TTY: colour-coded terminal output, pipeable.
  static String toTty(Report report) {
    const red = '\x1B[31m';
    const green = '\x1B[32m';
    const amber = '\x1B[33m';
    const reset = '\x1B[0m';
    final buffer = StringBuffer();
    buffer.writeln('FRAME POLICE  ·  ${report.exportName}');
    buffer.writeln('registry ${report.registryVersion}  ·  '
        '${formatTimestamp(report.createdAt)}');
    buffer.writeln();
    final exitColour = report.isClean ? green : red;
    buffer.writeln('$exitColour' 'exit ${report.exitCode} — '
        '${exitCodeLabel(report.exitCode)}$reset');
    buffer.writeln('score ${report.score}/100  ·  '
        '${report.defects.length} defects  ·  '
        '${report.suggestions.length} suggestions');
    if (report.demoProbe) {
      buffer.writeln('${amber}DEMO probe — values derived, not measured$reset');
    }
    buffer.writeln();
    for (final finding in report.defects) {
      final statusColour =
          finding.status == FindingStatus.waived ? amber : red;
      buffer.writeln('$statusColour✕ ${finding.ruleCode}$reset  '
          '${finding.title}');
      buffer.writeln('  ${finding.timecode}  ·  ${finding.measuredLabel} '
          'vs ${finding.limitLabel}  ·  ${finding.status.name}');
      if (finding.waiver != null) {
        buffer.writeln('  waived: "${finding.waiver!.reason}"');
      }
    }
    for (final finding in report.suggestions) {
      buffer.writeln('${amber}○ ${finding.ruleCode}$reset  ${finding.title}');
      buffer.writeln('  ${finding.detail}');
    }
    buffer.writeln();
    buffer.writeln('fingerprint ${report.fingerprint}');
    return buffer.toString();
  }

  /// Standalone HTML page with the V7 palette.
  static String toHtml(Report report) {
    String escape(String value) => value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    final defectsHtml = report.defects.map((finding) {
      final colour = finding.status == FindingStatus.waived
          ? '#fbbf24'
          : finding.status == FindingStatus.confirmed
              ? '#34d399'
              : '#f87171';
      final waiverHtml = finding.waiver == null
          ? ''
          : '<p class="waiver">Waived — “${escape(finding.waiver!.reason)}” '
              '(${escape(finding.waiver!.tag)}, '
              '${escape(finding.waiver!.waivedBy)})</p>';
      return '<section class="finding" style="border-color:$colour">'
          '<h3><code>${escape(finding.ruleCode)}</code> '
          '${escape(finding.title)}</h3>'
          '<p class="mono">${escape(finding.timecode)} · '
          '${escape(finding.measuredLabel)} vs '
          '${escape(finding.limitLabel)} · ${finding.status.name}</p>'
          '<p>${escape(finding.detail)}</p>$waiverHtml</section>';
    }).join('\n');

    final suggestionsHtml = report.suggestions.map((finding) {
      return '<section class="finding suggestion">'
          '<h3><code>${escape(finding.ruleCode)}</code> '
          '${escape(finding.title)}</h3>'
          '<p>${escape(finding.detail)}</p></section>';
    }).join('\n');

    final verdictColour = report.isClean ? '#34d399' : '#f87171';
    return '''<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<title>Frame Police — ${escape(report.exportName)}</title>
<style>
body{background:#0B0D10;color:#fff;font-family:system-ui,sans-serif;
  max-width:720px;margin:0 auto;padding:32px 20px;line-height:1.55}
h1{font-size:28px;margin:0 0 4px}.meta{color:#FBBF24;font-size:13px}
.verdict{font-size:20px;font-weight:700;color:$verdictColour;margin:16px 0}
.finding{border:1px solid #333;border-left:4px solid #f87171;
  border-radius:12px;padding:14px 18px;margin:12px 0;background:#161B22}
.finding.suggestion{border-left-color:#F5A524}
code{color:#FDE68A}.mono{font-family:ui-monospace,monospace;
  font-size:12px;color:#FBBF24}
.waiver{color:#FDE68A;font-style:italic}
.foot{color:rgba(255,255,255,.6);font-size:12px;margin-top:24px;
  word-break:break-all}
</style></head><body>
<h1>Frame Police — ${report.isClean ? 'clean' : 'defects found'}</h1>
<p class="meta">${escape(report.exportName)} · registry
${escape(report.registryVersion)} ·
${escape(formatTimestamp(report.createdAt))}</p>
<p class="verdict">Exit ${report.exitCode} — ${escape(exitCodeLabel(report.exitCode))}</p>
<p>Score ${report.score}/100 · ${report.defects.length} defects ·
${report.suggestions.length} suggestions (never blocking) ·
${formatInt(report.framesProbed)} frames probed</p>
${report.demoProbe ? '<p class="meta">DEMO probe — values derived, not measured.</p>' : ''}
$defectsHtml
${report.suggestions.isNotEmpty ? '<h2>Suggestions</h2>$suggestionsHtml' : ''}
<p class="foot">Fingerprint (SHA-256): ${report.fingerprint}<br>
Frame Police v0.1 — Build Specification. Suggestions never affect the exit code.</p>
</body></html>''';
  }
}

/// The GitHub Action workflow text (proposed integration — see the CI
/// setup screen and the README appendix). Eleven lines, no wizard.
const String kCiWorkflowYaml = '''name: Frame Police
on: [pull_request]
jobs:
  inspect:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: frame-police/action@v2
        with:
          registry: $kRegistryVersion
          paths: exports/**/*.mp4
''';
