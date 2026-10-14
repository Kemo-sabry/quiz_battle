import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/arena_cubit.dart';
import '../models/answer.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../widgets/answer_button.dart';
import '../widgets/players_panel.dart';
import '../widgets/reveal_banner.dart';
import '../widgets/timer_bar.dart';
import 'results_screen.dart';

class ArenaScreen extends StatelessWidget {
  final String roomId;
  final UserModel user;

  const ArenaScreen({super.key, required this.roomId, required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ArenaCubit(FirestoreService(), roomId, user),
      child: _ArenaView(roomId: roomId, user: user),
    );
  }
}

class _ArenaView extends StatelessWidget {
  final String roomId;
  final UserModel user;

  const _ArenaView({required this.roomId, required this.user});

  Future<void> _confirmLeave(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the battle?'),
        content: const Text('You will lose your progress in this battle.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave != true || !context.mounted) return;
    try {
      await context.read<ArenaCubit>().leave();
    } catch (_) {}
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  AnswerVisual _visualFor(
      int n,
      int correctIndex,
      bool reveal,
      Answer? mine,
      ) {
    if (reveal) {
      if (n == correctIndex) return AnswerVisual.correct;
      if (mine?.selectedIndex == n) return AnswerVisual.wrong;
      return AnswerVisual.dimmed;
    }
    if (mine != null) {
      return mine.selectedIndex == n
          ? AnswerVisual.selected
          : AnswerVisual.dimmed;
    }
    return AnswerVisual.idle;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ArenaCubit, ArenaState>(
      listenWhen: (prev, curr) =>
      prev.finished != curr.finished || prev.closed != curr.closed,
      listener: (context, state) {
        if (state.finished) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultsScreen(roomId: roomId, user: user),
            ),
          );
        } else if (state.closed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This room was closed.')),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      builder: (context, state) {
        final room = state.room;

        if (state.error != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Battle')),
            body: Center(child: Text('Error: ${state.error}')),
          );
        }
        if (state.loading ||
            room == null ||
            room.currentQuestionIndex >= room.questions.length) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final idx = room.currentQuestionIndex;
        final question = room.questions[idx];
        final reveal = room.phase == kPhaseReveal;
        final mine = state.answerOf(user.uid, idx);
        final scores = state.visibleScores();
        final theme = Theme.of(context);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave(context);
          },
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text('Question ${idx + 1} of ${room.questions.length}'),
              actions: [
                const Icon(Icons.star_rounded, color: Colors.amber),
                const SizedBox(width: 4),
                AnimatedScore(
                  value: scores[user.uid] ?? 0,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: 'Leave battle',
                  icon: const Icon(Icons.exit_to_app),
                  onPressed: () => _confirmLeave(context),
                ),
              ],
            ),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Timer
                      TimerBar(
                        key: ValueKey('timer_$idx'),
                        seconds: kQuestionSeconds,
                        running: !reveal,
                      ),
                      const SizedBox(height: 16),

                      // Question
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            question.text,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Four answers
                      ...List.generate(4, (n) {
                        return AnswerButton(
                          letter: 'ABCD'[n],
                          text: question.options[n],
                          visual: _visualFor(
                              n, question.correctIndex, reveal, mine),
                          onTap: (reveal || mine != null)
                              ? null
                              : () =>
                              context.read<ArenaCubit>().submitAnswer(n),
                        );
                      }),

                      // Result + AI explanation (reveal phase only)
                      if (reveal)
                        RevealBanner(
                          key: ValueKey('reveal_$idx'),
                          answer: mine,
                          explanation: question.explanation,
                        ),

                      const SizedBox(height: 8),

                      // Scoreboard + answered/thinking indicators
                      PlayersPanel(
                        players: room.players,
                        scores: scores,
                        answered: state.answeredUids(idx),
                        questionPoints: state.pointsFor(idx),
                        reveal: reveal,
                        myUid: user.uid,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}