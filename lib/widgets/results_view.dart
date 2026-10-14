import 'package:flutter/material.dart';
import '../models/result_entry.dart';
import 'confetti_overlay.dart';
import 'player_avatar.dart';
import 'stat_card.dart';

/// The whole "Battle Complete" layout. It only draws what it is given,
/// so battles and Solo Practice can both use it.
class ResultsView extends StatelessWidget {
  final List<ResultEntry> entries; // sorted from highest score to lowest
  final String myUid;
  final String winnerTitle;
  final bool celebrate; // there is a winner: show trophy and confetti
  final int correctCount;
  final int totalQuestions;
  final int pointsEarned;
  final bool playAgainLoading;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  const ResultsView({
    super.key,
    required this.entries,
    required this.myUid,
    required this.winnerTitle,
    required this.celebrate,
    required this.correctCount,
    required this.totalQuestions,
    required this.pointsEarned,
    required this.playAgainLoading,
    required this.onPlayAgain,
    required this.onHome,
  });

  Widget _rankBadge(int rank) {
    if (rank > 3) {
      return SizedBox(
        width: 32,
        child: Text('$rank',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );
    }
    final color = rank == 1
        ? Colors.amber.shade700
        : rank == 2
        ? Colors.blueGrey.shade300
        : Colors.brown.shade300;
    return SizedBox(
      width: 32,
      child: Icon(Icons.emoji_events, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accuracy = totalQuestions == 0
        ? 0
        : (correctCount / totalQuestions * 100).round();

    // Equal scores share the same rank.
    final ranks = <int>[];
    for (var i = 0; i < entries.length; i++) {
      if (i > 0 && entries[i].score == entries[i - 1].score) {
        ranks.add(ranks[i - 1]);
      } else {
        ranks.add(i + 1);
      }
    }

    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Winner announcement
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Icon(
                    celebrate
                        ? Icons.emoji_events
                        : Icons.sentiment_neutral_outlined,
                    size: 96,
                    color: celebrate ? Colors.amber.shade700 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  winnerTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Final ranking
                Text('Final ranking', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...entries.asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  final mine = p.uid == myUid;
                  return Card(
                    color: mine ? theme.colorScheme.primaryContainer : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          _rankBadge(ranks[i]),
                          const SizedBox(width: 8),
                          PlayerAvatar(name: p.name, photoUrl: p.photoUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              mine ? '${p.name} (You)' : p.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '${p.score}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Text('pts'),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // My stats
                Text('Your performance', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.gps_fixed,
                        label: 'Accuracy',
                        value: '$accuracy%',
                      ),
                    ),
                    Expanded(
                      child: StatCard(
                        icon: Icons.check_circle_outline,
                        label: 'Correct',
                        value: '$correctCount/$totalQuestions',
                        color: Colors.green,
                      ),
                    ),
                    Expanded(
                      child: StatCard(
                        icon: Icons.star_rounded,
                        label: 'Points earned',
                        value: '$pointsEarned',
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Buttons
                FilledButton.icon(
                  onPressed: playAgainLoading ? null : onPlayAgain,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(16)),
                  icon: playAgainLoading
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.replay),
                  label: Text(playAgainLoading
                      ? 'Preparing new battle...'
                      : 'Play Again'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: playAgainLoading ? null : onHome,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16)),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Home'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Celebration
        if (celebrate) const Positioned.fill(child: ConfettiOverlay()),
      ],
    );
  }
}