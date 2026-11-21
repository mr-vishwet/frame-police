/// Auto-fix applied — screen 08 (mobile + web).
///
/// "Fixed in one tap." The fixed finding's after-state, the fix list,
/// and the two next steps: Re-inspect now, or Decide on the remaining
/// defect. A fix isn't real until re-inspection confirms it.
library;

import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';
import '../widgets/waveform.dart';

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
    final report = reportId == null
        ? controller.currentReport
        : controller.reportById(reportId) ?? controller.currentReport;
    const p = AppTheme.palette;
    if (report == null) {
      return const FpScaffold(
        title: 'Auto-fix',
        showBack: true,
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.build_outlined,
            title: 'No fixes to show',
            body: 'Apply a fix from a report first.',
          ),
        ),
      );
    }
    final fixed = report.fixedAwaiting;
    final open = report.defects
        .where((f) => f.status == FindingStatus.open)
        .toList();
    final firstFixed = fixed.isEmpty ? null : fixed.first;
    return FpScaffold(
      title: 'Auto-fix',
      showBack: true,
      actions: [
        Center(
          child: Tag(
            '${fixed.length} of ${report.defects.length} fixed',
            color: p.green,
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
                      colors: [const Color(0xFF059669), p.green],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: p.green.withValues(alpha: 0.5),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'Fixed in one tap.',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  firstFixed == null
                      ? 'The fixes are applied. Re-inspection will confirm them.'
                      : '${firstFixed.fix?.label ?? 'Fix applied'} — re-inspection will confirm it.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: p.faint),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (firstFixed != null &&
                firstFixed.ruleCode == kRuleAudioPeak) ...[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Kicker('AUD-PEAK-02 · after the fix'),
                        Tag('Fixed', color: p.green),
                      ],
                    ),
                    const SizedBox(height: 10),
                    WaveformView(
                      seed: 7,
                      height: 40,
                      cap: 0.62,
                      color: p.green.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Peak −0.8 dBFS → −1.4 dBFS · limit −1.0 dBFS · now inside',
                        style: AppTheme.mono(size: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            GlassCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 8),
              child: Column(
                children: [
                  for (final finding in report.defects)
                    _fixRow(context, finding),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FpPrimaryButton(
              label: 'Re-inspect now',
              icon: Icons.arrow_forward,
              onPressed: () => Navigator.pushNamed(
                context,
                '/inspecting',
                arguments: {
                  'exportId': report.exportId,
                  'previousReportId': report.id,
                },
              ),
            ),
            const SizedBox(height: 8),
            if (open.isNotEmpty)
              FpGhostButton(
                label: 'Decide on the ${open.length == 1 ? 'remaining defect' : '${open.length} remaining defects'}',
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/defect',
                  arguments: {
                    'reportId': report.id,
                    'findingId': open.first.id,
                  },
                ),
              )
            else
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

  Widget _fixRow(BuildContext context, Finding finding) {
    const p = AppTheme.palette;
    final (icon, color, label, sub) = switch (finding.status) {
      FindingStatus.fixed => (
          Icons.check_circle,
          p.green,
          'Fixed',
          'Applied · awaiting re-inspection',
        ),
      FindingStatus.open => (
          Icons.error_outline,
          p.muted,
          'Open',
          'Still needs a decision — fix it, or waive it',
        ),
      FindingStatus.confirmed => (
          Icons.verified,
          p.green,
          'Confirmed',
          'Re-inspection verified the fix',
        ),
      FindingStatus.waived => (
          Icons.bookmark_added_outlined,
          p.muted,
          'Waived',
          'On record, with its reason',
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${finding.ruleCode} · ${finding.title}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 14),
                ),
                Text(sub, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(label, style: AppTheme.mono(size: 12, color: color)),
        ],
      ),
    );
  }
}
