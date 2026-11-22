/// Defect detail — screens 06 + 07 (mobile + web).
///
/// One screen per finding, parameterised by rule: the frame the probe
/// captured (when it captured one), the real audio waveform (when the
/// probe captured peaks), the finding's evidence, its fix guidance,
/// and the two decisions — fix it in your editor, or waive with reason.
///
/// Nothing here is mocked: no frame is drawn, no waveform is seeded.
/// When the probe captured no frame or no peaks, the screen says so
/// instead of inventing evidence. The evidence label reads "Measured"
/// only when the report's probe actually measured the file; demo-probe
/// reports say "Demo values".
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/autofix.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';
import '../widgets/waveform.dart';

/// The defect detail screen screen.
class DefectDetailScreen extends StatelessWidget {
  /// Creates a [DefectDetailScreen].
  const DefectDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final reportId = args?['reportId'] as String?;
    final findingId = args?['findingId'] as String?;
    final report = reportId == null
        ? controller.currentReport
        : controller.reportById(reportId) ?? controller.currentReport;
    const p = AppTheme.palette;
    Finding? finding;
    if (report != null && findingId != null) {
      for (final f in report.defects) {
        if (f.id == findingId) finding = f;
      }
    }
    if (report == null || finding == null) {
      return const FpScaffold(
        title: 'Defect',
        showBack: true,
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.search_off_outlined,
            title: 'Defect not found',
            body: 'It may belong to an older report.',
          ),
        ),
      );
    }
    final defects = report.defects;
    final index = defects.indexOf(finding);
    final f = finding;
    final export = controller.exportById(report.exportId);
    final isDemo = report.demoProbe;
    final guidance = fixForRule(f.ruleCode, finding: f) ?? f.fix;
    return FpScaffold(
      title: 'Defect ${index + 1} of ${defects.length}',
      showBack: true,
      actions: [Center(child: Tag('Defect', color: p.red))],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${f.ruleCode} · ${_ruleName(controller, f.ruleCode)}',
              style: AppTheme.mono(size: 12, color: p.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              f.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Frame ${f.timecode}',
                  style: AppTheme.mono(size: 12, color: p.muted),
                ),
                _statusTag(context, f),
              ],
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: _evidence(context, f, export, isDemo),
              right: _evidenceCard(context, f, isDemo),
            ),
            if (guidance != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                borderColor: p.orange.withValues(alpha: 0.55),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.build_outlined, size: 20, color: p.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guidance.label,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${guidance.detail} Target: ${guidance.afterLabel}.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (f.waiver != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                borderColor: p.muted.withValues(alpha: 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Waived — on record'),
                    const SizedBox(height: 6),
                    Text(
                      '“${f.waiver!.reason}”',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${f.waiver!.tag} · ${f.waiver!.waivedBy}',
                      style: AppTheme.mono(size: 12, color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (f.status == FindingStatus.open) ...[
              FpPrimaryButton(
                label: 'How to fix in your editor',
                icon: Icons.build_outlined,
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/autofix',
                  arguments: {'reportId': report.id, 'findingId': f.id},
                ),
              ),
              const SizedBox(height: 8),
              FpGhostButton(
                label: 'Waive with reason',
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/waiver',
                  arguments: {'reportId': report.id, 'findingId': f.id},
                ),
              ),
            ] else if (f.status == FindingStatus.fixed) ...[
              FpPrimaryButton(
                label: 'Re-inspect now',
                icon: Icons.refresh,
                onPressed: () => _reinspect(context, controller, report),
              ),
            ] else ...[
              FpGhostButton(
                label: 'Back to report',
                onPressed: () => Navigator.pop(context),
              ),
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Fix it in your editor, re-export, and re-inspect — or '
                'waive it with a reason. A waiver stays in the report.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            if (defects.length > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: index > 0
                        ? () => Navigator.pushReplacementNamed(
                              context,
                              '/defect',
                              arguments: {
                                'reportId': report.id,
                                'findingId': defects[index - 1].id,
                              },
                            )
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Previous'),
                  ),
                  TextButton.icon(
                    onPressed: index < defects.length - 1
                        ? () => Navigator.pushReplacementNamed(
                              context,
                              '/defect',
                              arguments: {
                                'reportId': report.id,
                                'findingId': defects[index + 1].id,
                              },
                            )
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 18),
                    label: const Text('Next defect'),
                    iconAlignment: IconAlignment.end,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusTag(BuildContext context, Finding finding) {
    const p = AppTheme.palette;
    return switch (finding.status) {
      FindingStatus.open => Tag(
          finding.ruleCode == kRuleSubtitleSafeArea
              ? 'Breach ${(finding.measuredValue - finding.limitValue).toStringAsFixed(0)} px'
              : 'Open',
          color: p.red,
        ),
      FindingStatus.fixed => Tag('Fixed · awaiting re-inspection',
          color: p.green),
      FindingStatus.confirmed => Tag('Confirmed fixed', color: p.green),
      FindingStatus.waived => Tag('Waived', color: p.muted),
    };
  }

  String _ruleName(AppController controller, String code) {
    return controller.ruleByCode(code)?.name ?? code;
  }

  /// Real evidence for the finding: the frame the probe captured, or
  /// the real audio waveform — with an honest empty state when the
  /// probe captured neither.
  Widget _evidence(
    BuildContext context,
    Finding finding,
    ExportFile? export,
    bool isDemo,
  ) {
    if (finding.ruleCode == kRuleSubtitleSafeArea ||
        finding.ruleCode == kRuleTitleSafeArea ||
        finding.ruleCode == kRuleTextOverflow ||
        finding.ruleCode == kRuleBlackFrames) {
      return _frameEvidence(context, finding, export);
    }
    if (finding.ruleCode == kRuleAudioPeak) {
      return _waveformEvidence(context, finding, export);
    }
    // Generic evidence: measured vs target, side by side.
    const p = AppTheme.palette;
    final guidance = fixForRule(finding.ruleCode, finding: finding);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Kicker('Measured vs target'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: isDemo ? 'Derived' : 'Measured',
                  value: finding.measuredLabel,
                  caption: isDemo ? 'demo probe' : 'measured',
                  valueColor: p.red,
                ),
              ),
              const Icon(Icons.arrow_forward, size: 18),
              Expanded(
                child: StatTile(
                  label: 'Target',
                  value: guidance?.afterLabel ?? finding.limitLabel,
                  caption: 'inside the limit',
                  valueColor: p.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _frameEvidence(
    BuildContext context,
    Finding finding,
    ExportFile? export,
  ) {
    const p = AppTheme.palette;
    final bytes = _thumbnailBytes(export);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Kicker('Frame evidence'),
          const SizedBox(height: 10),
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.glass,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No frame captured',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: p.muted),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${finding.timecode} · ${finding.measuredLabel} vs '
              '${finding.limitLabel}',
              style: AppTheme.mono(size: 11, color: p.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waveformEvidence(
    BuildContext context,
    Finding finding,
    ExportFile? export,
  ) {
    const p = AppTheme.palette;
    final peaks = export?.waveformPeaks;
    final isPeakDefect = finding.limitValue < 0;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Kicker('Waveform'),
              Tag('Peak ${finding.timecode}', color: p.red),
            ],
          ),
          const SizedBox(height: 10),
          if (peaks != null && peaks.isNotEmpty)
            WaveformView(
              peaks: peaks,
              height: 56,
              peakAt: isPeakDefect ? _peakAt(finding, export) : null,
              showLimit: isPeakDefect,
            )
          else
            Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.glass,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No audio waveform',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: p.muted),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${finding.timecode} · ${finding.measuredLabel}',
              style: AppTheme.mono(size: 11, color: p.red),
            ),
          ),
        ],
      ),
    );
  }

  /// The probe's frame thumbnail, decoded — null when the probe
  /// captured no frame or the bytes do not decode.
  Uint8List? _thumbnailBytes(ExportFile? export) {
    final raw = export?.frameThumbnailBase64;
    if (raw == null) return null;
    try {
      return base64Decode(raw);
    } on FormatException {
      return null;
    }
  }

  /// Position of the finding's timecode in the export (0..1), for the
  /// peak marker on the waveform.
  double? _peakAt(Finding finding, ExportFile? export) {
    final duration = export?.durationSeconds;
    if (duration == null || duration <= 0) return null;
    final parts = finding.timecode.split(':');
    if (parts.length < 3) return null;
    final seconds = (int.tryParse(parts[0]) ?? 0) * 3600 +
        (int.tryParse(parts[1]) ?? 0) * 60 +
        (int.tryParse(parts[2]) ?? 0);
    return (seconds / duration).clamp(0.0, 1.0);
  }

  Widget _evidenceCard(BuildContext context, Finding finding, bool isDemo) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(
            isDemo ? 'Evidence — demo values' : 'Evidence — measured',
          ),
          const SizedBox(height: 10),
          _evidenceRow(
            context,
            isDemo ? 'Derived' : 'Measured',
            finding.measuredLabel,
          ),
          _evidenceRow(context, 'Limit', finding.limitLabel),
          _evidenceRow(context, 'Timecode', finding.timecode),
          _evidenceRow(
            context,
            'Rule version',
            '${finding.ruleCode} · ${finding.ruleVersion}',
          ),
          const SizedBox(height: 8),
          Text(
            finding.detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                ),
          ),
          if (isDemo) ...[
            const SizedBox(height: 8),
            Text(
              'Demo probe — these values were derived from the file, '
              'not measured from its media.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _evidenceRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: AppTheme.mono(size: 13)),
        ],
      ),
    );
  }

  Future<void> _reinspect(
    BuildContext context,
    AppController controller,
    Report report,
  ) async {
    // The inspecting screen re-runs with the previous report, so
    // waivers carry forward.
    if (!context.mounted) return;
    Navigator.pushNamed(
      context,
      '/inspecting',
      arguments: {
        'exportId': report.exportId,
        'previousReportId': report.id,
      },
    );
  }
}
