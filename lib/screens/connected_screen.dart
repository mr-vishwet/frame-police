/// Connected accounts — screen 29 (mobile + web).
///
/// CI, the team registry, shared waivers, and devices. Disconnect any
/// of them — reports stay yours.
library;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

class ConnectedScreen extends StatelessWidget {
  const ConnectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final settings = controller.settings;
    final p = AppTheme.palette;
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
              'Disconnect any of them — your reports stay yours.',
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
                        controller.isGuest ? 'Guest' : 'Synced',
                        color: controller.isGuest ? p.muted : p.green,
                      ),
                      onTap: () =>
                          Navigator.pushNamed(context, '/registry'),
                    ),
                    const Divider(height: 8),
                    FpToggleRow(
                      title: 'PR comments',
                      subtitle: 'Post the report on every run — defects '
                          'only, by default',
                      value: settings.prComments,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(prComments: value),
                      ),
                    ),
                    const Divider(height: 8),
                    FpRow(
                      title: 'Shared waivers',
                      subtitle:
                          '${controller.waiversCount} waiver${controller.waiversCount == 1 ? '' : 's'} '
                          'on record — reason attached, never deleted',
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
                          'Synced just now · ${controller.reports.length} reports',
                      trailing: const Tag('This device'),
                    ),
                    const Divider(height: 8),
                    FpRow(
                      title: 'Desktop web',
                      subtitle:
                          'Synced · same registry, same verdicts',
                      trailing: TextButton(
                        onPressed: () => showFpSnack(
                          context,
                          'Desktop web removed. Its local reports stay '
                          'on that device.',
                        ),
                        child: Text(
                          'Remove',
                          style: TextStyle(color: p.red),
                        ),
                      ),
                    ),
                    if (controller.isGuest) ...[
                      const Divider(height: 8),
                      Text(
                        'Devices sync with an account. You are browsing '
                        'as a guest — sign in to link devices.',
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
