/// Logo widgets — the chosen v2 set (four amber corner brackets, the
/// shield in negative space), bundled as SVG assets.
///
/// The icon and app-icon tile are amber-on-dark and render on the app's
/// dark surfaces. The horizontal and stacked lockups carry dark wordmark
/// text (#171B22) and need a light background — [FpLogoLockup] renders
/// them on a cream chip.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The icon mark (no text) — used in headers and the badge.
class FpLogoMark extends StatelessWidget {
  const FpLogoMark({this.size = 36, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logos/icon.svg',
      width: size,
      height: size,
      semanticsLabel: 'Frame Police logo',
    );
  }
}

/// The rounded-square app-icon tile (dark tile, amber mark).
class FpAppIcon extends StatelessWidget {
  const FpAppIcon({this.size = 64, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SvgPicture.asset(
        'assets/logos/app-icon.svg',
        width: size,
        height: size,
        semanticsLabel: 'Frame Police app icon',
      ),
    );
  }
}

/// A lockup (horizontal or stacked) on a light chip, because the
/// wordmark text is dark.
class FpLogoLockup extends StatelessWidget {
  const FpLogoLockup.horizontal({this.width = 220, super.key})
      : _asset = 'assets/logos/horizontal.svg',
        _aspect = 2048 / 512;

  const FpLogoLockup.stacked({this.width = 180, super.key})
      : _asset = 'assets/logos/stacked.svg',
        _aspect = 2048 / 1330;

  final String _asset;
  final double _aspect;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0DC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SvgPicture.asset(
        _asset,
        width: width,
        height: width / _aspect,
        semanticsLabel: 'Frame Police logo',
      ),
    );
  }
}

/// The glossy shield badge used on Home and the payoff screen: the
/// app-icon tile with an amber glow, gently bobbing.
class FpBadge extends StatefulWidget {
  const FpBadge({this.size = 96, super.key});

  final double size;

  @override
  State<FpBadge> createState() => _FpBadgeState();
}

class _FpBadgeState extends State<FpBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -6 * _controller.value + 3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.size * 0.22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF97316).withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: FpAppIcon(size: widget.size),
    );
  }
}
