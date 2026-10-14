import 'package:flutter/material.dart';

enum AnswerVisual { idle, selected, correct, wrong, dimmed }

class AnswerButton extends StatelessWidget {
  final String letter;
  final String text;
  final AnswerVisual visual;
  final VoidCallback? onTap; // null = disabled

  const AnswerButton({
    super.key,
    required this.letter,
    required this.text,
    required this.visual,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color bg;
    Color border;
    IconData? icon;
    Color? iconColor;
    double opacity = 1;

    switch (visual) {
      case AnswerVisual.idle:
        bg = scheme.primaryContainer.withOpacity(0.35);
        border = scheme.outlineVariant;
        break;
      case AnswerVisual.selected:
        bg = scheme.primaryContainer;
        border = scheme.primary;
        icon = Icons.radio_button_checked;
        iconColor = scheme.primary;
        break;
      case AnswerVisual.correct:
        bg = Colors.green.shade100;
        border = Colors.green;
        icon = Icons.check_circle;
        iconColor = Colors.green.shade700;
        break;
      case AnswerVisual.wrong:
        bg = Colors.red.shade100;
        border = Colors.red;
        icon = Icons.cancel;
        iconColor = Colors.red.shade700;
        break;
      case AnswerVisual.dimmed:
        bg = scheme.surfaceVariant.withOpacity(0.4);
        border = scheme.outlineVariant;
        opacity = 0.55;
        break;
    }

    final strong = visual == AnswerVisual.correct ||
        visual == AnswerVisual.wrong ||
        visual == AnswerVisual.selected;

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: strong ? 2 : 1),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: scheme.surface,
                    child: Text(letter,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(text, style: const TextStyle(fontSize: 16)),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, color: iconColor),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}