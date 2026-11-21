/// Score bars: the quality-history chart (last 5 inspections).
///
/// The latest bar is amber when it is the worst of the five — the
/// latest run is the one that matters — and green when it is clean.
library;

import 'package:flutter/material.dart';

import '../core/theme.dart';

class ScoreBars extends StatelessWidget {
  const ScoreBars({
    required this.scores,
    this.height = 84,
    super.key,
  });

  final List<int> scores;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palette;
    if (scores.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No inspections yet')),
      );
    }
    final worst = scores.reduce((a, b) => a < b ? a : b);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < scores.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${scores[i]}',
                    style: AppTheme.mono(
                      size: 11,
                      color: scores[i] == worst && i == scores.length - 1
                          ? p.muted
                          : p.faint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: scores[i] / 100,
                        widthFactor: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                scores[i] == worst &&
                                        i == scores.length - 1
                                    ? p.muted
                                    : p.green,
                                scores[i] == worst &&
                                        i == scores.length - 1
                                    ? p.orange
                                    : p.green.withValues(alpha: 0.55),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
