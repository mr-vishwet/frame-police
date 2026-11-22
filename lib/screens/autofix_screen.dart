/// Fix guidance — screen 08 (mobile + web).
///
/// "Fix it in your editor." Frame Police cannot edit media, so there is
/// no in-app fix to apply: this screen shows the exact change each
/// defect needs — the measured value, the limit, and what to do in the
/// editor — and says plainly that the finding stays open until the user
/// re-exports and re-inspects a new file.
///
/// Takes an optional `findingId`: with one, it shows that finding's
/// guidance; without one, it shows guidance for every open defect on
/// the report.
library;

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../engine/autofix.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The autofix screen screen.
class AutofixScreen extends StatelessWidget {
  /// Creates an [AutofixScreen].
  const AutofixScreen({super.key});

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
    if (report == null) {
      return const FpScaffold(
        title: 'Fix guidance',
        showBack: true,
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.build_outlined,
            title: 'No guidance to show',
            body: 'Open a defect to see how to fix it.',
          ),
        ),
      );
    }
    final targets = _targets(report, findingId);
    if (targets.isEmpty) {
      return FpScaffold(
        title: 'Fix guidance',
        showBack: true,
        body: FpScrollBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FpEmptyState(
                icon: Icons.check_circle_outline,
                title: 'Nothing open',
                body: 'Every defect on this report is waived or confirmed.',
              ),
              const SizedBox(height: 12),
              FpGhostButton(
                label: 'Back to report',
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/report',
                  arguments: {'reportId': report.id},
                ),
              ),
            ],
          ),
        ),
      );
    }
    return FpScaffold(
      title: 'Fix guidance',
      showBack: true,
      actions: [
        Center(
          child: Tag(
            '${targets.length} to fix',
            color: p.orange,
          ),
        ),
      ],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [p.orange, p.amber],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: p.orange.withValues(alpha: 0.5),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.build_outlined,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Fix it in your editor.',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Frame Police cannot edit your video — the fix happens '
                  'in your editor, with the exact numbers below. Each '
                  'finding stays open until you re-export and re-inspect '
                  'a new file.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: p.faint),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final finding in targets) ...[
              _guidanceCard(context, finding),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            FpPrimaryButton(
              label: 'Inspect the re-exported file',
              icon: Icons.arrow_forward,
              onPressed: () =>
                  Navigator.pushNamed(context, '/inspect'),
            ),
            const SizedBox(height: 8),
            FpGhostButton(
              label: 'Back to report',
              onPressed: () => Navigator.pushNamed(
                context,
                '/report',
                arguments: {'reportId': report.id},
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'A fix isn’t real until re-inspection confirms it — the '
                'exit code stays 1 until then.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The findings this screen guides: the one asked for, or every open
  /// defect when no finding was named.
  List<Finding> _targets(Report report, String? findingId) {
    if (findingId != null) {
      for (final finding in report.defects) {
        if (finding.id == findingId) return [finding];
      }
    }
    return report.defects
        .where((f) => f.status == FindingStatus.open)
        .toList();
  }

  Widget _guidanceCard(BuildContext context, Finding finding) {
    const p = AppTheme.palette;
    final guidance =
        fixForRule(finding.ruleCode, finding: finding) ?? finding.fix;
    return GlassCard(
      borderColor: p.orange.withValues(alpha: 0.55),
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
              Tag(
                finding.status == FindingStatus.open
                    ? 'Open'
                    : finding.status.name,
                color: finding.status == FindingStatus.open
                    ? p.red
                    : p.muted,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            finding.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            '${finding.timecode} · ${finding.measuredLabel} vs '
            '${finding.limitLabel}',
            style: AppTheme.mono(size: 12, color: p.muted),
          ),
          if (guidance != null) ...[
            const SizedBox(height: 8),
            Text(
              guidance.label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              guidance.detail,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Target: ${guidance.afterLabel}',
              style: AppTheme.mono(size: 12, color: p.green),
            ),
          ],
        ],
      ),
    );
  }
}
