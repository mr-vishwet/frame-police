/// Waveform and marker-track painters for the audio defect screens.
///
/// The waveform draws REAL measured peaks — the normalized samples the
/// probe captured from the export's audio. There is no seeded or
/// synthetic waveform anywhere: when the probe captured no peaks, the
/// screens show an honest "No audio waveform" state instead of drawing
/// one.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// A waveform drawn from real measured peaks (normalized 0..1).
/// [peakAt] (0..1) marks the over-limit peak in red, when the finding
/// has one.
class WaveformView extends StatelessWidget {
  /// Creates a [WaveformView].
  const WaveformView({
    required this.peaks,
    this.height = 64,
    this.peakAt,
    this.color,
    this.showLimit = false,
    super.key,
  });

  /// The measured peaks, normalized 0..1.
  final List<double> peaks;

  /// The height.
  final double height;

  /// Where the over-limit peak sits (0..1), highlighted in red.
  final double? peakAt;

  /// The color.
  final Color? color;

  /// Whether to show the limit line.
  final bool showLimit;

  @override
  Widget build(BuildContext context) {
    const p = AppTheme.palette;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _WaveformPainter(
          peaks: peaks,
          peakAt: peakAt,
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
    required this.peaks,
    required this.peakAt,
    required this.color,
    required this.limitColor,
    required this.showLimit,
  });

  final List<double> peaks;
  final double? peakAt;
  final Color color;
  final Color limitColor;
  final bool showLimit;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;
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
      // Downsample the real peaks: each bar shows the max of its slice.
      final start = (t * peaks.length).floor();
      final end = ((i + 1) / bars * peaks.length).ceil().clamp(
            start + 1,
            peaks.length,
          );
      var amp = 0.0;
      for (var j = start; j < end; j++) {
        amp = math.max(amp, peaks[j].clamp(0.0, 1.0));
      }
      final isPeak =
          peakAt != null && (t - peakAt!).abs() < 1 / bars;
      final barHeight = (amp * size.height).clamp(2.0, size.height);
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
      old.peaks != peaks ||
      old.peakAt != peakAt ||
      old.color != color;
}

/// Marker tracks: a timeline strip with defect markers at their
/// timecodes.
class MarkerTracks extends StatelessWidget {
  /// Creates a [MarkerTracks].
  const MarkerTracks({
    required this.durationSeconds,
    required this.markers,
    this.height = 30,
    super.key,
  });

  /// The duration in seconds.
  final int durationSeconds;

  /// (timecodeSeconds, label, isDefect) markers.
  final List<(double, String, bool)> markers;

  /// The height.
  final double height;

  @override
  Widget build(BuildContext context) {
    const p = AppTheme.palette;
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
