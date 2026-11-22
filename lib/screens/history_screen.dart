/// Quality history — screen 14 (mobile + web).
///
/// The five-bar chart, averages, and the inspection list. Score is
/// illustrative — the exit code is the verdict. On web the chart sits
/// beside the list.
library;

import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';
import '../widgets/score_bars.dart';

/// The history screen screen.
class HistoryScreen extends StatelessWidget {
  /// Creates a [HistoryScreen].
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    const p = AppTheme.palette;
    final reports = controller.reports;
    final scores = controller.recentScores;
    final average = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
    final best = scores.isEmpty
        ? 0
        : scores.reduce((a, b) => a > b ? a : b);
    final worst = scores.isEmpty
        ? 0
        : scores.reduce((a, b) => a < b ? a : b);
    final bestReport = reports.isEmpty
        ? null
        : reports.reduce((a, b) => a.score >= b.score ? a : b);
    return FpScaffold(
      title: 'History',
      showBack: true,
      actions: const [Center(child: Tag('Score / 100'))],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Getting cleaner,\none export at a time.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Kicker('Last 5 inspections'),
                        Text(
                          scores.isEmpty
                              ? 'No data yet'
                              : average >= 85
                                  ? 'Trend up'
                                  : 'Trend flat',
                          style: AppTheme.mono(size: 12, color: p.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ScoreBars(scores: scores, height: 84),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatTile(
                          label: 'Average',
                          value: average.toStringAsFixed(1),
                          caption: 'last 5 runs',
                        ),
                        StatTile(
                          label: 'Best',
                          value: '$best',
                          caption: bestReport?.exportName ?? '—',
                          valueColor: p.green,
                        ),
                        StatTile(
                          label: 'Worst',
                          value: '$worst',
                          caption: reports.isEmpty
                              ? '—'
                              : reports.first.exportName,
                          valueColor: p.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              right: GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Inspections'),
                    const SizedBox(height: 6),
                    if (reports.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No inspections yet.'),
                      ),
                    for (final report in reports.take(8))
                      _historyRow(context, report),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Score is illustrative — the exit code is the verdict.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyRow(BuildContext context, Report report) {
    const p = AppTheme.palette;
    final open = report.openDefects.length;
    final meta = report.isClean
        ? 'Clean'
        : open == 0
            ? '${report.waivedDefects.length} waived'
            : '$open defect${open == 1 ? '' : 's'}'
                '${report.waivedDefects.isEmpty ? '' : ' · ${report.waivedDefects.length} waived'}';
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/report',
        arguments: {'reportId': report.id},
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.exportName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 14),
                  ),
                  Text(
                    '${formatRelative(report.createdAt)} · $meta',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${report.score}',
                  style: AppTheme.mono(size: 19, color: p.ink),
                ),
                Text(
                  'Exit ${report.exitCode}',
                  style: AppTheme.mono(
                    size: 11,
                    color: report.isClean ? p.green : p.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
