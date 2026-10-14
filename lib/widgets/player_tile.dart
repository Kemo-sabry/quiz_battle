import 'package:flutter/material.dart';
import '../models/player.dart';
import 'player_avatar.dart';

class PlayerTile extends StatelessWidget {
  final Player player;
  final bool isHost;
  final bool isMe;

  const PlayerTile({
    super.key,
    required this.player,
    required this.isHost,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: PlayerAvatar(name: player.name, photoUrl: player.photoUrl),
        title: Text(isMe ? '${player.name} (You)' : player.name),
        subtitle: isHost
            ? Row(
          children: [
            Icon(Icons.star_rounded,
                size: 16, color: Colors.amber.shade700),
            const SizedBox(width: 4),
            const Text('Host'),
          ],
        )
            : null,
        trailing: player.isReady
            ? const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 4),
            Text('Ready'),
          ],
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty,
                color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text('Not ready',
                style: TextStyle(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}