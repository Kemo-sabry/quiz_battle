import 'package:flutter/material.dart';
import '../models/battle_room.dart';

class RoomTile extends StatelessWidget {
  final BattleRoom room;
  final VoidCallback onJoin;

  const RoomTile({super.key, required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.quiz_outlined,
                  color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.topic, style: theme.textTheme.titleMedium),
                  Text('${room.difficulty} • ${room.questionCount} questions',
                      style: theme.textTheme.bodySmall),
                  Text('Host: ${room.hostName}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 16),
                    const SizedBox(width: 4),
                    Text('${room.players.length}/${room.maxPlayers}'),
                  ],
                ),
                const SizedBox(height: 6),
                FilledButton.tonal(
                  onPressed: room.isFull ? null : onJoin,
                  child: Text(room.isFull ? 'Full' : 'Join'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}