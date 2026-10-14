import 'package:flutter/material.dart';
import '../models/player.dart';
import 'player_avatar.dart';

/// A number that counts up smoothly when its value changes.
class AnimatedScore extends StatelessWidget {
  final int value;
  final TextStyle? style;

  const AnimatedScore({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value.toDouble(), end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

/// Mini scoreboard plus "answered / thinking" status for every player.
class PlayersPanel extends StatelessWidget {
  final List<Player> players;
  final Map<String, int> scores;
  final Set<String> answered;
  final Map<String, int> questionPoints;
  final bool reveal;
  final String myUid;

  const PlayersPanel({
    super.key,
    required this.players,
    required this.scores,
    required this.answered,
    required this.questionPoints,
    required this.reveal,
    required this.myUid,
  });

  Widget _status(Player p) {
    if (reveal) {
      final pts = questionPoints[p.uid] ?? 0;
      return Text(
        pts > 0 ? '+$pts' : '0',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: pts > 0 ? Colors.green.shade700 : Colors.grey,
        ),
      );
    }
    if (answered.contains(p.uid)) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18),
          SizedBox(width: 4),
          Text('Answered', style: TextStyle(fontSize: 12)),
        ],
      );
    }
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.hourglass_top, color: Colors.grey, size: 18),
        SizedBox(width: 4),
        Text('Thinking', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...players]
      ..sort((a, b) => (scores[b.uid] ?? 0).compareTo(scores[a.uid] ?? 0));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scoreboard',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...sorted.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text('${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    PlayerAvatar(
                        name: p.name, photoUrl: p.photoUrl, radius: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.uid == myUid ? '${p.name} (You)' : p.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _status(p),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 56,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedScore(
                          value: scores[p.uid] ?? 0,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}