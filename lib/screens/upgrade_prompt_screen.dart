/// Upgrade prompt — screen 26 (mobile + web).
///
/// CI integration needs an account. The PR it would unblock stays
/// visible; signing in adds CI, the team registry, and shared waivers.
/// On web the two panels sit side by side.
library;

import 'package:material_ui/material_ui.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The upgrade prompt screen screen.
class UpgradePromptScreen extends StatelessWidget {
  /// Creates an [UpgradePromptScreen].
  const UpgradePromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final report = controller.currentReport;
    const p = AppTheme.palette;
    return FpScaffold(
      title: 'CI integration',
      showBack: true,
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Kicker('You tapped · Connect GitHub Action'),
            const SizedBox(height: 6),
            Text(
              'CI integration\nneeds an account.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Running Frame Police on every pull request is the one '
              'thing guest mode can’t do — CI needs a registry to pull from.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: GlassCard(
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
                              const Kicker('Waiting on CI · PR #142'),
                              const SizedBox(height: 2),
                              Text(
                                report?.exportName ??
                                    'Launch Teaser — v3.mp4',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '00:47 · 1080×1920 · score ${report?.score ?? 82}',
                                style: AppTheme.mono(
                                  size: 12,
                                  color: p.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ExitBadge(report?.exitCode ?? 1),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The local verdict is exit ${report?.exitCode ?? 1} — '
                      '${report?.defects.length ?? 2} defects. Connect CI '
                      'and the check fails the PR automatically, with the '
                      'report posted as a comment.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              right: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Signing in adds'),
                    const SizedBox(height: 8),
                    _addsRow(
                      context,
                      'CI integration',
                      'The GitHub Action frame-police.yml on every pull request that touches an export.',
                    ),
                    const SizedBox(height: 8),
                    _addsRow(
                      context,
                      'Team registry',
                      'Registry v2.4.1 shared with the team; same rules, same exit code, everywhere.',
                    ),
                    const SizedBox(height: 8),
                    _addsRow(
                      context,
                      'Shared waivers',
                      'Waive with a reason once; the whole team sees it, on record.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FpPrimaryButton(
              label: 'Sign in to connect CI',
              onPressed: () => Navigator.pushNamed(context, '/sign-in'),
            ),
            const SizedBox(height: 8),
            FpGhostButton(
              label: 'Keep inspecting locally',
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Build Specification · concept UI · no account required',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addsRow(BuildContext context, String title, String body) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.6,
            ),
        children: [
          TextSpan(
            text: '$title ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: '— $body'),
        ],
      ),
    );
  }
}
