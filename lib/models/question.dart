class Question {
  final String text;
  final List<String> options; // exactly 4
  final int correctIndex;     // 0..3
  final String explanation;

  const Question({
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  Map<String, dynamic> toMap() => {
    'question': text,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
  };

  factory Question.fromMap(Map<String, dynamic> map) => Question(
    text: (map['question'] ?? '').toString(),
    options: List<String>.from(
      (map['options'] ?? []).map((o) => o.toString()),
    ),
    // num -> int is safer in case the AI returns 2.0 instead of 2
    correctIndex: (map['correctIndex'] as num?)?.toInt() ?? 0,
    explanation: (map['explanation'] ?? '').toString(),
  );
}