import 'package:flutter/material.dart';

/// Responsive helpers: one codebase, one route per screen, two layouts.
///
/// The V7 inventory has 30 mobile screens + 30 web screens. In Flutter
/// each pair is ONE route that adapts: below [kWideBreakpoint] it lays
/// out as the mobile screen (single column, bottom tab bar); at or above
/// it lays out as the web screen (side navigation, two-column content,
/// wider max width). All 60 inventory screens are covered by the 30
/// responsive routes — see README "Screens".
library;

/// Width at or above which the web layout applies.
const double kWideBreakpoint = 720;

/// Maximum content width on wide screens.
const double kMaxContentWidth = 1120;

/// Maximum content width on narrow screens.
const double kMaxNarrowWidth = 560;

/// Whether the current layout is the wide (web/desktop) one.
bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// Centres [child] and constrains its width: [kMaxNarrowWidth] on
/// mobile, [kMaxContentWidth] on web.
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxWidth = isWide(context) ? kMaxContentWidth : kMaxNarrowWidth;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Two-column layout on wide screens, single column (left then right)
/// on narrow screens.
///
/// [leftFlex] / [rightFlex] control the wide split; [gap] separates the
/// columns (and the stacked sections on mobile).
class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({
    required this.left,
    required this.right,
    this.leftFlex = 3,
    this.rightFlex = 2,
    this.gap = 16,
    super.key,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (!isWide(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, SizedBox(height: gap), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        SizedBox(width: gap),
        Expanded(flex: rightFlex, child: right),
      ],
    );
  }
}

/// A grid that shows [wideColumns] on wide screens and [narrowColumns]
/// on narrow screens.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    required this.children,
    this.narrowColumns = 2,
    this.wideColumns = 4,
    this.gap = 12,
    super.key,
  });

  final List<Widget> children;
  final int narrowColumns;
  final int wideColumns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final columns = isWide(context) ? wideColumns : narrowColumns;
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          final rowChildren = <Widget>[];
          for (var j = 0; j < columns; j++) {
            final index = i + j;
            if (index >= children.length) break;
            if (j > 0) rowChildren.add(SizedBox(width: gap));
            rowChildren.add(
              SizedBox(width: itemWidth, child: children[index]),
            );
          }
          if (i > 0) rows.add(SizedBox(height: gap));
          rows.add(Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowChildren,
          ));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
