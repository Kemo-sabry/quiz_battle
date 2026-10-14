class Answer {
  final String uid;
  final int questionIndex;
  final int selectedIndex; // -1 = no answer (time ran out)
  final bool isCorrect;
  final int timeTakenMs;
  final int points;

  const Answer({
    required this.uid,
    required this.questionIndex,
    required this.selectedIndex,
    required this.isCorrect,
    required this.timeTakenMs,
    required this.points,
  });

  /// Used as the document ID so a player can't answer the same question twice.
  String get docId => '${uid}_$questionIndex';

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'questionIndex': questionIndex,
    'selectedIndex': selectedIndex,
    'isCorrect': isCorrect,
    'timeTakenMs': timeTakenMs,
    'points': points,
  };

  factory Answer.fromMap(Map<String, dynamic> map) => Answer(
    uid: (map['uid'] ?? '').toString(),
    questionIndex: (map['questionIndex'] as num?)?.toInt() ?? 0,
    selectedIndex: (map['selectedIndex'] as num?)?.toInt() ?? -1,
    isCorrect: map['isCorrect'] ?? false,
    timeTakenMs: (map['timeTakenMs'] as num?)?.toInt() ?? 0,
    points: (map['points'] as num?)?.toInt() ?? 0,
  );
}