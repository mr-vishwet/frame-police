/// Rule detail — screen 13 (mobile + web).
///
/// The editable limit beside the evidence schema and version history.
/// Changing a limit versions the rule — it never rewrites history.
/// On web the limit editor sits beside the schema + history.
library;

import 'package:material_ui/material_ui.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

/// The rule detail screen screen.
class RuleDetailScreen extends StatefulWidget {
  /// Creates a [RuleDetailScreen].
  const RuleDetailScreen({super.key});

  @override
  State<RuleDetailScreen> createState() => _RuleDetailScreenState();
}

class _RuleDetailScreenState extends State<RuleDetailScreen> {
  double? _selectedValue;
  String? _selectedLabel;
  final _customController = TextEditingController();
  bool _custom = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final ruleCode = args?['ruleCode'] as String?;
    final rule =
        ruleCode == null ? null : controller.ruleByCode(ruleCode);
    const p = AppTheme.palette;
    if (rule == null) {
      return const FpScaffold(
        title: 'Rule',
        showBack: true,
        body: FpScrollBody(
          child: FpEmptyState(
            icon: Icons.rule_outlined,
            title: 'Rule not found',
            body: 'It may have been removed from the registry.',
          ),
        ),
      );
    }
    final options = _limitOptions(rule);
    final currentValue = _selectedValue ?? rule.limitValue;
    final currentLabel = _selectedLabel ?? rule.limitLabel;
    final changed = _selectedValue != null &&
        (_selectedValue != rule.limitValue ||
            _selectedLabel != rule.limitLabel);
    return FpScaffold(
      title: 'Rule',
      showBack: true,
      actions: [
        Center(
          child: Tag(
            rule.isDefect ? 'Defect rule' : 'Suggestion rule',
            color: rule.isDefect ? p.red : p.faint,
          ),
        ),
      ],
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${rule.code} · rule ${rule.version}',
              style: AppTheme.mono(size: 12, color: p.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              '${rule.name}.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              rule.description,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              left: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Limit — editable, versioned'),
                    const SizedBox(height: 8),
                    Text(
                      _limitTitle(rule),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _limitSubtitle(rule),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in options)
                          ChoiceChip(
                            label: Text(option.$2),
                            selected: !_custom &&
                                currentValue == option.$1 &&
                                currentLabel == option.$2,
                            onSelected: (_) => setState(() {
                              _custom = false;
                              _selectedValue = option.$1;
                              _selectedLabel = option.$2;
                            }),
                            selectedColor:
                                p.amber.withValues(alpha: 0.4),
                            backgroundColor: p.glass,
                            side: BorderSide(color: p.hairline),
                            labelStyle: TextStyle(
                              color: !_custom &&
                                      currentValue == option.$1
                                  ? p.ink
                                  : p.faint,
                            ),
                          ),
                        ChoiceChip(
                          label: const Text('Custom'),
                          selected: _custom,
                          onSelected: (_) =>
                              setState(() => _custom = true),
                          selectedColor: p.amber.withValues(alpha: 0.4),
                          backgroundColor: p.glass,
                          side: BorderSide(color: p.hairline),
                          labelStyle: TextStyle(
                            color: _custom ? p.ink : p.faint,
                          ),
                        ),
                      ],
                    ),
                    if (_custom) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Custom limit (${rule.unit})',
                          suffixText: rule.unit,
                        ),
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          setState(() {
                            if (parsed != null) {
                              _selectedValue = parsed;
                              _selectedLabel =
                                  '${value.trim()} ${rule.unit}';
                            }
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Changing a limit creates a new rule version. Old '
                      'reports keep pointing at the version that ran them.',
                      style: Theme.of(context).textTheme.bodySmall,
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
                        const Kicker('Evidence schema'),
                        const SizedBox(height: 8),
                        Text(
                          _evidenceSchema(rule),
                          style: AppTheme.mono(size: 12, color: p.secondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Kicker('Version history'),
                        const SizedBox(height: 8),
                        Text(
                          '${rule.version} · current — ${rule.limitLabel}',
                          style:
                              AppTheme.mono(size: 12, color: p.secondary),
                        ),
                        for (final version in rule.versions) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${version.version} — ${version.limitLabel}',
                            style: AppTheme.mono(size: 12, color: p.faint),
                          ),
                          Text(
                            version.note,
                            style:
                                Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
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
                    label: 'Save as new version',
                    onPressed: changed
                        ? () => _save(context, controller, rule)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FpGhostButton(
                    label: rule.enabled ? 'Disable rule' : 'Enable rule',
                    onPressed: () {
                      controller.toggleRule(rule.code, !rule.enabled);
                      showFpSnack(
                        context,
                        rule.enabled
                            ? '${rule.code} disabled — it will not run.'
                            : '${rule.code} enabled.',
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Edits never rewrite history — they version it.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Preset limit options per rule (value, label).
  List<(double, String)> _limitOptions(Rule rule) {
    switch (rule.code) {
      case 'SUB-SAFE-01':
        return const [(85, '85%'), (90, '90%'), (93, '93%')];
      case 'AUD-PEAK-02':
        return const [(-0.5, '−0.5 dBFS'), (-1.0, '−1.0 dBFS'), (-2.0, '−2.0 dBFS')];
      case 'CAP-SYNC-01':
        return const [(80, '±80 ms'), (120, '±120 ms'), (200, '±200 ms')];
      case 'TITLE-SAFE-01':
        return const [(80, '80%'), (85, '85%'), (90, '90%')];
      case 'SUG-LOUD-01':
        return const [(-16.0, '−16.0 LUFS'), (-14.0, '−14.0 LUFS'), (-12.0, '−12.0 LUFS')];
      case 'SUG-OPEN-01':
        return const [(0.4, '< 40% dark'), (0.5, '< 50% dark'), (0.6, '< 60% dark')];
      default:
        return [(rule.limitValue, rule.limitLabel)];
    }
  }

  String _limitTitle(Rule rule) {
    switch (rule.code) {
      case 'SUB-SAFE-01':
        return 'Safe-area margin';
      case 'AUD-PEAK-02':
        return 'Peak ceiling';
      case 'CAP-SYNC-01':
        return 'Sync tolerance';
      case 'TITLE-SAFE-01':
        return 'Title-safe margin';
      case 'SUG-LOUD-01':
        return 'Loudness target';
      case 'SUG-OPEN-01':
        return 'Darkness threshold';
      default:
        return 'Limit';
    }
  }

  String _limitSubtitle(Rule rule) {
    switch (rule.code) {
      case 'SUB-SAFE-01':
        return 'Bottom edge must stay inside the margin of frame height';
      case 'AUD-PEAK-02':
        return 'No peak may exceed the ceiling; no dead air over 1.5 s';
      default:
        return rule.limitLabel;
    }
  }

  String _evidenceSchema(Rule rule) {
    switch (rule.code) {
      case 'SUB-SAFE-01':
        return 'timecode 00:00:12:08\n'
            'measured y = 1,066 px\n'
            'limit y ≤ 1,052 px\n'
            'frame rendered + overlay\n'
            'rule SUB-SAFE-01 v1.2';
      case 'AUD-PEAK-02':
        return 'timecode 00:00:31:22\n'
            'measured peak −0.8 dBFS\n'
            'limit −1.0 dBFS\n'
            'waveform + limit line\n'
            'rule AUD-PEAK-02 v2.0';
      default:
        return 'timecode\n'
            'measured value\n'
            'limit ${rule.limitLabel}\n'
            'rule ${rule.code} ${rule.version}';
    }
  }

  Future<void> _save(
    BuildContext context,
    AppController controller,
    Rule rule,
  ) async {
    final value = _selectedValue ?? rule.limitValue;
    final label = _selectedLabel ?? rule.limitLabel;
    await controller.updateRuleLimit(
      code: rule.code,
      newValue: value,
      newLabel: label,
      note: 'Limit changed from ${rule.limitLabel} to $label.',
    );
    if (!context.mounted) return;
    setState(() {
      _selectedValue = null;
      _selectedLabel = null;
      _custom = false;
      _customController.clear();
    });
    showFpSnack(context, '${rule.code} saved as a new version.');
  }
}
