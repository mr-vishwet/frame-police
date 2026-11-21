/// Shared Frame Police widgets: glass cards, tags, buttons, stat tiles,
/// and the exit-code badge.
///
/// These carry the V7 look (glassmorphic cards on near-black, amber
/// accents) so screens stay composition, not styling.
library;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// A glassmorphic card — the V7 surface.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? p.hairline),
      ),
      child: child,
    );
  }
}

/// Small uppercase kicker label above a section.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppTheme.palette.muted,
          ),
    );
  }
}

/// A pill tag (e.g. `Registry v2.4.1`, `Exit 1`, `DEMO`).
class Tag extends StatelessWidget {
  const Tag(
    this.text, {
    this.color,
    this.filled = false,
    super.key,
  });

  final String text;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palette;
    final c = color ?? p.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? c.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: AppTheme.mono(size: 11, color: c),
      ),
    );
  }
}

/// A statistic: label above a large value above a caption.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    required this.caption,
    this.valueColor,
    super.key,
  });

  final String label;
  final String value;
  final String caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTheme.mono(
            size: 22,
            color: valueColor ?? p.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// The exit-code badge — the verdict, always visible on report screens.
class ExitBadge extends StatelessWidget {
  const ExitBadge(this.exitCode, {this.large = false, super.key});

  final int exitCode;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palette;
    final color = exitCode == kExitClean ? p.green : p.red;
    return Tag(
      'Exit $exitCode',
      color: color,
      filled: large,
    );
  }
}

/// Primary gradient CTA.
class FpPrimaryButton extends StatelessWidget {
  const FpPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palette;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: p.background0),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.background0,
            ),
          ),
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: p.accentGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: p.orange.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(52),
        ),
        child: child,
      ),
    );
  }
}

/// Ghost (outlined) button.
class FpGhostButton extends StatelessWidget {
  const FpGhostButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
      ),
    );
  }
}

/// Danger (red outline) button — destructive actions only.
class FpDangerButton extends StatelessWidget {
  const FpDangerButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palette;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: 18, color: p.red),
      label: Text(label, style: TextStyle(color: p.red)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: p.red.withValues(alpha: 0.5)),
      ),
    );
  }
}

/// A settings-style row: icon, title, subtitle, trailing widget.
class FpRow extends StatelessWidget {
  const FpRow({
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.danger = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palette;
    final content = Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: p.glass,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: danger ? p.red : p.secondary,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      color: danger ? p.red : null,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: content,
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: content,
      ),
    );
  }
}

/// A settings toggle row.
class FpToggleRow extends StatelessWidget {
  const FpToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FpRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// Empty state with an icon, title, and body.
class FpEmptyState extends StatelessWidget {
  const FpEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palette;
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, size: 36, color: p.muted),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Shows a snackbar message.
void showFpSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
