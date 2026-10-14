import 'package:flutter/material.dart';
import '../models/answer.dart';

/// "Correct! +800" banner plus the AI explanation card.
class RevealBanner extends StatelessWidget {
  final Answer? answer; // null = time ran out
  final String explanation;

  const RevealBanner({
    super.key,
    required this.answer,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String title;
    final Color color;
    final IconData icon;

    if (answer == null) {
      title = "Time's up!";
      color = Colors.orange.shade800;
      icon = Icons.timer_off_outlined;
    } else if (answer!.isCorrect) {
      title = 'Correct!';
      color = Colors.green.shade700;
      icon = Icons.celebration;
    } else {
      title = 'Wrong answer';
      color = Colors.red.shade700;
      icon = Icons.sentiment_dissatisfied;
    }
    final points = answer?.points ?? 0;

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
                if (points > 0) ...[
                  const SizedBox(width: 14),
                  Text(
                    '+$points',
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline),
                const SizedBox(width: 10),
                Expanded(child: Text(explanation)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}