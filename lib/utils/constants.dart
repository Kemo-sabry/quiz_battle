const List<String> kTopics = [
  'Science',
  'History',
  'Math',
  'Geography',
  'Technology',
  'Sports',
  'Movies',
  'Music',
  'Literature',
  'General Knowledge',
];

const List<String> kDifficulties = ['Easy', 'Medium', 'Hard'];

const int kMinTopics = 2;
const int kMaxTopics = 3;

// ---- Battle settings ----
const int kQuestionSeconds = 15; // time to answer each question
const int kRevealSeconds = 3; // how long the result is shown
const int kBasePoints = 500; // points for a correct answer
const int kSpeedBonus = 500; // extra points for answering fast

// ---- Room phases ----
const String kPhaseQuestion = 'question';
const String kPhaseReveal = 'reveal';

// ---- Solo practice ----
const int kDailyBonus = 100; // bonus points for the daily challenge
const String kBotUid = 'ai_bot';
const String kBotName = 'AI Bot';

/// How often the bot answers correctly, by difficulty.
const Map<String, double> kBotAccuracy = {
  'Easy': 0.5,
  'Medium': 0.7,
  'Hard': 0.9,
};

/// How long the bot thinks, in seconds: [fastest, slowest], by difficulty.
const Map<String, List<double>> kBotDelay = {
  'Easy': [6.0, 13.0],
  'Medium': [4.0, 11.0],
  'Hard': [2.0, 8.0],
};