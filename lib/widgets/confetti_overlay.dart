import 'dart:math';
import 'package:flutter/material.dart';

/// Colorful pieces that fall for about 4 seconds, then fade out.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _pieces = List.generate(80, (_) => _Piece(rand));
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value),
        ),
      ),
    );
  }
}

class _Piece {
  static const _colors = [
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.pink,
  ];

  final double x; // start position, 0..1 of the width
  final double delay; // when it starts falling, 0..0.4
  final double speed; // how far it falls
  final double size;
  final double drift; // sideways movement
  final double spin;
  final Color color;

  _Piece(Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * 0.4,
        speed = 0.7 + r.nextDouble() * 0.3,
        size = 6 + r.nextDouble() * 7,
        drift = (r.nextDouble() - 0.5) * 0.25,
        spin = r.nextDouble() * 8,
        color = _colors[r.nextInt(_colors.length)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double progress; // 0..1

  _ConfettiPainter(this.pieces, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final fade = 1 - ((progress - 0.8) / 0.2).clamp(0.0, 1.0);

    for (final p in pieces) {
      if (progress < p.delay) continue;
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);

      final dx = (p.x + p.drift * t) * size.width;
      final dy = -20 + t * p.speed * (size.height + 40);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.spin * t * 6);
      final paint = Paint()..color = p.color.withOpacity(fade);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}