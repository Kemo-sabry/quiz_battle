import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'player_avatar.dart';

/// Ranks for a list that is already sorted from best to worst.
/// Equal scores share the same rank.
List<int> computeRanks(List<int> scores) {
  final ranks = <int>[];
  for (var i = 0; i < scores.length; i++) {
    if (i > 0 && scores[i] == scores[i - 1]) {
      ranks.add(ranks[i - 1]);
    } else {
      ranks.add(i + 1);
    }
  }
  return ranks;
}

class LeaderboardTile extends StatelessWidget {
  final int rank;
  final UserModel user;
  final bool isMe;
  final Widget? trailingAction; // for example the "remove friend" button

  const LeaderboardTile({
    super.key,
    required this.rank,
    required this.user,
    required this.isMe,
    this.trailingAction,
  });

  Widget _rankBadge() {
    if (rank > 3) {
      return SizedBox(
        width: 34,
        child: Text(
          '$rank',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    }
    final color = rank == 1
        ? Colors.amber.shade700
        : rank == 2
        ? Colors.blueGrey.shade300
        : Colors.brown.shade300;
    return SizedBox(width: 34, child: Icon(Icons.emoji_events, color: color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isMe ? theme.colorScheme.primaryContainer : null,
      shape: isMe
          ? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.primary, width: 2),
      )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _rankBadge(),
            const SizedBox(width: 8),
            PlayerAvatar(name: user.displayName, photoUrl: user.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '${user.displayName} (You)' : user.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(user.level, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Text(
              '${user.totalPoints}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Text('pts'),
            if (trailingAction != null) trailingAction!,
          ],
        ),
      ),
    );
  }
}