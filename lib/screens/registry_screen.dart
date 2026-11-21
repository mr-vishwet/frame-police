/// Rule registry — screen 12 (mobile + web).
///
/// Every rule, versioned. Search + filter (All / Defects / Suggestions),
/// tap a rule for its detail. On web the rules lay out in two columns.
library;

import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../engine/models.dart';
import '../state/app_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/fp_widgets.dart';

enum _Filter { all, defects, suggestions }

/// The registry screen screen.
class RegistryScreen extends StatefulWidget {
  /// Creates a [RegistryScreen].
  const RegistryScreen({super.key});

  @override
  State<RegistryScreen> createState() => _RegistryScreenState();
}

class _RegistryScreenState extends State<RegistryScreen> {
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    const p = AppTheme.palette;
    final query = _query.toLowerCase();
    final visible = controller.rules.where((rule) {
      if (_filter == _Filter.defects && !rule.isDefect) return false;
      if (_filter == _Filter.suggestions && rule.isDefect) return false;
      if (query.isEmpty) return true;
      return rule.code.toLowerCase().contains(query) ||
          rule.name.toLowerCase().contains(query);
    }).toList();
    final defectCount =
        controller.rules.where((r) => r.isDefect).length;
    final suggestionCount =
        controller.rules.where((r) => !r.isDefect).length;
    return FpScaffold(
      tabIndex: 2,
      body: FpScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rule registry',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Tag(kRegistryVersion),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Every rule, versioned.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'The report records the registry version. Same input, same '
              'rules, same report — every time.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: p.faint),
            ),
            const SizedBox(height: 14),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search rules',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_Filter>(
              segments: [
                ButtonSegment(
                  value: _Filter.all,
                  label: Text('All ${controller.rules.length}'),
                ),
                ButtonSegment(
                  value: _Filter.defects,
                  label: Text('Defects · $defectCount'),
                ),
                ButtonSegment(
                  value: _Filter.suggestions,
                  label: Text('Suggestions · $suggestionCount'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (selected) =>
                  setState(() => _filter = selected.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: p.amber.withValues(alpha: 0.25),
                selectedForegroundColor: p.ink,
                foregroundColor: p.faint,
                side: BorderSide(color: p.hairline),
              ),
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const FpEmptyState(
                icon: Icons.search_off_outlined,
                title: 'No rules match',
                body: 'Try a different search or filter.',
              )
            else if (isWide(context))
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0;
                            i < visible.length;
                            i += 2)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ruleCard(context, visible[i]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 1;
                            i < visible.length;
                            i += 2)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ruleCard(context, visible[i]),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            else
              GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 6),
                child: Column(
                  children: [
                    for (final rule in visible)
                      _ruleRow(context, rule),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ruleRow(BuildContext context, Rule rule) {
    const p = AppTheme.palette;
    return FpRow(
      title: rule.name,
      subtitle: '${rule.code} · rule ${rule.version}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tag(
            rule.isDefect ? 'Defect' : 'Suggestion',
            color: rule.isDefect ? p.red : p.faint,
          ),
          const SizedBox(width: 6),
          Switch(
            value: rule.enabled,
            onChanged: (value) =>
                AppScope.read(context).toggleRule(rule.code, value),
          ),
        ],
      ),
      onTap: () => Navigator.pushNamed(
        context,
        '/rule',
        arguments: {'ruleCode': rule.code},
      ),
    );
  }

  Widget _ruleCard(BuildContext context, Rule rule) {
    const p = AppTheme.palette;
    return GlassCard(
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/rule',
          arguments: {'ruleCode': rule.code},
        ),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rule.code,
                  style: AppTheme.mono(size: 12, color: p.secondary),
                ),
                Tag(
                  rule.isDefect ? 'Defect' : 'Suggestion',
                  color: rule.isDefect ? p.red : p.faint,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rule.name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              rule.description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'rule ${rule.version} · ${rule.limitLabel}',
                  style: AppTheme.mono(size: 11, color: p.muted),
                ),
                Switch(
                  value: rule.enabled,
                  onChanged: (value) => AppScope.read(context)
                      .toggleRule(rule.code, value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
