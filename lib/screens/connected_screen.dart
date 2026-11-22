/// Connected accounts — screen 29 (mobile + web).
///
/// CI, the team registry, waivers on record, and devices. Everything is
/// local to this device — there is no cloud sync yet, so there is
/// nothing to disconnect.
library;

import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The connected screen screen.
class ConnectedScreen extends StatelessWidget {
  /// Creates a [ConnectedScreen].
  const ConnectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final settings = controller.settings;
    const p = AppTheme.palette;
    return FpScaffold(
      title: 'Connected',
      showBack: true,
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Where the inspector\nplugs in.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'CI, the team registry, and devices, all in one place. '
              'Everything here is local to this device — there is no '
              'cloud sync yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('CI and registry'),
                    FpRow(
                      title: 'GitHub Action',
                      subtitle:
                          'frame-police.yml · ${controller.ciTotals[0]} runs',
                      trailing: Tag(
                        settings.ciConnected
                            ? 'Connected'
                            : 'Not connected',
                        color: settings.ciConnected ? p.green : p.muted,
                      ),
                      onTap: () =>
                          Navigator.pushNamed(context, '/ci-setup'),
                    ),
                    const Divider(height: 8),
                    FpRow(
                      title: 'Team registry',
                      subtitle:
                          '$kRegistryVersion · ${controller.rules.length} rules · pinned',
                      trailing: Tag(
                        controller.isGuest ? 'Guest' : 'Local',
                        color: controller.isGuest ? p.muted : p.green,
                      ),
                      onTap: () =>
                          Navigator.pushNamed(context, '/registry'),
                    ),
                    const Divider(height: 8),
                    FpRow(
                      title: 'PR comments',
                      subtitle: 'Coming soon — needs the published Action',
                      trailing: Tag(
                        'Coming soon',
                        color: p.muted,
                      ),
                    ),
                    const Divider(height: 8),
                    FpRow(
                      title: 'Waivers on record',
                      subtitle:
                          '${controller.waiversCount} waiver${controller.waiversCount == 1 ? '' : 's'} '
                          'on this device — reason attached, never deleted',
                      trailing: Text(
                        '${controller.waiversCount} waiver${controller.waiversCount == 1 ? '' : 's'}',
                        style: AppTheme.mono(size: 13),
                      ),
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
                    const Kicker('Devices on this account'),
                    FpRow(
                      title: 'This device',
                      subtitle:
                          '${controller.reports.length} reports on this device',
                      trailing: const Tag('This device'),
                    ),
                    const Divider(height: 8),
                    Text(
                      'No other devices linked. Data stays on this '
                      'device — there is no cloud sync yet, so nothing '
                      'to link.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (controller.isGuest) ...[
                      const Divider(height: 8),
                      Text(
                        'You are browsing as a guest. Signing in attaches '
                        'a name to this device’s data — it does not sync '
                        'it anywhere yet.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
