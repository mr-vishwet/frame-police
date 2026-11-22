/// Waiver sheet — screen 10 (mobile + web).
///
/// A waiver needs a reason (minimum 20 characters), and the reason
/// stays in the report. Waiving never deletes the finding. On web the
/// defect sits beside the reason field.
library;

import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

const List<String> _waiverTags = [
  'Client approved',
  'Platform exception',
  'False positive',
];

/// The waiver screen screen.
class WaiverScreen extends StatefulWidget {
  /// Creates a [WaiverScreen].
  const WaiverScreen({super.key});

  @override
  State<WaiverScreen> createState() => _WaiverScreenState();
}

class _WaiverScreenState extends State<WaiverScreen> {
  final _reasonController = TextEditingController();
  String _tag = _waiverTags.first;
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final reportId = args?['reportId'] as String?;
    final findingId = args?['findingId'] as String?;
    final report = reportId == null
        ? controller.currentReport
        : controller.reportById(reportId) ?? controller.currentReport;
    const p = AppTheme.palette;
    Finding? finding;
    if (report != null && findingId != null) {
      for (final f in report.defects) {
        if (f.id == findingId) finding = f;
      }
    }
    if (report == null || finding == null) {
      return const FpScaffold(
        title: 'Waiver',
        showBack: true,
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.search_off_outlined,
            title: 'Defect not found',
            body: 'It may belong to an older report.',
          ),
        ),
      );
    }
    final f = finding;
    if (f.status == FindingStatus.waived && f.waiver != null) {
      // Already waived — show the record instead of the form.
      return FpScaffold(
        title: 'Defect',
        showBack: true,
        body: FpScrollBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${f.ruleCode} · ${_ruleName(controller, f.ruleCode)}',
                style: AppTheme.mono(size: 12, color: p.secondary),
              ),
              const SizedBox(height: 8),
              Text(
                f.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 14),
              GlassCard(
                borderColor: p.muted.withValues(alpha: 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Already waived — on record'),
                    const SizedBox(height: 6),
                    Text(
                      '“${f.waiver!.reason}”',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${f.waiver!.tag} · ${f.waiver!.waivedBy}',
                      style: AppTheme.mono(size: 12, color: p.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FpGhostButton(
                label: 'Back to report',
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/report-waived',
                  arguments: {'reportId': report.id},
                ),
              ),
            ],
          ),
        ),
      );
    }
    final chars = _reasonController.text.length;
    final valid = chars >= kMinWaiverChars;
    return FpScaffold(
      title: 'Defect',
      showBack: true,
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${f.ruleCode} · ${_ruleName(controller, f.ruleCode)}',
              style: AppTheme.mono(size: 12, color: p.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              f.title,
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
                        Text(
                          f.ruleCode,
                          style:
                              AppTheme.mono(size: 12, color: p.secondary),
                        ),
                        Tag('Defect', color: p.red),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${f.timecode} · ${f.measuredLabel} vs ${f.limitLabel}',
                      style: AppTheme.mono(size: 12, color: p.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      f.detail,
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
                    const Kicker('Waive this defect'),
                    const SizedBox(height: 6),
                    Text(
                      'A waiver needs a reason, and the reason stays in '
                      'the report. Waiving never deletes the finding.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                          ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reasonController,
                      maxLines: 4,
                      maxLength: 280,
                      decoration: const InputDecoration(
                        hintText: 'Why is this defect waived? '
                            'Be specific — the reason is the record.',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Flexed: the count wraps instead of pushing
                        // the label off the card in the narrow column.
                        Expanded(
                          child: Text(
                            '$chars characters · minimum $kMinWaiverChars',
                            style: AppTheme.mono(
                              size: 12,
                              color: valid ? p.green : p.muted,
                            ),
                          ),
                        ),
                        Text(
                          'Reason required',
                          style: AppTheme.mono(size: 12, color: p.secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _waiverTags
                          .map((tag) => ChoiceChip(
                                label: Text(tag),
                                selected: _tag == tag,
                                onSelected: (_) =>
                                    setState(() => _tag = tag),
                                selectedColor:
                                    p.amber.withValues(alpha: 0.4),
                                backgroundColor: p.glass,
                                side: BorderSide(color: p.hairline),
                                labelStyle: TextStyle(
                                  color: _tag == tag ? p.ink : p.faint,
                                  fontSize: 13,
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'After this waiver, ${report.fixedAwaiting.length} fix'
              '${report.fixedAwaiting.length == 1 ? ' is' : 'es are'} '
              'applied (awaiting re-inspection). The exit code stays 1 '
              'until re-inspection confirms it.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                  ),
            ),
            const SizedBox(height: 12),
            FpPrimaryButton(
              label: _saving ? 'Recording…' : 'Waive and record reason',
              onPressed: valid && !_saving
                  ? () => _waive(context, controller, report, f)
                  : null,
            ),
            const SizedBox(height: 8),
            FpGhostButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  String _ruleName(AppController controller, String code) {
    return controller.ruleByCode(code)?.name ?? code;
  }

  Future<void> _waive(
    BuildContext context,
    AppController controller,
    Report report,
    Finding finding,
  ) async {
    setState(() => _saving = true);
    try {
      final updated = await controller.waiveFinding(
        report.id,
        finding.id,
        reason: _reasonController.text,
        tag: _tag,
      );
      if (!context.mounted) return;
      if (updated == null) {
        showFpSnack(context, 'The reason needs at least $kMinWaiverChars characters.');
        return;
      }
      Navigator.pushNamed(
        context,
        '/report-waived',
        arguments: {'reportId': updated.id},
      );
    } on Object catch (_) {
      // Saving the waiver failed (storage unavailable): say so instead
      // of leaving the button stuck on "Recording…".
      if (!context.mounted) return;
      showFpSnack(context, 'Could not record the waiver. Try again.');
    } finally {
      if (context.mounted) setState(() => _saving = false);
    }
  }
}
