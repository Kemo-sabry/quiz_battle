import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/answer.dart';
import '../models/battle_room.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';

class ArenaState extends Equatable {
  final bool loading;
  final BattleRoom? room;
  final List<Answer> answers;
  final bool finished; // the battle is over
  final bool closed; // the room was deleted
  final String? error;

  const ArenaState({
    this.loading = true,
    this.room,
    this.answers = const [],
    this.finished = false,
    this.closed = false,
    this.error,
  });

  ArenaState copyWith({
    bool? loading,
    BattleRoom? room,
    List<Answer>? answers,
    bool? finished,
    bool? closed,
    String? error,
  }) =>
      ArenaState(
        loading: loading ?? this.loading,
        room: room ?? this.room,
        answers: answers ?? this.answers,
        finished: finished ?? this.finished,
        closed: closed ?? this.closed,
        error: error ?? this.error,
      );

  /// A player's answer for one question (null = not answered).
  Answer? answerOf(String uid, int questionIndex) {
    for (final a in answers) {
      if (a.uid == uid && a.questionIndex == questionIndex) return a;
    }
    return null;
  }

  /// Who has answered the given question.
  Set<String> answeredUids(int questionIndex) => answers
      .where((a) => a.questionIndex == questionIndex)
      .map((a) => a.uid)
      .toSet();

  /// Points each player earned on one question.
  Map<String, int> pointsFor(int questionIndex) => {
    for (final a in answers.where((a) => a.questionIndex == questionIndex))
      a.uid: a.points,
  };

  /// Scores shown on the scoreboard. The current question only counts
  /// after the reveal, so nobody can see who got it right too early.
  Map<String, int> visibleScores() {
    final r = room;
    if (r == null) return {};
    final revealed = r.phase == kPhaseReveal;
    final idx = r.currentQuestionIndex;
    final scores = <String, int>{};
    for (final a in answers) {
      final counts =
          a.questionIndex < idx || (a.questionIndex == idx && revealed);
      if (counts) scores[a.uid] = (scores[a.uid] ?? 0) + a.points;
    }
    return scores;
  }

  @override
  List<Object?> get props => [loading, room, answers, finished, closed, error];
}

class ArenaCubit extends Cubit<ArenaState> {
  final FirestoreService _db;
  final String roomId;
  final UserModel _user;

  StreamSubscription<BattleRoom?>? _roomSub;
  StreamSubscription<List<Answer>>? _answersSub;
  Timer? _questionTimer; // ends the question when time runs out
  Timer? _revealTimer; // ends the reveal after 3 seconds
  final Stopwatch _clock = Stopwatch(); // measures how fast I answered

  int? _timedIndex; // question whose timer is running
  int? _revealIndex; // question whose reveal timer is running
  int? _revealRequestedFor;
  int? _submittingFor;

  ArenaCubit(this._db, this.roomId, this._user) : super(const ArenaState()) {
    _roomSub = _db.watchRoom(roomId).listen(
      _onRoom,
      onError: (e) =>
          emit(state.copyWith(loading: false, error: e.toString())),
    );
    _answersSub = _db.watchAnswers(roomId).listen(
      _onAnswers,
      onError: (_) {},
    );
  }

  // ---------------------------------------------------------------
  // Reacting to Firestore
  // ---------------------------------------------------------------

  void _onRoom(BattleRoom? room) {
    if (room == null) {
      emit(state.copyWith(loading: false, closed: true));
      return;
    }

    if (room.status == RoomStatus.finished) {
      _questionTimer?.cancel();
      _revealTimer?.cancel();
      emit(state.copyWith(loading: false, room: room, finished: true));
      return;
    }

    emit(state.copyWith(loading: false, room: room));

    final idx = room.currentQuestionIndex;

    if (room.phase == kPhaseQuestion) {
      // A new question just started: start my timers.
      if (_timedIndex != idx) {
        _timedIndex = idx;
        _revealRequestedFor = null;
        _submittingFor = null;
        _clock
          ..reset()
          ..start();
        _questionTimer?.cancel();
        _questionTimer = Timer(
          const Duration(seconds: kQuestionSeconds),
              () => _requestReveal(idx),
        );
      }
      _checkAllAnswered();
    } else {
      // Reveal phase: show the result, then move on after 3 seconds.
      _questionTimer?.cancel();
      if (_revealIndex != idx) {
        _revealIndex = idx;
        _revealTimer?.cancel();
        _revealTimer = Timer(
          const Duration(seconds: kRevealSeconds),
              () => _requestAdvance(idx),
        );
      }
    }
  }

  void _onAnswers(List<Answer> answers) {
    emit(state.copyWith(answers: answers));
    _checkAllAnswered();
  }

  /// If everyone answered, don't wait for the timer.
  void _checkAllAnswered() {
    final room = state.room;
    if (room == null || room.phase != kPhaseQuestion) return;
    if (room.players.isEmpty) return;

    final idx = room.currentQuestionIndex;
    final answered = state.answeredUids(idx);
    final allIn = room.players.every((p) => answered.contains(p.uid));
    if (allIn) _requestReveal(idx);
  }

  Future<void> _requestReveal(int idx) async {
    if (isClosed || _revealRequestedFor == idx) return;
    _revealRequestedFor = idx;
    try {
      await _db.moveToReveal(roomId, idx);
    } catch (_) {
      _revealRequestedFor = null; // allow another try
    }
  }

  Future<void> _requestAdvance(int idx) async {
    if (isClosed) return;

    // Total points per player, in case this is the last question.
    final scores = <String, int>{};
    for (final a in state.answers) {
      scores[a.uid] = (scores[a.uid] ?? 0) + a.points;
    }

    try {
      await _db.advanceQuestion(roomId, idx, scores);
    } catch (_) {
      // Network hiccup: try again in 2 seconds.
      if (!isClosed && _revealIndex == idx) {
        _revealTimer = Timer(
          const Duration(seconds: 2),
              () => _requestAdvance(idx),
        );
      }
    }
  }

  // ---------------------------------------------------------------
  // Actions from the screen
  // ---------------------------------------------------------------

  Future<void> submitAnswer(int selectedIndex) async {
    final room = state.room;
    if (room == null || room.phase != kPhaseQuestion) return;

    final idx = room.currentQuestionIndex;
    if (state.answerOf(_user.uid, idx) != null) return; // already answered
    if (_submittingFor == idx) return; // double tap
    _submittingFor = idx;

    final question = room.questions[idx];
    final totalMs = kQuestionSeconds * 1000;
    final elapsed = _clock.elapsedMilliseconds.clamp(0, totalMs).toInt();
    final correct = selectedIndex == question.correctIndex;
    final points = correct
        ? kBasePoints + (((totalMs - elapsed) / totalMs) * kSpeedBonus).round()
        : 0;

    try {
      await _db.submitAnswer(
        roomId,
        Answer(
          uid: _user.uid,
          questionIndex: idx,
          selectedIndex: selectedIndex,
          isCorrect: correct,
          timeTakenMs: elapsed,
          points: points,
        ),
      );
    } catch (_) {
      _submittingFor = null; // let the player tap again
    }
  }

  Future<void> leave() async {
    // Stop listening first so leaving doesn't trigger our own listeners.
    _roomSub?.cancel();
    _answersSub?.cancel();
    _questionTimer?.cancel();
    _revealTimer?.cancel();
    await _db.leaveRoom(roomId, _user.uid);
  }

  @override
  Future<void> close() {
    _roomSub?.cancel();
    _answersSub?.cancel();
    _questionTimer?.cancel();
    _revealTimer?.cancel();
    return super.close();
  }
}