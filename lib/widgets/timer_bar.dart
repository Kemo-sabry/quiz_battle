import 'package:flutter/material.dart';

/// Animated countdown bar. Give it a new key for every question.
class TimerBar extends StatefulWidget {
  final int seconds;
  final bool running;

  const TimerBar({super.key, required this.seconds, required this.running});

  @override
  State<TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends State<TimerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.seconds),
    );
    if (widget.running) _c.forward();
  }

  @override
  void didUpdateWidget(TimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Freeze the bar when the reveal starts.
    if (!widget.running && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final left = 1 - _c.value;
        final secs = (left * widget.seconds).ceil();
        final color = left > 0.5
            ? Colors.green
            : left > 0.25
            ? Colors.orange
            : Colors.red;
        return Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: left,
                  minHeight: 12,
                  color: color,
                  backgroundColor: color.withOpacity(0.2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 32,
              child: Text(
                '$secs',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}