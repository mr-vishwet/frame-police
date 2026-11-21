/// Export report — screen 18 (mobile + web).
///
/// The report in your format — HTML, JSON, Markdown, TTY. Every format
/// carries the same findings, evidence, registry version, and waiver
/// with its reason. On web the formats sit beside the inclusions list.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../engine/reporter.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  ReportFormat _format = ReportFormat.html;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final reportId = args?['reportId'] as String?;
    final report = reportId == null
        ? controller.currentReport
        : controller.reportById(reportId) ?? controller.currentReport;
    final p = AppTheme.palette;
    if (report == null) {
      return const FpScaffold(
        title: 'Export',
        showBack: true,
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.share_outlined,
            title: 'No report to export',
            body: 'Inspect an export first.',
          ),
        ),
      );
    }
    final preview = Reporter.render(report, _format);
    return FpScaffold(
      title: 'Export',
      showBack: true,
      actions: [Center(child: ExitBadge(report.exitCode))],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Kicker(report.exportName),
            const SizedBox(height: 6),
            Text(
              'The report,\nin your format.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Every format carries the same findings, the same evidence, '
              'the registry version, and the waiver with its reason.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 8),
                child: Column(
                  children: [
                    for (final format in ReportFormat.values)
                      _formatRow(context, report, format),
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
                        const Kicker('Included in every export'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Tag('Registry ${report.registryVersion}'),
                            Tag(
                              'Exit code ${report.exitCode}',
                              color: report.isClean ? p.green : p.red,
                            ),
                            Tag(
                              '${report.defects.length} defects + evidence',
                            ),
                            if (report.waivedDefects.isNotEmpty)
                              Tag(
                                '${report.waivedDefects.length} waiver${report.waivedDefects.length == 1 ? '' : 's'} + reason',
                              ),
                            Tag(
                              '${report.suggestions.length} suggestions',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Kicker('Preview'),
                            TextButton.icon(
                              onPressed: () => _copy(context, preview),
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preview.length > 600
                              ? '${preview.substring(0, 600)}…'
                              : preview,
                          style: AppTheme.mono(size: 11, color: p.faint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FpPrimaryButton(
              label: _saving ? 'Saving…' : 'Export as ${_format.label}',
              icon: Icons.download_outlined,
              onPressed: _saving
                  ? null
                  : () => _save(context, controller, report),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'The report is the record — nothing in it can be edited '
                'after the run.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formatRow(
    BuildContext context,
    Report report,
    ReportFormat format,
  ) {
    final p = AppTheme.palette;
    final icon = switch (format) {
      ReportFormat.html => Icons.language_outlined,
      ReportFormat.json => Icons.data_object_outlined,
      ReportFormat.markdown => Icons.article_outlined,
      ReportFormat.tty => Icons.terminal_outlined,
    };
    final selected = _format == format;
    final size = Reporter.render(report, format).length;
    return InkWell(
      onTap: () => setState(() => _format = format),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? p.amber.withValues(alpha: 0.25)
                    : p.glass,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? p.amber : p.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 15),
                  ),
                  Text(
                    format.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              size >= 1000
                  ? '${(size / 1000).toStringAsFixed(1)} KB'
                  : '$size B',
              style: AppTheme.mono(size: 12, color: p.muted),
            ),
            const SizedBox(width: 8),
            Radio<ReportFormat>(
              value: format,
              groupValue: _format,
              onChanged: (_) => setState(() => _format = format),
              activeColor: p.amber,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    showFpSnack(context, 'Report copied to clipboard.');
  }

  Future<void> _save(
    BuildContext context,
    AppController controller,
    Report report,
  ) async {
    setState(() => _saving = true);
    final path = await controller.exporter.saveReport(report, _format);
    if (!context.mounted) return;
    setState(() => _saving = false);
    showFpSnack(
      context,
      path == null
          ? 'Export cancelled.'
          : 'Report saved as ${_format.label}.',
    );
  }
}
