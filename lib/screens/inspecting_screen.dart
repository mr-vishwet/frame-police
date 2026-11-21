/// Inspecting — screen 04 (mobile + web).
///
/// The live run: percentage, probe list, elapsed time. The inspection
/// starts when the screen opens and navigates to the report when it
/// finishes. Cancel returns to the previous screen without a report.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

class InspectingScreen extends StatefulWidget {
  const InspectingScreen({super.key});

  @override
  State<InspectingScreen> createState() => _InspectingScreenState();
}

class _InspectingScreenState extends State<InspectingScreen> {
  Timer? _clock;
  Duration _elapsed = Duration.zero;
  bool _started = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    final controller = AppScope.read(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final exportId = args?['exportId'] as String?;
    final reportId = args?['previousReportId'] as String?;
    final export = exportId == null
        ? controller.selectedExport
        : controller.exportById(exportId);
    if (export == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final previous =
        reportId == null ? null : controller.reportById(reportId);
    // A re-inspection first applies the fixes to the working copy.
    final runTarget = previous == null
        ? export
        : controller.prepareReinspection(previous);
    final report = await controller.runInspection(
      runTarget,
      previousReport: previous,
    );
    if (!mounted) return;
    if (report == null) {
      // Cancelled or errored: go back.
      Navigator.pop(context);
      return;
    }
    // A re-inspection that lands clean is the payoff; everything else
    // goes to the report verdict.
    if (previous != null && report.exitCode == 0) {
      _navigateToPayoff(report.id);
    } else {
      _navigateToReport(report.id);
    }
  }

  void _navigateToPayoff(String reportId) {
    if (_navigated) return;
    _navigated = true;
    Navigator.pushReplacementNamed(
      context,
      '/payoff',
      arguments: {'reportId': reportId},
    );
  }

  void _navigateToReport(String reportId) {
    if (_navigated) return;
    _navigated = true;
    Navigator.pushReplacementNamed(
      context,
      '/report',
      arguments: {'reportId': reportId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final exportId = args?['exportId'] as String?;
    final export = exportId == null
        ? controller.selectedExport
        : controller.exportById(exportId);
    final p = AppTheme.palette;
    final progress = controller.inspectionProgress;
    final running = controller.probeProgress
        .where((probe) => probe.state == ProbeState.running)
        .toList();
    final runningProbe = running.isEmpty ? null : running.first;
    final doneCount = controller.probeProgress
        .where((probe) => probe.state != ProbeState.queued &&
            probe.state != ProbeState.running)
        .length;
    final defectsSoFar = controller.probeProgress
        .where((probe) => probe.state == ProbeState.defect)
        .length;
    final elapsedText =
        '${_elapsed.inMinutes}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    final remaining = progress > 0
        ? Duration(
            seconds: (_elapsed.inSeconds * (1 - progress) / progress)
                .round(),
          )
        : const Duration(seconds: 8);
    final remainingText =
        '≈${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

    return FpScaffold(
      title: 'Inspecting',
      actions: [Center(child: Tag(kRegistryVersion))],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Kicker(export?.name ?? 'Export'),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${(progress * 100).round()}%',
                  style: AppTheme.mono(size: 52, color: p.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    runningProbe == null
                        ? 'Probe $doneCount of ${controller.probeProgress.length}'
                        : 'Probe ${doneCount + 1} of ${controller.probeProgress.length} · ${runningProbe.label}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: p.faint),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: p.glassStrong,
                valueColor: AlwaysStoppedAnimation<Color>(p.amber),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${formatInt(controller.framesProbed)} / '
              '${formatInt(export?.frameCount ?? 0)} frames probed · '
              '$defectsSoFar defect${defectsSoFar == 1 ? '' : 's'} so far',
              style: AppTheme.mono(size: 12, color: p.muted),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Kicker('Probes · registry $kRegistryVersion'),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: p.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Live',
                            style: AppTheme.mono(size: 12, color: p.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final probe in controller.probeProgress)
                    _probeRow(context, probe),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatTile(
                  label: 'Elapsed',
                  value: elapsedText,
                  caption: 'since start',
                ),
                StatTile(
                  label: 'Left',
                  value: remainingText,
                  caption: 'at current pace',
                ),
                StatTile(
                  label: 'Rules',
                  value: '${controller.probeProgress.length}',
                  caption:
                      '${controller.rules.where((r) => r.isDefect).length} defects · ${controller.rules.where((r) => !r.isDefect).length} suggestions',
                ),
              ],
            ),
            const SizedBox(height: 16),
            FpGhostButton(
              label: 'Cancel inspection',
              onPressed: () {
                AppScope.read(context).cancelInspection();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _probeRow(BuildContext context, ProbeProgress probe) {
    final p = AppTheme.palette;
    final (icon, color, label) = switch (probe.state) {
      ProbeState.queued => (Icons.schedule, p.muted, 'Queued'),
      ProbeState.running => (Icons.sync, p.orange, 'Running'),
      ProbeState.pass => (Icons.check_circle, p.green, 'Pass'),
      ProbeState.defect => (Icons.error, p.red, 'Defect'),
      ProbeState.suggestion => (Icons.lightbulb, p.muted, 'Suggestion'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: p.glass,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  probe.label,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 14),
                ),
                Text(
                  probe.detail.isEmpty ? probe.ruleCode : probe.detail,
                  style: AppTheme.mono(size: 11, color: p.muted),
                ),
              ],
            ),
          ),
          Text(label, style: AppTheme.mono(size: 12, color: color)),
        ],
      ),
    );
  }
}
