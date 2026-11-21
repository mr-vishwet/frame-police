/// Before/after frame mock for the subtitle defect screen.
///
/// A stylised 9:16 frame with a subtitle bar and the safe-area line:
/// the before frame shows the subtitle below the line (red), the after
/// frame shows it inside (green). The fix is shown, not described.
library;

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// The frame mock widget.
class FrameMock extends StatelessWidget {
  /// Creates a [FrameMock].
  const FrameMock.before({
    required this.subtitleY,
    required this.limitY,
    super.key,
  }) : _isBefore = true;

  /// Creates a [FrameMock].
  const FrameMock.after({
    required this.subtitleY,
    required this.limitY,
    super.key,
  }) : _isBefore = false;

  /// The subtitle y.
  final double subtitleY;
  /// The limit y.
  final double limitY;
  final bool _isBefore;

  @override
  Widget build(BuildContext context) {
    const p = AppTheme.palette;
    // Frame is 163x190 in the design; scale the y values (frame height
    // 1920 px) into the mock's height.
    const mockHeight = 190.0;
    const frameHeight = 1920.0;
    final subTop = (subtitleY / frameHeight) * mockHeight;
    final limitTop = (limitY / frameHeight) * mockHeight;
    final breach = _isBefore;
    return Container(
      height: mockHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [p.background2, p.background1],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.hairline),
      ),
      child: Stack(
        children: [
          // Fake scene: gradient orb + horizon line.
          Positioned(
            top: 28,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: p.accentGradient,
                ),
              ),
            ),
          ),
          Positioned(
            top: 108,
            left: 16,
            right: 16,
            child: Container(height: 1, color: p.hairline),
          ),
          // Safe-area line.
          Positioned(
            top: limitTop,
            left: 0,
            right: 0,
            child: Container(
              height: 1.5,
              color: (breach ? p.red : p.green).withValues(alpha: 0.8),
            ),
          ),
          // Subtitle bar.
          Positioned(
            top: subTop,
            left: 18,
            right: 18,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: breach ? p.red : p.green,
                  width: 1.2,
                ),
              ),
              child: Text(
                '“Ship nothing with a defect.”',
                style: TextStyle(
                  fontSize: 10,
                  color: breach ? p.red : p.green,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Text(
              _isBefore ? 'BEFORE' : 'AFTER',
              style: AppTheme.mono(
                size: 10,
                color: breach ? p.red : p.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
