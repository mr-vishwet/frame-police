/// PR comment — screen 16 (mobile + web).
///
/// The comment CI left: the bot's failed check, the defects, the
/// suggestions, and the merge block. On web the comment sits beside
/// the merge status.
library;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';
import '../widgets/logo.dart';

class PrCommentScreen extends StatelessWidget {
  const PrCommentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final ciRunId = args?['ciRunId'] as String?;
    final run = ciRunId == null
        ? (controller.ciRuns.isEmpty ? null : controller.ciRuns.first)
        : controller.ciRunById(ciRunId);
    final p = AppTheme.palette;
    if (run == null) {
      return const FpScaffold(
        title: 'PR',
        showBack: true,
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'No CI runs yet',
            body: 'Connect the Action to see runs here.',
          ),
        ),
      );
    }
    // The report behind this run, when it exists locally.
    Report? report;
    for (final r in controller.reports) {
      if (r.exportName == run.exportName) report = r;
    }
    // Final local: `report` is mutable, so its null check does not
    // promote inside the button closure below — capture the id first.
    final reportId = report?.id;
    final defects = report?.defects ?? _demoDefects(run);
    final suggestions = report?.suggestions ?? _demoSuggestions(run);
    final score = report?.score ?? 82;
    return FpScaffold(
      title: 'PR #${run.prNumber}',
      showBack: true,
      actions: [
        Center(
          child: Tag(
            run.passed ? 'Check passed' : 'Check failed',
            color: run.passed ? p.green : p.red,
          ),
        ),
      ],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Run #${run.number} · frame-police.yml',
              style: AppTheme.mono(size: 12, color: p.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              'The comment\nCI left.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const FpAppIcon(size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'frame-police · bot',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontSize: 15),
                              ),
                              Text(
                                'Commented just now',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Tag(
                          run.passed ? 'Passed' : 'Failed',
                          color: run.passed ? p.green : p.red,
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Text(
                      run.passed
                          ? 'Inspection passed — exit code 0'
                          : 'Inspection failed — exit code 1',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${run.exportName} · registry ${run.registryVersion} · '
                      '${defects.length} defects, ${suggestions.length} suggestions, '
                      'score $score/100.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 13),
                    ),
                    if (defects.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Kicker('Defects'),
                      const SizedBox(height: 6),
                      for (final defect in defects)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            '${defect.ruleCode} · ${defect.timecode}\n'
                            '${defect.measuredLabel} vs ${defect.limitLabel}',
                            style: AppTheme.mono(size: 13, color: p.red),
                          ),
                        ),
                    ],
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Kicker('Suggestions (not blocking)'),
                      const SizedBox(height: 6),
                      Text(
                        suggestions.map((s) => s.title).join(' · '),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                run.passed ? 'Merge unblocked' : 'Merge blocked',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                run.passed
                                    ? 'The check passed — the branch may merge.'
                                    : 'The branch rule requires this check to pass.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Tag(
                          run.passed ? 'Ready' : 'Blocked',
                          color: run.passed ? p.green : p.red,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FpGhostButton(
                          label: 'View full report',
                          onPressed: reportId == null
                              ? null
                              : () => Navigator.pushNamed(
                                    context,
                                    '/report',
                                    arguments: {'reportId': reportId},
                                  ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FpGhostButton(
                          label: 'Re-run checks',
                          onPressed: () {
                            final export = controller.exportById(
                              report?.exportId ?? '',
                            );
                            if (export == null) {
                              showFpSnack(
                                context,
                                'That export is not on this device.',
                              );
                              return;
                            }
                            Navigator.pushNamed(
                              context,
                              '/inspecting',
                              arguments: {'exportId': export.id},
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      run.passed
                          ? 'The check passed on re-inspection — ship it.'
                          : 'Fix the defects, re-export, push again —\n'
                              'the check re-runs itself.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Demo defects for seeded CI runs whose report is not stored locally.
  List<Finding> _demoDefects(CiRun run) {
    if (run.passed) return const [];
    return [
      Finding(
        id: kRuleSubtitleSafeArea,
        ruleCode: kRuleSubtitleSafeArea,
        ruleVersion: 'v1.2',
        title: 'Subtitle sits below the safe area.',
        kind: FindingKind.defect,
        timecode: DemoFixture.subtitleTimecode,
        measuredLabel: '1,066 px',
        measuredValue: DemoFixture.subtitleBottomY,
        limitLabel: '≤ 1,052 px',
        limitValue: DemoFixture.subtitleLimitY,
        detail: 'Subtitle bottom edge below the safe-area line.',
      ),
      Finding(
        id: kRuleAudioPeak,
        ruleCode: kRuleAudioPeak,
        ruleVersion: 'v2.0',
        title: 'One peak, 0.2 dB over the limit.',
        kind: FindingKind.defect,
        timecode: DemoFixture.peakTimecode,
        measuredLabel: '−0.8 dBFS',
        measuredValue: DemoFixture.peakDbfs,
        limitLabel: '−1.0 dBFS limit',
        limitValue: DemoFixture.peakLimitDbfs,
        detail: 'A single peak over the ceiling.',
      ),
    ];
  }

  List<Finding> _demoSuggestions(CiRun run) {
    if (run.passed) return const [];
    return [
      const Finding(
        id: kRuleLoudness,
        ruleCode: kRuleLoudness,
        ruleVersion: 'v1.0',
        title: 'Loudness −13.2 LUFS vs −14.0 target',
        kind: FindingKind.suggestion,
        timecode: '00:00:00:00',
        measuredLabel: '−13.2 LUFS',
        measuredValue: -13.2,
        limitLabel: '−14.0 LUFS target',
        limitValue: -14.0,
        detail: 'Loudness is 0.8 LUFS hot.',
      ),
      const Finding(
        id: kRuleOpeningFrame,
        ruleCode: kRuleOpeningFrame,
        ruleVersion: 'v1.0',
        title: 'Opening frame 62% dark',
        kind: FindingKind.suggestion,
        timecode: '00:00:00:00',
        measuredLabel: '62% dark',
        measuredValue: 0.62,
        limitLabel: '< 50% dark',
        limitValue: 0.5,
        detail: 'The opening frame is the thumbnail on most players.',
      ),
      const Finding(
        id: kRuleCaptionsFile,
        ruleCode: kRuleCaptionsFile,
        ruleVersion: 'v1.0',
        title: 'No .srt attached',
        kind: FindingKind.suggestion,
        timecode: '00:00:00:00',
        measuredLabel: 'No .srt found',
        measuredValue: 0,
        limitLabel: '.srt attached',
        limitValue: 1,
        detail: 'No captions file alongside the export.',
      ),
    ];
  }
}
