/// Report verdict — screen 05 (mobile + web).
///
/// The verdict: exit code, score, marker tracks, both defects, and the
/// two actions — Fix both in one tap, or Review defects. On web the
/// verdict sits beside the marker tracks and defects.
library;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';
import '../widgets/waveform.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final reportId = args?['reportId'] as String?;
    final report = reportId == null
        ? controller.currentReport
        : controller.reportById(reportId) ?? controller.currentReport;
    final p = AppTheme.palette;
    if (report == null) {
      return const FpScaffold(
        title: 'Report',
        showBack: true,
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No report yet',
            body: 'Inspect an export to get your first verdict.',
          ),
        ),
      );
    }
    final export = controller.exportById(report.exportId);
    final openDefects = report.openDefects;
    final headline = report.isClean
        ? 'Clean.\nShip it.'
        : openDefects.length == 1
            ? 'One defect.\nDon’t ship it.'
            : '${openDefects.length} defects.\nDon’t ship it.';
    return FpScaffold(
      title: 'Report',
      showBack: true,
      actions: [Center(child: ExitBadge(report.exitCode))],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Kicker(
              'Inspection complete · ${report.durationSeconds} seconds',
            ),
            const SizedBox(height: 6),
            Text(
              headline,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (report.demoProbe) ...[
              const SizedBox(height: 8),
              Tag('DEMO probe — values derived, not measured',
                  color: p.muted),
            ],
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: GlassCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXIT CODE',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${report.exitCode}',
                              style: AppTheme.mono(
                                size: 38,
                                color: report.isClean ? p.green : p.red,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'REGISTRY ${report.registryVersion}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${formatInt(report.framesProbed)} frames · '
                              '${report.findings.length} findings',
                              style:
                                  AppTheme.mono(size: 12, color: p.secondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatTile(
                          label: 'Defects',
                          value: '${report.defects.length}',
                          caption: 'blocking',
                          valueColor: report.defects.isEmpty
                              ? p.green
                              : p.red,
                        ),
                        StatTile(
                          label: 'Suggestions',
                          value: '${report.suggestions.length}',
                          caption: 'not blocking',
                        ),
                        StatTile(
                          label: 'Score',
                          value: '${report.score}',
                          caption: 'out of 100',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (export != null) ...[
                    Kicker(
                      'Marker tracks · 00:00–${formatDuration(export.durationSeconds)}',
                    ),
                    const SizedBox(height: 8),
                    GlassCard(
                      child: MarkerTracks(
                        durationSeconds: export.durationSeconds,
                        markers: report.defects
                            .map((f) => (
                                  _secondsOf(f.timecode),
                                  f.ruleCode.split('-').first,
                                  true,
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final finding in report.defects)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _defectMini(context, report, finding),
                    ),
                  if (report.suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: FpGhostButton(
                        label:
                            'View ${report.suggestions.length} suggestions',
                        icon: Icons.lightbulb_outline,
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/suggestions',
                          arguments: {'reportId': report.id},
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (openDefects.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: FpPrimaryButton(
                      label: openDefects.length == 1
                          ? 'Fix it'
                          : 'Fix all (${openDefects.length})',
                      icon: Icons.build_outlined,
                      onPressed: () => _fixAll(context, controller, report),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FpGhostButton(
                      label: 'Review defects',
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/defect',
                        arguments: {
                          'reportId': report.id,
                          'findingId': openDefects.first.id,
                        },
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FpPrimaryButton(
                      label: 'Export report',
                      icon: Icons.share_outlined,
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/export',
                        arguments: {'reportId': report.id},
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FpGhostButton(
                      label: 'Inspect another',
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/inspect',
                        (route) => false,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/export',
                  arguments: {'reportId': report.id},
                ),
                child: const Text('Export this report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defectMini(
    BuildContext context,
    Report report,
    Finding finding,
  ) {
    final p = AppTheme.palette;
    final color = switch (finding.status) {
      FindingStatus.open => p.red,
      FindingStatus.fixed => p.green,
      FindingStatus.confirmed => p.green,
      FindingStatus.waived => p.muted,
    };
    final statusLabel = switch (finding.status) {
      FindingStatus.open => 'Defect',
      FindingStatus.fixed => 'Fixed · awaiting re-inspection',
      FindingStatus.confirmed => 'Confirmed fixed',
      FindingStatus.waived => 'Waived',
    };
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/defect',
          arguments: {'reportId': report.id, 'findingId': finding.id},
        ),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  finding.ruleCode,
                  style: AppTheme.mono(size: 12, color: p.secondary),
                ),
                Tag(statusLabel, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              finding.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 2),
            Text(
              '${finding.timecode} · ${finding.measuredLabel} vs ${finding.limitLabel}',
              style: AppTheme.mono(size: 12, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }

  static double _secondsOf(String timecode) {
    // HH:MM:SS:FF — frames ignored for marker placement.
    final parts = timecode.split(':');
    if (parts.length < 3) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;
    return (h * 3600 + m * 60 + s).toDouble();
  }

  Future<void> _fixAll(
    BuildContext context,
    AppController controller,
    Report report,
  ) async {
    final updated = await controller.applyAllFixes(report.id);
    if (!context.mounted || updated == null) return;
    Navigator.pushNamed(
      context,
      '/autofix',
      arguments: {'reportId': updated.id},
    );
  }
}
