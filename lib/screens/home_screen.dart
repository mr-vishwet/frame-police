/// Home — screen 01 (mobile + web).
///
/// "Ship nothing with a defect." The latest report, the quality chart,
/// lifetime totals, and the Inspect CTA. On web the report card and the
/// chart sit side by side.
library;

import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';
import '../widgets/logo.dart';
import '../widgets/score_bars.dart';

/// The home screen screen.
class HomeScreen extends StatelessWidget {
  /// Creates a [HomeScreen].
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final report = controller.currentReport;
    const p = AppTheme.palette;
    return FpScaffold(
      tabIndex: 0,
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const FpLogoMark(size: 34),
                    const SizedBox(width: 10),
                    Text(
                      'FRAME POLICE',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Tag('Registry $kRegistryVersion', color: p.secondary),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Ship nothing\nwith a defect.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Fourteen checks on every export. The exit code is the verdict.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 16),
            AdaptiveColumns(
              left: _latestReportCard(context, controller),
              right: _qualityCard(context, controller),
            ),
            const SizedBox(height: 12),
            AdaptiveGrid(
              narrowColumns: 2,
              wideColumns: 2,
              children: [
                GlassCard(
                  child: StatTile(
                    label: 'Defects caught',
                    value: '${controller.defectsCaught}',
                    caption: 'Before upload, this project',
                  ),
                ),
                GlassCard(
                  child: StatTile(
                    label: 'Zero-defect exports',
                    value: '${controller.zeroDefectExports}',
                    caption: 'Clean runs, exit code 0',
                    valueColor: p.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FpPrimaryButton(
              label: 'Inspect an export',
              icon: Icons.arrow_forward,
              onPressed: () =>
                  Navigator.pushNamed(context, '/inspect'),
            ),
            if (report != null && report.demoProbe) ...[
              const SizedBox(height: 8),
              Center(
                child: Tag('DEMO probe — values derived, not measured',
                    color: p.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _latestReportCard(
    BuildContext context,
    AppController controller,
  ) {
    final report = controller.currentReport;
    const p = AppTheme.palette;
    if (report == null) {
      return const FpEmptyState(
        icon: Icons.document_scanner_outlined,
        title: 'No reports yet',
        body: 'Inspect an export to get your first verdict.',
      );
    }
    final export = controller.exportById(report.exportId);
    return GlassCard(
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/report',
          arguments: {'reportId': report.id},
        ),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker(
                        'Latest report · ${formatRelative(report.createdAt)}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.exportName,
                        style:
                            Theme.of(context).textTheme.titleMedium,
                      ),
                      if (export != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${formatDuration(export.durationSeconds)} · '
                          '${export.width}×${export.height} · '
                          '${export.aspectLabel} · ${export.fps} fps · '
                          '${formatBytes(export.sizeBytes)}',
                          style: AppTheme.mono(size: 12, color: p.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ExitBadge(report.exitCode),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatTile(
                  label: 'Defects',
                  value: '${report.defects.length}',
                  caption: 'block the release',
                  valueColor: report.defects.isEmpty ? p.green : p.red,
                ),
                StatTile(
                  label: 'Suggestions',
                  value: '${report.suggestions.length}',
                  caption: 'never blocking',
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
    );
  }

  Widget _qualityCard(BuildContext context, AppController controller) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Kicker('Quality · last 5 inspections'),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/history'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('History'),
                    Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ScoreBars(scores: controller.recentScores, height: 72),
        ],
      ),
    );
  }
}
