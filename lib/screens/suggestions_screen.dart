/// Suggestions — screen 09 (mobile + web).
///
/// Opinions with evidence, never blocking. The exit code if only
/// suggestions exist is always 0 — by design, not by setting.
library;

import 'package:material_ui/material_ui.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The suggestions screen screen.
class SuggestionsScreen extends StatelessWidget {
  /// Creates a [SuggestionsScreen].
  const SuggestionsScreen({super.key});

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
        title: 'Suggestions',
        showBack: true,
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.lightbulb_outline,
            title: 'No report yet',
            body: 'Inspect an export to see suggestions.',
          ),
        ),
      );
    }
    final suggestions = report.suggestions;
    return FpScaffold(
      title: 'Report',
      showBack: true,
      actions: [
        Center(child: Tag('${suggestions.length} suggestions')),
      ],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Suggestions.\nNever blocking.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Opinions with evidence, not defects. They never touch the '
              'exit code — that is the whole point.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (suggestions.isEmpty)
                    const FpEmptyState(
                      icon: Icons.lightbulb_outline,
                      title: 'No suggestions this run',
                      body: 'Nothing worth an opinion — the export is '
                          'clean on every suggestion rule.',
                    ),
                  for (final suggestion in suggestions) ...[
                    _suggestionCard(context, suggestion),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
              right: GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FpRow(
                      title: 'Suggestions in CI?',
                      subtitle: 'Off by default. When on, they appear as '
                          'PR comments only.',
                      trailing: Switch(
                        value: controller.settings.prComments,
                        onChanged: (value) => controller.updateSettings(
                          controller.settings.copyWith(prComments: value),
                        ),
                      ),
                    ),
                    const Divider(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Exit code if only suggestions',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Always 0 — by design, not by setting',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '0',
                          style: AppTheme.mono(size: 26, color: p.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FpGhostButton(
              label: 'Back to defects',
              onPressed: () => Navigator.pushNamed(
                context,
                '/report',
                arguments: {'reportId': report.id},
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'The moment an opinion blocks CI, the product has lied.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionCard(BuildContext context, Finding suggestion) {
    const p = AppTheme.palette;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                suggestion.ruleCode,
                style: AppTheme.mono(size: 12, color: p.secondary),
              ),
              const Tag('Suggestion'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            suggestion.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            suggestion.detail,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '${suggestion.measuredLabel} vs ${suggestion.limitLabel}',
            style: AppTheme.mono(size: 11, color: p.muted),
          ),
        ],
      ),
    );
  }
}
