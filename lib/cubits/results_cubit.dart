import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/battle_room.dart';
import '../models/player.dart';
import '../models/result_entry.dart';
import '../models/user_model.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';

class ResultsState extends Equatable {
  final bool loading;
  final String? error;
  final List<ResultEntry> entries;
  final int correct;
  final int total;
  final int points;
  final String winnerTitle;
  final bool celebrate;
  final bool playAgainLoading;
  final String? playAgainError;
  final String? openRoomId; // set when a rematch lobby is ready

  const ResultsState({
    this.loading = true,
    this.error,
    this.entries = const [],
    this.correct = 0,
    this.total = 0,
    this.points = 0,
    this.winnerTitle = '',
    this.celebrate = false,
    this.playAgainLoading = false,
    this.playAgainError,
    this.openRoomId,
  });

  // error, playAgainError and openRoomId are replaced on every copy.
  ResultsState copyWith({
    bool? loading,
    String? error,
    List<ResultEntry>? entries,
    int? correct,
    int? total,
    int? points,
    String? winnerTitle,
    bool? celebrate,
    bool? playAgainLoading,
    String? playAgainError,
    String? openRoomId,
  }) =>
      ResultsState(
        loading: loading ?? this.loading,
        error: error,
        entries: entries ?? this.entries,
        correct: correct ?? this.correct,
        total: total ?? this.total,
        points: points ?? this.points,
        winnerTitle: winnerTitle ?? this.winnerTitle,
        celebrate: celebrate ?? this.celebrate,
        playAgainLoading: playAgainLoading ?? this.playAgainLoading,
        playAgainError: playAgainError,
        openRoomId: openRoomId,
      );

  @override
  List<Object?> get props => [
    loading,
    error,
    entries,
    correct,
    total,
    points,
    winnerTitle,
    celebrate,
    playAgainLoading,
    playAgainError,
    openRoomId,
  ];
}

class ResultsCubit extends Cubit<ResultsState> {
  final FirestoreService _db;
  final AIService _ai;
  final String roomId;
  final UserModel _user;
  BattleRoom? _room;

  ResultsCubit(this._db, this._ai, this.roomId, this._user)
      : super(const ResultsState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final room = await _db.getRoom(roomId);
      if (room == null) {
        emit(state.copyWith(loading: false, error: 'This battle no longer exists.'));
        return;
      }
      _room = room;

      // Everything is calculated from the saved answers.
      final answers = await _db.getAnswers(roomId);
      final scoreOf = <String, int>{};
      for (final a in answers) {
        scoreOf[a.uid] = (scoreOf[a.uid] ?? 0) + a.points;
      }

      final entries = room.players
          .map((p) => ResultEntry(
        uid: p.uid,
        name: p.name,
        photoUrl: p.photoUrl,
        score: scoreOf[p.uid] ?? 0,
      ))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      final top = entries.isEmpty ? 0 : entries.first.score;
      final winners =
      top > 0 ? entries.where((e) => e.score == top).toList() : <ResultEntry>[];
      final iWon = winners.any((e) => e.uid == _user.uid);

      String title;
      if (winners.isEmpty) {
        title = 'No winner this time';
      } else if (winners.length > 1) {
        title = iWon ? "It's a tie! You share the win 🤝" : "It's a tie!";
      } else if (iWon) {
        title = 'You win! 🎉';
      } else {
        title = '${winners.first.name} wins!';
      }

      final mine = answers.where((a) => a.uid == _user.uid).toList();
      final myPoints = scoreOf[_user.uid] ?? 0;

      emit(state.copyWith(
        loading: false,
        entries: entries,
        correct: mine.where((a) => a.isCorrect).length,
        total: room.questions.length,
        points: myPoints,
        winnerTitle: title,
        celebrate: winners.isNotEmpty,
      ));

      // Save my stats (once per battle).
      if (room.players.any((p) => p.uid == _user.uid)) {
        try {
          await _db.applyBattleResult(
            roomId: roomId,
            uid: _user.uid,
            points: myPoints,
            won: iWon,
          );
        } catch (e) {
          debugPrint('Could not save stats: $e');
        }
      }
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  // ---------------------------------------------------------------
  // PLAY AGAIN
  // ---------------------------------------------------------------

  Player get _me => Player(
    uid: _user.uid,
    name: _user.displayName,
    photoUrl: _user.photoUrl,
    isReady: true,
  );

  Future<void> playAgain() async {
    final room = _room;
    if (room == null || state.playAgainLoading) return;
    emit(state.copyWith(playAgainLoading: true));

    try {
      // Someone already started the rematch: just join it.
      final existing = await _db.getNextRoomId(roomId);
      if (existing != null) {
        await _joinRematch(existing);
        return;
      }

      // Otherwise create it: same settings, brand new questions.
      final questions = await _ai.generateQuiz(
        topic: room.topic,
        difficulty: room.difficulty,
        count: room.questionCount,
      );
      final code = room.isPublic ? null : await _db.generateUniqueRoomCode();

      final newRoom = BattleRoom(
        id: '',
        name: room.name,
        hostId: _user.uid,
        hostName: _user.displayName,
        topic: room.topic,
        difficulty: room.difficulty,
        questionCount: room.questionCount,
        maxPlayers: room.maxPlayers,
        isPublic: room.isPublic,
        roomCode: code,
        players: [_me],
        questions: questions,
      );
      final newId = await _db.createRoom(newRoom);

      // If two players tapped at the same time, only one rematch survives.
      final chosen = await _db.claimRematch(roomId, newId);
      if (chosen != newId) {
        await _db.deleteRoom(newId);
        await _joinRematch(chosen);
        return;
      }

      if (isClosed) return;
      emit(state.copyWith(openRoomId: newId));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        playAgainLoading: false,
        playAgainError: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _joinRematch(String rematchId) async {
    await _db.joinRoom(rematchId, _me);
    if (isClosed) return;
    emit(state.copyWith(openRoomId: rematchId));
  }
}