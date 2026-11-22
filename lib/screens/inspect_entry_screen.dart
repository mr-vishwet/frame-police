/// Inspect entry — screen 02 (mobile + web).
///
/// Pick an export: recent files with the selected one highlighted, the
/// known-bad demo reel, and Browse for a new file. On web the selected
/// export's detail sits beside the list.
library;

import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The inspect entry screen screen.
class InspectEntryScreen extends StatefulWidget {
  /// Creates an [InspectEntryScreen].
  const InspectEntryScreen({super.key});

  @override
  State<InspectEntryScreen> createState() => _InspectEntryScreenState();
}

class _InspectEntryScreenState extends State<InspectEntryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    const p = AppTheme.palette;
    final query = _query.toLowerCase();
    final visible = controller.exports
        .where((e) => e.name.toLowerCase().contains(query))
        .toList();
    final selected = controller.selectedExport;
    return FpScaffold(
      tabIndex: 1,
      title: 'Inspect',
      actions: const [Center(child: Tag(kRegistryVersion))],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pick an export',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Checks run on-device. Nothing uploads.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 14),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search exports',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            AdaptiveColumns(
              left: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: RadioGroup<String>(
                  groupValue: selected?.id,
                  onChanged: (id) {
                    for (final export in visible) {
                      if (export.id == id) {
                        controller.selectExport(export);
                        break;
                      }
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Kicker('Recent exports'),
                      const SizedBox(height: 6),
                      if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No exports match that search.'),
                        ),
                      for (final export in visible)
                        _fileRow(context, controller, export),
                    ],
                  ),
                ),
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (selected != null) _detailCard(context, selected),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: FpRow(
                      icon: Icons.folder_open_outlined,
                      title: 'Browse all files',
                      subtitle: 'Files · Photos · iCloud Drive',
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => _browse(context, controller),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FpPrimaryButton(
              label: 'Continue',
              onPressed: selected == null
                  ? null
                  : () => Navigator.pushNamed(
                        context,
                        '/pre-inspection',
                        arguments: {'exportId': selected.id},
                      ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                selected == null
                    ? 'No file selected'
                    : '1 file selected · ${controller.rules.where((r) => r.enabled).length} checks queued',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileRow(
    BuildContext context,
    AppController controller,
    ExportFile export,
  ) {
    const p = AppTheme.palette;
    final isKnownBad = export.id == 'exp_known_bad';
    return InkWell(
      onTap: () => controller.selectExport(export),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: p.hairline),
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: export.id,
              activeColor: p.amber,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          export.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: 15),
                        ),
                      ),
                      if (isKnownBad) ...[
                        const SizedBox(width: 6),
                        Tag('Try it', color: p.orange, filled: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isKnownBad
                        ? '${formatDuration(export.durationSeconds)} · '
                            '${export.width}×${export.height} · '
                            '5 defects waiting'
                        : '${formatDuration(export.durationSeconds)} · '
                            '${export.width}×${export.height} · '
                            '${formatBytes(export.sizeBytes)} · '
                            '${formatRelative(export.addedAt)}',
                    style: AppTheme.mono(size: 11, color: p.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(BuildContext context, ExportFile export) {
    const p = AppTheme.palette;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Kicker('Selected export'),
          const SizedBox(height: 8),
          Text(
            export.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${formatDuration(export.durationSeconds)} · '
            '${formatInt(export.frameCount)} frames · '
            '${export.width}×${export.height} · ${export.aspectLabel} · '
            '${export.fps} fps · ${formatBytes(export.sizeBytes)}',
            style: AppTheme.mono(size: 12, color: p.muted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Tag('Registry $kRegistryVersion'),
              const SizedBox(width: 8),
              Tag(export.probe.isDemoProbe ? 'DEMO probe' : 'Measured probe',
                  color: export.probe.isDemoProbe ? p.muted : p.green),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _browse(
    BuildContext context,
    AppController controller,
  ) async {
    ExportFile? picked;
    try {
      picked = await controller.pickExportFile();
    } on Object catch (_) {
      // Persisting the picked export failed: the file was picked but
      // could not be saved, so say so instead of going silent.
      if (!context.mounted) return;
      showFpSnack(context, 'Could not save the picked export.');
      return;
    }
    if (!context.mounted) return;
    if (picked == null) {
      if (controller.pickerError != null) {
        showFpSnack(context, 'Could not open the file picker.');
      }
      return;
    }
    showFpSnack(
      context,
      '${picked.name} added — demo probe, labelled in the report.',
    );
  }
}
