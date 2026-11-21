/// Welcome — screen 21 (mobile + web).
///
/// Inspect anything, no account needed. Guest-first: the whole
/// inspector works without signing in. On web the panel sits inside
/// the desktop shell.
library;

import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';
import '../widgets/logo.dart';

/// The welcome screen screen.
class WelcomeScreen extends StatelessWidget {
  /// Creates a [WelcomeScreen].
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.read(context);
    const p = AppTheme.palette;
    return FpScaffold(
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Column(
              children: [
                const FpBadge(size: 80),
                const SizedBox(height: 10),
                Text(
                  'FRAME POLICE',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Registry $kRegistryVersion · $kRuleCount rules',
                  style: AppTheme.mono(size: 12, color: p.muted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Inspect anything.\nNo account needed.',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Frame Police works fully as a guest. Your exports and '
              'reports stay on this device until you choose otherwise.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FpPrimaryButton(
              label: 'Continue as guest',
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
              label: 'Sign in',
              onPressed: () => Navigator.pushNamed(context, '/sign-in'),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/create-account'),
                child: const Text('New here? Create an account'),
              ),
            ),
            const SizedBox(height: 8),
            const GlassCard(
              padding:
                  EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker('As a guest, you get'),
                  FpRow(
                    icon: Icons.document_scanner_outlined,
                    title: 'The full inspector',
                    subtitle: 'All 14 rules — 11 defect checks that decide '
                        'the exit code, 3 suggestions.',
                  ),
                  Divider(height: 8),
                  FpRow(
                    icon: Icons.article_outlined,
                    title: 'Reports, waivers and history',
                    subtitle: 'Every verdict on-device, with its evidence.',
                  ),
                  Divider(height: 8),
                  FpRow(
                    icon: Icons.refresh_outlined,
                    title: 'Deterministic, every time',
                    subtitle: 'Same input, same report. The exit code never '
                        'lies to you.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Sign in later, any time. Migrating loses nothing —\n'
                'we move every report, rule, and waiver.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
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
}
