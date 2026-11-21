/// Account home — screen 28 (mobile + web).
///
/// The signed-in account: synced counts, registry, CI runs, devices.
/// Guests are routed to Welcome instead.
library;

import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The account screen screen.
class AccountScreen extends StatelessWidget {
  /// Creates an [AccountScreen].
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final account = controller.account;
    const p = AppTheme.palette;
    if (account == null) {
      return FpScaffold(
        title: 'Account',
        showBack: true,
        body: FpScrollBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FpEmptyState(
                icon: Icons.person_outline,
                title: 'You are browsing as a guest',
                body: 'Sign in to see your account, team registry, and '
                    'synced reports.',
              ),
              const SizedBox(height: 14),
              FpPrimaryButton(
                label: 'Sign in',
                onPressed: () =>
                    Navigator.pushNamed(context, '/sign-in'),
              ),
              const SizedBox(height: 8),
              FpGhostButton(
                label: 'Guest mode, explained',
                onPressed: () => Navigator.pushNamed(context, '/guest'),
              ),
            ],
          ),
        ),
      );
    }
    return FpScaffold(
      title: 'Account',
      showBack: true,
      actions: [Center(child: Tag('Signed in', color: p.green))],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: p.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: p.orange.withValues(alpha: 0.5),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      account.initial,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style:
                            Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        account.email,
                        style: AppTheme.mono(size: 13, color: p.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Tag('${account.plan} plan · team registry on', filled: true),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Synced · this account'),
                    const SizedBox(height: 10),
                    AdaptiveGrid(
                      narrowColumns: 2,
                      wideColumns: 2,
                      children: [
                        StatTile(
                          label: 'Reports',
                          value: '${controller.reports.length}',
                          caption: 'all verdicts',
                        ),
                        StatTile(
                          label: 'Defects caught',
                          value: '${controller.defectsCaught}',
                          caption: 'before upload',
                        ),
                        StatTile(
                          label: 'Zero-defect',
                          value: '${controller.zeroDefectExports}',
                          caption: 'clean runs',
                          valueColor: p.green,
                        ),
                        StatTile(
                          label: 'Waivers',
                          value: '${controller.waiversCount}',
                          caption: 'with reason',
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
                  children: [
                    FpRow(
                      title: 'Registry',
                      subtitle: 'The versioned rule set',
                      trailing: Text(
                        '$kRegistryVersion · ${controller.rules.length} rules · pinned',
                        style: AppTheme.mono(size: 12),
                      ),
                      onTap: () =>
                          Navigator.pushNamed(context, '/registry'),
                    ),
                    const Divider(height: 8),
                    FpRow(
                      title: 'CI runs',
                      subtitle:
                          '${controller.ciTotals[0]} all time · ${controller.ciTotals[1]} failed',
                      trailing: Text(
                        '${controller.ciTotals[0]}',
                        style: AppTheme.mono(size: 13),
                      ),
                      onTap: () => Navigator.pushNamed(context, '/ci'),
                    ),
                    const Divider(height: 8),
                    const FpRow(
                      title: 'This device',
                      subtitle: 'Synced · reports on device',
                      trailing: Tag('This device'),
                    ),
                    const Divider(height: 8),
                    FpRow(
                      title: 'Connected accounts',
                      subtitle: 'GitHub · registry',
                      trailing: Text(
                        'Manage',
                        style: AppTheme.mono(size: 13),
                      ),
                      onTap: () =>
                          Navigator.pushNamed(context, '/connected'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FpGhostButton(
              label: 'Sign out',
              icon: Icons.logout_outlined,
              onPressed: () => _signOut(context, controller),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/data'),
                child: const Text('Data controls'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(
    BuildContext context,
    AppController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Signing out keeps your local copy on this device — reports '
          'untouched. You go back to guest mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await controller.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    showFpSnack(context, 'Signed out. Local reports stay on this device.');
  }
}
