import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/results_cubit.dart';
import '../models/user_model.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../widgets/results_view.dart';
import 'lobby_screen.dart';

class ResultsScreen extends StatelessWidget {
  final String roomId;
  final UserModel user;

  const ResultsScreen({super.key, required this.roomId, required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ResultsCubit(FirestoreService(), AIService(), roomId, user),
      child: _ResultsBody(user: user),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  final UserModel user;
  const _ResultsBody({required this.user});

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ResultsCubit, ResultsState>(
      listenWhen: (prev, curr) =>
      prev.openRoomId != curr.openRoomId ||
          prev.playAgainError != curr.playAgainError,
      listener: (context, state) {
        if (state.openRoomId != null) {
          // The rematch lobby is ready.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  LobbyScreen(roomId: state.openRoomId!, user: user),
            ),
          );
        } else if (state.playAgainError != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.playAgainError!),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 8),
            ));
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Battle Complete'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(child: _content(context, state)),
        );
      },
    );
  }

  Widget _content(BuildContext context, ResultsState state) {
    if (state.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Calculating results...'),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _goHome(context),
                child: const Text('Home'),
              ),
            ],
          ),
        ),
      );
    }

    return ResultsView(
      entries: state.entries,
      myUid: user.uid,
      winnerTitle: state.winnerTitle,
      celebrate: state.celebrate,
      correctCount: state.correct,
      totalQuestions: state.total,
      pointsEarned: state.points,
      playAgainLoading: state.playAgainLoading,
      onPlayAgain: () => context.read<ResultsCubit>().playAgain(),
      onHome: () => _goHome(context),
    );
  }
}