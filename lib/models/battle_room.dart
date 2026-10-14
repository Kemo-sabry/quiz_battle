import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import 'player.dart';
import 'question.dart';

enum RoomStatus { waiting, active, finished }

class BattleRoom {
  final String id;
  final String name;
  final String hostId;
  final String hostName;
  final String topic;
  final String difficulty;
  final int questionCount;
  final int maxPlayers;
  final bool isPublic;
  final String? roomCode; // 6 digits, private rooms only
  final RoomStatus status;
  final List<Player> players;
  final List<Question> questions;
  final int currentQuestionIndex;
  final String phase; // 'question' or 'reveal'
  final int? questionStartedAt; // millis since epoch

  const BattleRoom({
    required this.id,
    required this.name,
    required this.hostId,
    required this.hostName,
    required this.topic,
    required this.difficulty,
    required this.questionCount,
    required this.maxPlayers,
    required this.isPublic,
    this.roomCode,
    this.status = RoomStatus.waiting,
    this.players = const [],
    this.questions = const [],
    this.currentQuestionIndex = 0,
    this.phase = kPhaseQuestion,
    this.questionStartedAt,
  });

  bool get isFull => players.length >= maxPlayers;

  /// The host can start when 2 or more players are ready.
  bool get canStart => players.where((p) => p.isReady).length >= 2;

  Map<String, dynamic> toMap() => {
    'name': name,
    'hostId': hostId,
    'hostName': hostName,
    'topic': topic,
    'difficulty': difficulty,
    'questionCount': questionCount,
    'maxPlayers': maxPlayers,
    'isPublic': isPublic,
    'roomCode': roomCode,
    'status': status.name,
    'players': players.map((p) => p.toMap()).toList(),
    'questions': questions.map((q) => q.toMap()).toList(),
    'currentQuestionIndex': currentQuestionIndex,
    'phase': phase,
    'questionStartedAt': questionStartedAt,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory BattleRoom.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return BattleRoom(
      id: doc.id,
      name: (map['name'] ?? '').toString(),
      hostId: (map['hostId'] ?? '').toString(),
      hostName: (map['hostName'] ?? '').toString(),
      topic: (map['topic'] ?? '').toString(),
      difficulty: (map['difficulty'] ?? 'Medium').toString(),
      questionCount: (map['questionCount'] as num?)?.toInt() ?? 5,
      maxPlayers: (map['maxPlayers'] as num?)?.toInt() ?? 2,
      isPublic: map['isPublic'] ?? true,
      roomCode: map['roomCode']?.toString(),
      status: RoomStatus.values.firstWhere(
            (s) => s.name == map['status'],
        orElse: () => RoomStatus.waiting,
      ),
      players: (map['players'] as List? ?? [])
          .map((p) => Player.fromMap(Map<String, dynamic>.from(p)))
          .toList(),
      questions: (map['questions'] as List? ?? [])
          .map((q) => Question.fromMap(Map<String, dynamic>.from(q)))
          .toList(),
      currentQuestionIndex:
      (map['currentQuestionIndex'] as num?)?.toInt() ?? 0,
      phase: (map['phase'] ?? kPhaseQuestion).toString(),
      questionStartedAt: (map['questionStartedAt'] as num?)?.toInt(),
    );
  }
}