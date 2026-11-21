/// Defect detail — screens 06 + 07 (mobile + web).
///
/// One screen per finding, parameterised by rule: the subtitle defect
/// shows before/after frames; the audio defect shows before/after
/// waveforms; every defect shows its evidence, its auto-fix preview,
/// and the two decisions — Auto-fix, or Waive with reason.
library;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';
import '../widgets/frame_mock.dart';
import '../widgets/waveform.dart';

class DefectDetailScreen extends StatelessWidget {
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
    final p = AppTheme.palette;
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
              left: _beforeAfter(context, f),
              right: _evidenceCard(context, f),
            ),
            if (f.fix != null) ...[
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
                            f.fix!.label,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${f.fix!.detail} After: ${f.fix!.afterLabel}.',
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
                label: 'Auto-fix this finding',
                icon: Icons.build_outlined,
                onPressed: () => _fix(context, controller, report, f),
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
                'Fix it in the edit, auto-fix it here, or waive it — a '
                'waiver needs a reason and stays in the report.',
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
    final p = AppTheme.palette;
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

  Widget _beforeAfter(BuildContext context, Finding finding) {
    final p = AppTheme.palette;
    if (finding.ruleCode == kRuleSubtitleSafeArea) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FrameMock.before(
                      subtitleY: finding.measuredValue,
                      limitY: finding.limitValue,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'BEFORE · y = ${finding.measuredValue.toStringAsFixed(0)} px',
                      style: AppTheme.mono(size: 11, color: p.red),
                    ),
                    Text(
                      '${(finding.measuredValue - finding.limitValue).toStringAsFixed(0)} px below the line',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FrameMock.after(
                      subtitleY: finding.limitValue - 12,
                      limitY: finding.limitValue,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'AFTER · y = ${(finding.limitValue - 12).toStringAsFixed(0)} px',
                      style: AppTheme.mono(size: 11, color: p.green),
                    ),
                    Text(
                      'Inside the safe area',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (finding.ruleCode == kRuleAudioPeak) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Kicker('Before · waveform'),
                    Tag('Peak ${finding.timecode}', color: p.red),
                  ],
                ),
                const SizedBox(height: 10),
                WaveformView(
                  seed: 7,
                  height: 56,
                  peakAt: 0.66,
                  showLimit: true,
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
          ),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Kicker('After · limiter at −1.0 dBFS'),
                    Text(
                      'Peak −1.4 dBFS · inside',
                      style: AppTheme.mono(size: 12, color: p.green),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                WaveformView(
                  seed: 7,
                  height: 36,
                  cap: 0.62,
                  color: p.green.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ],
      );
    }
    // Generic before/after: measured vs limit, side by side.
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Kicker('Before / after'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Before',
                  value: finding.measuredLabel,
                  caption: 'measured',
                  valueColor: p.red,
                ),
              ),
              const Icon(Icons.arrow_forward, size: 18),
              Expanded(
                child: StatTile(
                  label: 'After the fix',
                  value: finding.fix?.afterLabel ?? finding.limitLabel,
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

  Widget _evidenceCard(BuildContext context, Finding finding) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Kicker('Evidence — measured, not guessed'),
          const SizedBox(height: 10),
          _evidenceRow(context, 'Measured', finding.measuredLabel),
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

  Future<void> _fix(
    BuildContext context,
    AppController controller,
    Report report,
    Finding finding,
  ) async {
    final updated = await controller.applyFix(report.id, finding.id);
    if (!context.mounted || updated == null) return;
    Navigator.pushNamed(
      context,
      '/autofix',
      arguments: {'reportId': updated.id},
    );
  }

  Future<void> _reinspect(
    BuildContext context,
    AppController controller,
    Report report,
  ) async {
    // The inspecting screen applies the fixes to the working copy and
    // runs with the previous report, so waivers carry forward.
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
