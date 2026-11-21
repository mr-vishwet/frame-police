/// Waveform and marker-track painters for the audio defect screens.
///
/// The waveform is deterministic (seeded from the finding's rule code)
/// so the before/after pair is stable across rebuilds. The marker
/// tracks show where the defects sit on the timeline.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A deterministic waveform. [peakAt] (0..1) places the over-limit peak;
/// [cap] clamps the amplitude for the after-fix waveform.
class WaveformView extends StatelessWidget {
  const WaveformView({
    required this.seed,
    this.height = 64,
    this.peakAt,
    this.cap = 1.0,
    this.color,
    this.showLimit = false,
    super.key,
  });

  final int seed;
  final double height;
  final double? peakAt;
  final double cap;
  final Color? color;
  final bool showLimit;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palette;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _WaveformPainter(
          seed: seed,
          peakAt: peakAt,
          cap: cap,
          color: color ?? p.secondary.withValues(alpha: 0.55),
          limitColor: p.red,
          showLimit: showLimit,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.seed,
    required this.peakAt,
    required this.cap,
    required this.color,
    required this.limitColor,
    required this.showLimit,
  });

  final int seed;
  final double? peakAt;
  final double cap;
  final Color color;
  final Color limitColor;
  final bool showLimit;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    const bars = 72;
    final barWidth = size.width / bars;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final peakPaint = Paint()
      ..color = limitColor
      ..style = PaintingStyle.fill;
    for (var i = 0; i < bars; i++) {
      final t = i / bars;
      var amp = 0.25 + random.nextDouble() * 0.55;
      // A gentle swell toward the drop, then decay.
      amp *= 0.7 + 0.5 * math.sin(t * math.pi);
      var isPeak = false;
      if (peakAt != null && (t - peakAt!).abs() < 1 / bars) {
        amp = 1.0;
        isPeak = true;
      }
      amp = math.min(amp, cap);
      final barHeight = amp * size.height;
      final x = i * barWidth + barWidth * 0.2;
      final rect = Rect.fromLTWH(
        x,
        (size.height - barHeight) / 2,
        barWidth * 0.6,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        isPeak ? peakPaint : paint,
      );
    }
    if (showLimit) {
      final limitY = size.height * 0.12;
      final dashPaint = Paint()
        ..color = limitColor.withValues(alpha: 0.7)
        ..strokeWidth = 1.5;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, limitY),
          Offset(math.min(x + 8, size.width), limitY),
          dashPaint,
        );
        x += 14;
      }
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.seed != seed ||
      old.peakAt != peakAt ||
      old.cap != cap ||
      old.color != color;
}

/// Marker tracks: a timeline strip with defect markers at their
/// timecodes.
class MarkerTracks extends StatelessWidget {
  const MarkerTracks({
    required this.durationSeconds,
    required this.markers,
    this.height = 30,
    super.key,
  });

  final int durationSeconds;

  /// (timecodeSeconds, label, isDefect) markers.
  final List<(double, String, bool)> markers;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palette;
    return SizedBox(
      height: height + 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: height / 2 - 2,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.glassStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              for (final (seconds, label, isDefect) in markers)
                Positioned(
                  left: (seconds / durationSeconds) * width - 5,
                  top: 0,
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: height,
                        decoration: BoxDecoration(
                          color: isDefect ? p.red : p.muted,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: AppTheme.mono(
                          size: 9,
                          color: isDefect ? p.red : p.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
