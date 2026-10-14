import 'dart:async';
import 'dart:math';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/question.dart';
import '../models/user_model.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';

enum SoloPhase { loading, question, reveal, finished, error }

class SoloState extends Equatable {
  final SoloPhase phase;
  final String? error;
  final List<Question> questions;
  final int index;
  final int? selected; // my choice on this question (null = not answered)
  final bool botAnswered; // the bot has answered (its choice stays hidden)
  final int? botSelected; // known only at the reveal (-1 = did not answer)
  final int myQPoints; // points on this question (set at the reveal)
  final int botQPoints;
  final int myScore;
  final int botScore;
  final int myCorrect;
  final bool bonusAwarded;

  const SoloState({
    this.phase = SoloPhase.loading,
    this.error,
    this.questions = const [],
    this.index = 0,
    this.selected,
    this.botAnswered = false,
    this.botSelected,
    this.myQPoints = 0,
    this.botQPoints = 0,
    this.myScore = 0,
    this.botScore = 0,
    this.myCorrect = 0,
    this.bonusAwarded = false,
  });

  SoloState copyWith({
    SoloPhase? phase,
    String? error,
    int? selected,
    bool? botAnswered,
    int? botSelected,
    int? myQPoints,
    int? botQPoints,
    int? myScore,
    int? botScore,
    int? myCorrect,
    bool? bonusAwarded,
  }) =>
      SoloState(
        phase: phase ?? this.phase,
        error: error ?? this.error,
        questions: questions,
        index: index,
        selected: selected ?? this.selected,
        botAnswered: botAnswered ?? this.botAnswered,
        botSelected: botSelected ?? this.botSelected,
        myQPoints: myQPoints ?? this.myQPoints,
        botQPoints: botQPoints ?? this.botQPoints,
        myScore: myScore ?? this.myScore,
        botScore: botScore ?? this.botScore,
        myCorrect: myCorrect ?? this.myCorrect,
        bonusAwarded: bonusAwarded ?? this.bonusAwarded,
      );

  @override
  List<Object?> get props => [
    phase,
    error,
    questions,
    index,
    selected,
    botAnswered,
    botSelected,
    myQPoints,
    botQPoints,
    myScore,
    botScore,
    myCorrect,
    bonusAwarded,
  ];
}

class SoloCubit extends Cubit<SoloState> {
  final AIService ai;
  final FirestoreService db;
  final UserModel user;
  final String topic;
  final String difficulty;
  final int count;
  final String? dailyKey; // set = this is the Daily Challenge

  final Random _rand = Random();
  final Stopwatch _clock = Stopwatch();
  Timer? _questionTimer;
  Timer? _revealTimer;
  Timer? _botTimer;

  // The bot's plan for the current question (hidden until the reveal).
  int _botChoice = -1;
  int _botPoints = 0;
  int _myPoints = 0;

  SoloCubit({
    required this.ai,
    required this.db,
    required this.user,
    required this.topic,
    required this.difficulty,
    required this.count,
    this.dailyKey,
  }) : super(const SoloState()) {
    _load();
  }

  // ---------------------------------------------------------------
  // Loading the quiz
  // ---------------------------------------------------------------

  Future<void> _load() async {
    try {
      final questions = dailyKey != null
          ? await _loadDaily()
          : await ai.generateQuiz(
        topic: topic,
        difficulty: difficulty,
        count: count,
      );
      if (isClosed) return;
      _startQuestion(0, questions);
    } catch (e) {
      if (isClosed) return;
      emit(SoloState(
        phase: SoloPhase.error,
        error: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  /// Everyone gets the same daily quiz. The first player creates it.
  Future<List<Question>> _loadDaily() async {
    final saved = await db.getDailyQuestions(dailyKey!);
    if (saved != null && saved.length >= count) {
      return saved.take(count).toList();
    }
    final questions = await ai.generateQuiz(
      topic: topic,
      difficulty: difficulty,
      count: count,
    );
    try {
      await db.saveDailyQuestions(dailyKey!, topic, questions);
    } catch (e) {
      debugPrint('Could not save the daily quiz: $e');
    }
    return questions;
  }

  void retry() {
    emit(const SoloState());
    _load();
  }

  // ---------------------------------------------------------------
  // The game loop
  // ---------------------------------------------------------------

  int _pointsFor(int elapsedMs) {
    final totalMs = kQuestionSeconds * 1000;
    return kBasePoints +
        (((totalMs - elapsedMs) / totalMs) * kSpeedBonus).round();
  }

  void _startQuestion(int i, List<Question> questions) {
    _cancelTimers();
    _myPoints = 0;
    final q = questions[i];
    final totalMs = kQuestionSeconds * 1000;

    // Plan the bot's answer: how long it thinks and what it picks.
    final range = kBotDelay[difficulty] ?? kBotDelay['Medium']!;
    final delaySec = range[0] + _rand.nextDouble() * (range[1] - range[0]);
    final delayMs =
    (delaySec * 1000).round().clamp(1000, totalMs - 1500).toInt();

    final accuracy = kBotAccuracy[difficulty] ?? 0.7;
    final botCorrect = _rand.nextDouble() < accuracy;
    if (botCorrect) {
      _botChoice = q.correctIndex;
    } else {
      final wrong = [0, 1, 2, 3]..remove(q.correctIndex);
      _botChoice = wrong[_rand.nextInt(wrong.length)];
    }
    _botPoints = botCorrect ? _pointsFor(delayMs) : 0;

    emit(SoloState(
      phase: SoloPhase.question,
      questions: questions,
      index: i,
      myScore: state.myScore,
      botScore: state.botScore,
      myCorrect: state.myCorrect,
    ));

    _clock
      ..reset()
      ..start();
    _questionTimer = Timer(
      const Duration(seconds: kQuestionSeconds),
      _reveal,
    );
    _botTimer = Timer(Duration(milliseconds: delayMs), _onBotAnswered);
  }

  void _onBotAnswered() {
    if (isClosed || state.phase != SoloPhase.question) return;
    emit(state.copyWith(botAnswered: true));
    _checkBoth();
  }

  void submitAnswer(int choice) {
    if (state.phase != SoloPhase.question || state.selected != null) return;

    final q = state.questions[state.index];
    final totalMs = kQuestionSeconds * 1000;
    final elapsed = _clock.elapsedMilliseconds.clamp(0, totalMs).toInt();
    _myPoints = choice == q.correctIndex ? _pointsFor(elapsed) : 0;

    emit(state.copyWith(selected: choice));
    _checkBoth();
  }

  /// Both of us answered: no need to wait for the timer.
  void _checkBoth() {
    if (state.selected != null && state.botAnswered) _reveal();
  }

  void _reveal() {
    if (isClosed || state.phase != SoloPhase.question) return;
    _questionTimer?.cancel();
    _botTimer?.cancel();

    final q = state.questions[state.index];
    final botQ = state.botAnswered ? _botPoints : 0;
    final iWasCorrect = state.selected == q.correctIndex;

    emit(state.copyWith(
      phase: SoloPhase.reveal,
      botSelected: state.botAnswered ? _botChoice : -1,
      myQPoints: _myPoints,
      botQPoints: botQ,
      myScore: state.myScore + _myPoints,
      botScore: state.botScore + botQ,
      myCorrect: state.myCorrect + (iWasCorrect ? 1 : 0),
    ));

    _revealTimer = Timer(const Duration(seconds: kRevealSeconds), _next);
  }

  void _next() {
    if (isClosed) return;
    final next = state.index + 1;
    if (next < state.questions.length) {
      _startQuestion(next, state.questions);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    var bonus = false;
    if (dailyKey != null) {
      try {
        bonus = await db.claimDailyBonus(user.uid, dailyKey!, kDailyBonus);
      } catch (e) {
        debugPrint('Could not give the daily bonus: $e');
      }
    }
    if (isClosed) return;
    emit(state.copyWith(phase: SoloPhase.finished, bonusAwarded: bonus));
  }

  void _cancelTimers() {
    _questionTimer?.cancel();
    _revealTimer?.cancel();
    _botTimer?.cancel();
  }

  @override
  Future<void> close() {
    _cancelTimers();
    return super.close();
  }
}