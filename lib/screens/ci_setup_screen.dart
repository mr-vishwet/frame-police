/// CI setup — screen 17 (mobile + web).
///
/// The workflow file, eleven lines, no wizard — with how it behaves
/// beside it. Copy the workflow, or connect the Action (account
/// required — guests get the upgrade prompt).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/reporter.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

class CiSetupScreen extends StatelessWidget {
  const CiSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = AppTheme.palette;
    final connected = controller.settings.ciConnected;
    return FpScaffold(
      title: 'CI setup',
      showBack: true,
      actions: [Center(child: Tag('GitHub Action'))],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Kicker('Two minutes, once'),
            const SizedBox(height: 6),
            Text(
              'Put the inspector\nin the pipeline.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '.github/workflows/frame-police.yml',
                            style: AppTheme.mono(size: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _copy(context),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    SelectableText(
                      kCiWorkflowYaml,
                      style: AppTheme.mono(
                        size: 12,
                        color: p.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Kicker('How it behaves'),
                        const SizedBox(height: 8),
                        Text(
                          '1  Runs on every PR that touches an export.\n'
                          '2  Posts the report as a PR comment.\n'
                          '3  Exit 1 fails the check; exit 0 passes it.\n'
                          '4  Registry version is pinned — no surprise '
                          'rule changes.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(height: 1.8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: FpRow(
                      icon: Icons.cloud_sync_outlined,
                      title: 'GitHub Action',
                      subtitle: connected
                          ? 'frame-police.yml · connected'
                          : 'frame-police.yml · not connected',
                      trailing: Tag(
                        connected ? 'Connected' : 'Not connected',
                        color: connected ? p.green : p.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FpPrimaryButton(
                    label: 'Copy workflow',
                    icon: Icons.copy,
                    onPressed: () => _copy(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FpGhostButton(
                    label: connected ? 'Disconnect' : 'Connect Action',
                    onPressed: () => _connect(context, controller),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Proposed integration · the Action spec is part of this '
                'Build Specification.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: kCiWorkflowYaml),
    );
    if (!context.mounted) return;
    showFpSnack(context, 'Workflow copied — add it as .github/workflows/frame-police.yml.');
  }

  Future<void> _connect(
    BuildContext context,
    AppController controller,
  ) async {
    if (controller.settings.ciConnected) {
      await controller.setCiConnected(false);
      if (!context.mounted) return;
      showFpSnack(context, 'GitHub Action disconnected. Reports stay yours.');
      return;
    }
    if (controller.isGuest) {
      // CI integration needs an account.
      Navigator.pushNamed(context, '/upgrade');
      return;
    }
    await controller.setCiConnected(true);
    if (!context.mounted) return;
    showFpSnack(
      context,
      'Action connected — registry $kRegistryVersion pinned.',
    );
  }
}
