/// Pre-inspection — screen 03 (mobile + web).
///
/// The file's facts, the pinned registry, and the checks queued.
/// One Continue: Run inspection.
library;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

class PreInspectionScreen extends StatelessWidget {
  const PreInspectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final exportId = args?['exportId'] as String?;
    final export = exportId == null
        ? controller.selectedExport
        : controller.exportById(exportId) ?? controller.selectedExport;
    final p = AppTheme.palette;
    if (export == null) {
      return const FpScaffold(
        title: 'Inspect',
        showBack: true,
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.folder_off_outlined,
            title: 'No export selected',
            body: 'Pick an export first.',
          ),
        ),
      );
    }
    final defectRules = controller.rules
        .where((r) => r.enabled && r.isDefect)
        .length;
    final suggestionRules = controller.rules
        .where((r) =>
            r.enabled &&
            !r.isDefect &&
            controller.settings.suggestionsEnabled)
        .length;
    return FpScaffold(
      title: 'Inspect',
      showBack: true,
      actions: [Center(child: Tag(kRegistryVersion))],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Kicker('Ready to inspect'),
            const SizedBox(height: 6),
            Text(
              export.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: GlassCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatTile(
                          label: 'Duration',
                          value: formatDuration(export.durationSeconds),
                          caption:
                              '${formatInt(export.frameCount)} frames',
                        ),
                        StatTile(
                          label: 'Format',
                          value: export.aspectLabel,
                          caption: '${export.width}×${export.height}',
                        ),
                        StatTile(
                          label: 'Size',
                          value: formatBytes(export.sizeBytes),
                          caption: '${export.fps} fps',
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RULE REGISTRY',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$kRegistryVersion · ${controller.rules.length} rules',
                              style: AppTheme.mono(size: 14),
                            ),
                          ],
                        ),
                        const Tag('Pinned', filled: true),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The version is recorded in the report.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              right: GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Checks to run'),
                    const SizedBox(height: 8),
                    FpRow(
                      title: 'Defect checks',
                      subtitle:
                          'Subtitles, safe area, aspect, audio, black frames, brand',
                      trailing: Text(
                        '$defectRules',
                        style: AppTheme.mono(size: 17),
                      ),
                    ),
                    const Divider(height: 8),
                    FpRow(
                      title: 'Suggestions',
                      subtitle: 'Opt-in. Never affect the exit code.',
                      trailing: Text(
                        '$suggestionRules',
                        style: AppTheme.mono(size: 17),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Defects block the release. Suggestions live in a separate '
              'universe — CI only reads the exit code.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 14),
            FpPrimaryButton(
              label: 'Run inspection',
              icon: Icons.play_arrow,
              onPressed: () => Navigator.pushNamed(
                context,
                '/inspecting',
                arguments: {'exportId': export.id},
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'About 20 seconds · frame, audio and text probes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
