import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/question.dart';

/// Change this one line if Firebase ever says "model not found".
const String kGeminiModel = 'gemini-3.1-flash-lite';

/// One study link returned by the tool.
class StudyResource {
  final String title;
  final String url;
  final String type; // video | article | course

  const StudyResource({
    required this.title,
    required this.url,
    required this.type,
  });

  Map<String, Object?> toMap() => {'title': title, 'url': url, 'type': type};
}

/// What the "Learn more" feature returns to the UI.
class StudyHelp {
  final String message; // Gemini's short friendly summary
  final List<StudyResource> resources; // links from our tool
  const StudyHelp({required this.message, required this.resources});
}

class AIService {
  // ---------------------------------------------------------------
  // 1) QUIZ GENERATION (JSON mode + response schema)
  // ---------------------------------------------------------------
  late final GenerativeModel _quizModel =
  FirebaseAI.googleAI().generativeModel(
    model: kGeminiModel,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.array(
        items: Schema.object(
          properties: {
            'question': Schema.string(),
            'options': Schema.array(items: Schema.string()),
            'correctIndex': Schema.integer(),
            'explanation': Schema.string(),
          },
        ),
      ),
    ),
  );

  Future<List<Question>> generateQuiz({
    required String topic,
    required String difficulty,
    required int count,
  }) async {
    final prompt = '''
Generate exactly $count multiple-choice quiz questions.
Topic: $topic
Difficulty: $difficulty

Rules:
- Each question has exactly 4 answer options.
- Exactly one option is correct. "correctIndex" is its position (0 to 3).
- Spread the correct answers across different positions. Do not always use the same index.
- All questions must be factually accurate, clear, and different from each other.
- "explanation" is 1 or 2 short sentences explaining why the answer is correct.
- Match the difficulty: Easy = common knowledge, Medium = needs some study, Hard = detailed or tricky.
''';

    Object? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await _quizModel.generateContent([
          Content.text(prompt),
        ]);
        return _parseQuestions(response.text, count);
      } catch (e) {
        lastError = e; // try once more, then give up
      }
    }
    throw Exception('Quiz generation failed: $lastError');
  }

  List<Question> _parseQuestions(String? raw, int count) {
    if (raw == null || raw.trim().isEmpty) {
      throw const FormatException('Empty response from AI');
    }

    // Safety: remove ```json fences if the model adds them.
    final cleaned =
    raw.replaceAll('```json', '').replaceAll('```', '').trim();

    final decoded = jsonDecode(cleaned);
    if (decoded is! List) {
      throw const FormatException('AI did not return a list');
    }

    final questions = <Question>[];
    for (final item in decoded) {
      final q = Question.fromMap(Map<String, dynamic>.from(item as Map));
      final valid = q.text.trim().isNotEmpty &&
          q.options.length == 4 &&
          q.correctIndex >= 0 &&
          q.correctIndex <= 3;
      if (valid) questions.add(q);
    }

    if (questions.length < count) {
      throw FormatException(
          'Only ${questions.length} valid questions, needed $count');
    }
    return questions.take(count).toList();
  }

  // ---------------------------------------------------------------
  // 2) FUNCTION CALLING: Educational Resource Finder (Option A)
  // ---------------------------------------------------------------

  // Step A: describe the tool to Gemini (name, purpose, inputs).
  late final FunctionDeclaration _resourceFinderDecl = FunctionDeclaration(
    'findStudyResources',
    'Finds study materials (videos and articles) about a topic so a '
        'player can learn more.',
    parameters: {
      'topic': Schema.string(
        description: 'The specific subject to find study materials for.',
      ),
    },
  );

  // Function calling and JSON mode are separate on purpose:
  // this model has the tool, the quiz model has the JSON schema.
  late final GenerativeModel _toolModel = FirebaseAI.googleAI().generativeModel(
    model: kGeminiModel,
    tools: [
      Tool.functionDeclarations([_resourceFinderDecl]),
    ],
  );

  /// Step C: our own code that actually runs (a mock implementation).
  List<StudyResource> _findStudyResources(String topic) {
    final q = Uri.encodeQueryComponent(topic);
    return [
      StudyResource(
        title: 'YouTube: $topic explained',
        url: 'https://www.youtube.com/results?search_query=$q+explained',
        type: 'video',
      ),
      StudyResource(
        title: 'Wikipedia: $topic',
        url: 'https://en.wikipedia.org/wiki/Special:Search?search=$q',
        type: 'article',
      ),
      StudyResource(
        title: 'Khan Academy: $topic',
        url: 'https://www.khanacademy.org/search?page_search_query=$q',
        type: 'course',
      ),
    ];
  }

  /// Full loop: ask -> Gemini requests the tool -> we run it -> send result back.
  Future<StudyHelp> getStudyHelp({
    required String topic,
    String? questionText,
  }) async {
    final subject = questionText == null
        ? topic
        : '$topic (related to this question: "$questionText")';

    final chat = _toolModel.startChat();

    // Step B: Gemini decides to call the tool.
    var response = await chat.sendMessage(Content.text(
      'A quiz player wants to learn more about: $subject. '
          'Use the findStudyResources tool, then reply with one short, '
          'friendly sentence encouraging them to check the resources.',
    ));

    final calls = response.functionCalls.toList();
    if (calls.isEmpty) {
      // Gemini answered without the tool. Fall back to our own links.
      return StudyHelp(
        message: response.text ?? 'Here are some resources to help you learn.',
        resources: _findStudyResources(topic),
      );
    }

    var resources = <StudyResource>[];
    final call = calls.first;
    if (call.name == 'findStudyResources') {
      final requestedTopic = (call.args['topic'] ?? topic).toString();

      // Step C: run the function ourselves.
      resources = _findStudyResources(requestedTopic);

      // Step D: send the result back to Gemini.
      response = await chat.sendMessage(Content.functionResponse(
        call.name,
        {'resources': resources.map((r) => r.toMap()).toList()},
      ));
    }

    return StudyHelp(
      message: response.text ?? 'Here are some resources to help you learn.',
      resources: resources,
    );
  }
}