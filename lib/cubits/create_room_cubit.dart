import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/battle_room.dart';
import '../models/player.dart';
import '../models/user_model.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';

class CreateRoomState extends Equatable {
  final bool loading;
  final String? error;
  final String? roomId; // set when the room was created

  const CreateRoomState({this.loading = false, this.error, this.roomId});

  @override
  List<Object?> get props => [loading, error, roomId];
}

class CreateRoomCubit extends Cubit<CreateRoomState> {
  final FirestoreService _db;
  final AIService _ai;

  CreateRoomCubit(this._db, this._ai) : super(const CreateRoomState());

  Future<void> createRoom({
    required UserModel user,
    required String name,
    required bool isPublic,
    required String topic,
    required String difficulty,
    required int questionCount,
    required int maxPlayers,
  }) async {
    emit(const CreateRoomState(loading: true));
    try {
      // 1) Gemini writes the quiz.
      final questions = await _ai.generateQuiz(
        topic: topic,
        difficulty: difficulty,
        count: questionCount,
      );

      // 2) Private rooms get a 6-digit code.
      final code = isPublic ? null : await _db.generateUniqueRoomCode();

      // 3) Save the room. The host joins as the first player, already ready.
      final room = BattleRoom(
        id: '',
        name: name.trim().isEmpty ? "${user.displayName}'s room" : name.trim(),
        hostId: user.uid,
        hostName: user.displayName,
        topic: topic,
        difficulty: difficulty,
        questionCount: questionCount,
        maxPlayers: maxPlayers,
        isPublic: isPublic,
        roomCode: code,
        players: [
          Player(
            uid: user.uid,
            name: user.displayName,
            photoUrl: user.photoUrl,
            isReady: true,
          ),
        ],
        questions: questions,
      );
      final id = await _db.createRoom(room);

      if (isClosed) return;
      emit(CreateRoomState(roomId: id));
    } catch (e) {
      if (isClosed) return;
      emit(CreateRoomState(error: e.toString()));
    }
  }
}