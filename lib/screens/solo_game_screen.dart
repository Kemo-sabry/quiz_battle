import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/solo_cubit.dart';
import '../models/answer.dart';
import '../models/player.dart';
import '../models/question.dart';
import '../models/result_entry.dart';
import '../models/user_model.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../widgets/answer_button.dart';
import '../widgets/players_panel.dart';
import '../widgets/results_view.dart';
import '../widgets/reveal_banner.dart';
import '../widgets/timer_bar.dart';

class SoloGameScreen extends StatelessWidget {
  final UserModel user;
  final String topic;
  final String difficulty;
  final int questionCount;
  final String? dailyKey; // set = Daily Challenge

  const SoloGameScreen({
    super.key,
    required this.user,
    required this.topic,
    required this.difficulty,
    required this.questionCount,
    this.dailyKey,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SoloCubit(
        ai: AIService(),
        db: FirestoreService(),
        user: user,
        topic: topic,
        difficulty: difficulty,
        count: questionCount,
        dailyKey: dailyKey,
      ),
      child: _SoloBody(screen: this),
    );
  }
}

class _SoloBody extends StatelessWidget {
  final SoloGameScreen screen;
  const _SoloBody({required this.screen});

  UserModel get _user => screen.user;
  bool get _isDaily => screen.dailyKey != null;

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the game?'),
        content: const Text('Your progress will be lost.'),
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
    if (leave == true && context.mounted) _goHome(context);
  }

  void _playAgain(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SoloGameScreen(
          user: screen.user,
          topic: screen.topic,
          difficulty: screen.difficulty,
          questionCount: screen.questionCount,
          dailyKey: screen.dailyKey,
        ),
      ),
    );
  }

  AnswerVisual _visualFor(int n, int correctIndex, bool reveal, int? mine) {
    if (reveal) {
      if (n == correctIndex) return AnswerVisual.correct;
      if (mine == n) return AnswerVisual.wrong;
      return AnswerVisual.dimmed;
    }
    if (mine != null) {
      return mine == n ? AnswerVisual.selected : AnswerVisual.dimmed;
    }
    return AnswerVisual.idle;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SoloCubit, SoloState>(
      builder: (context, state) {
        final phase = state.phase;
        final inGame =
            phase == SoloPhase.question || phase == SoloPhase.reveal;
        final finished = phase == SoloPhase.finished;

        return PopScope(
          canPop: !inGame && !finished,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (finished) {
              _goHome(context);
            } else {
              _confirmLeave(context);
            }
          },
          child: Scaffold(
            appBar: _appBar(context, state),
            body: SafeArea(child: _body(context, state)),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, SoloState state) {
    final phase = state.phase;
    if (phase == SoloPhase.question || phase == SoloPhase.reveal) {
      return AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          '${_isDaily ? 'Daily • ' : ''}Question ${state.index + 1} of ${state.questions.length}',
        ),
        actions: [
          const Icon(Icons.star_rounded, color: Colors.amber),
          const SizedBox(width: 4),
          AnimatedScore(
            value: state.myScore,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            tooltip: 'Leave',
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => _confirmLeave(context),
          ),
        ],
      );
    }
    return AppBar(
      title: Text(phase == SoloPhase.finished
          ? 'Game Complete'
          : (_isDaily ? 'Daily Challenge' : 'Solo Practice')),
      automaticallyImplyLeading: phase != SoloPhase.finished,
    );
  }

  Widget _body(BuildContext context, SoloState state) {
    switch (state.phase) {
      case SoloPhase.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_isDaily
                  ? 'Getting the Daily Challenge...'
                  : 'AI is writing your quiz...'),
              const SizedBox(height: 4),
              const Text('This can take up to a minute.'),
            ],
          ),
        );

      case SoloPhase.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.error ?? 'Something went wrong.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.read<SoloCubit>().retry(),
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: () => _goHome(context),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        );

      case SoloPhase.finished:
        return _results(context, state);

      case SoloPhase.question:
      case SoloPhase.reveal:
        return _game(context, state);
    }
  }

  // ---------------------------------------------------------------
  // The question screen (same look as the multiplayer Arena)
  // ---------------------------------------------------------------

  Widget _game(BuildContext context, SoloState state) {
    final theme = Theme.of(context);
    final Question q = state.questions[state.index];
    final reveal = state.phase == SoloPhase.reveal;

    final me = Player(
      uid: _user.uid,
      name: _user.displayName,
      photoUrl: _user.photoUrl,
    );
    const bot = Player(uid: kBotUid, name: kBotName);

    final myAnswer = state.selected == null
        ? null
        : Answer(
      uid: _user.uid,
      questionIndex: state.index,
      selectedIndex: state.selected!,
      isCorrect: state.selected == q.correctIndex,
      timeTakenMs: 0,
      points: state.myQPoints,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TimerBar(
              key: ValueKey('solo_timer_${state.index}'),
              seconds: kQuestionSeconds,
              running: !reveal,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(q.text, style: theme.textTheme.titleLarge),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(4, (n) {
              return AnswerButton(
                letter: 'ABCD'[n],
                text: q.options[n],
                visual: _visualFor(n, q.correctIndex, reveal, state.selected),
                onTap: (reveal || state.selected != null)
                    ? null
                    : () => context.read<SoloCubit>().submitAnswer(n),
              );
            }),
            if (reveal) ...[
              RevealBanner(
                key: ValueKey('solo_reveal_${state.index}'),
                answer: myAnswer,
                explanation: q.explanation,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(child: _botLine(state, q)),
              ),
            ],
            const SizedBox(height: 8),
            PlayersPanel(
              players: [me, bot],
              scores: {_user.uid: state.myScore, kBotUid: state.botScore},
              answered: {
                if (state.selected != null) _user.uid,
                if (state.botAnswered) kBotUid,
              },
              questionPoints: {
                _user.uid: state.myQPoints,
                kBotUid: state.botQPoints,
              },
              reveal: reveal,
              myUid: _user.uid,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _botLine(SoloState state, Question q) {
    final chose = state.botSelected;
    final String text;
    if (chose == null || chose < 0) {
      text = '$kBotName did not answer in time';
    } else {
      final ok = chose == q.correctIndex;
      text =
      '$kBotName chose ${'ABCD'[chose]}: ${ok ? 'correct ✅' : 'wrong ❌'}';
    }
    return Text(text, style: const TextStyle(fontStyle: FontStyle.italic));
  }

  // ---------------------------------------------------------------
  // The results (same ResultsView as the multiplayer battle)
  // ---------------------------------------------------------------

  Widget _results(BuildContext context, SoloState state) {
    final my = state.myScore;
    final botScore = state.botScore;

    final entries = [
      ResultEntry(
        uid: _user.uid,
        name: _user.displayName,
        photoUrl: _user.photoUrl,
        score: my,
      ),
      ResultEntry(uid: kBotUid, name: kBotName, score: botScore),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final String title;
    final bool celebrate;
    if (my == 0 && botScore == 0) {
      title = 'No winner this time';
      celebrate = false;
    } else if (my > botScore) {
      title = 'You beat the bot! 🎉';
      celebrate = true;
    } else if (my == botScore) {
      title = "It's a tie! 🤝";
      celebrate = true;
    } else {
      title = 'The bot wins this time 🤖';
      celebrate = false;
    }

    return Column(
      children: [
        if (_isDaily)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepOrange),
            ),
            child: Text(
              state.bonusAwarded
                  ? '🔥 Daily Challenge complete! +$kDailyBonus bonus points'
                  : 'Daily Challenge complete! You already claimed today\'s bonus.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        Expanded(
          child: ResultsView(
            entries: entries,
            myUid: _user.uid,
            winnerTitle: title,
            celebrate: celebrate,
            correctCount: state.myCorrect,
            totalQuestions: state.questions.length,
            pointsEarned: my,
            playAgainLoading: false,
            onPlayAgain: () => _playAgain(context),
            onHome: () => _goHome(context),
          ),
        ),
      ],
    );
  }
}