/// Guest mode, explained — screen 22 (mobile + web).
///
/// No account, no password, nothing uploaded. What works, what stays
/// on-device, and what login adds — only when you want it.
library;

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The guest mode screen screen.
class GuestModeScreen extends StatelessWidget {
  /// Creates a [GuestModeScreen].
  const GuestModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    const p = AppTheme.palette;
    return FpScaffold(
      title: 'Guest mode',
      showBack: true,
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Guest mode,\nexplained.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'No account, no password, nothing uploaded. This is the '
              'whole inspector — not a trial.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 14),
            const GlassCard(
              padding:
                  EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker('What works'),
                  FpRow(
                    icon: Icons.document_scanner_outlined,
                    title: 'Inspect any export',
                    subtitle: 'Drop in a file — get a verdict.',
                  ),
                  Divider(height: 8),
                  FpRow(
                    icon: Icons.article_outlined,
                    title: 'Waivers with reasons',
                    subtitle: 'Waive a finding with a reason; the reason '
                        'stays in the report.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('Your exports stay on this device'),
                  const SizedBox(height: 6),
                  Text(
                    '${controller.reports.length} reports · '
                    '${controller.waiversCount} waiver${controller.waiversCount == 1 ? '' : 's'} · '
                    'exit ${controller.currentReport?.exitCode ?? 0}, on record',
                    style: AppTheme.mono(size: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker(
                    'What login adds — only when you want it',
                  ),
                  const SizedBox(height: 8),
                  _addsRow(
                    context,
                    'Team registry',
                    'One rule set for the whole team, versioned and pinned per report.',
                  ),
                  const SizedBox(height: 8),
                  _addsRow(
                    context,
                    'CI integration',
                    'The GitHub Action on every pull request; exit 1 fails the check.',
                  ),
                  const SizedBox(height: 8),
                  _addsRow(
                    context,
                    'Shared waivers',
                    'A waiver your whole team can see, with its reason attached.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FpPrimaryButton(
              label: 'Keep going as guest',
              onPressed: () async {
                await controller.continueAsGuest();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 8),
            FpGhostButton(
              label: 'Sign in instead',
              onPressed: () => Navigator.pushNamed(context, '/sign-in'),
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
