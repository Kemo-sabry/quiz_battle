import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/battle_room.dart';
import '../models/chat_message.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class LobbyState extends Equatable {
  final bool loading;
  final BattleRoom? room;
  final List<ChatMessage> messages;
  final bool closed; // the room was deleted
  final String? error;

  const LobbyState({
    this.loading = true,
    this.room,
    this.messages = const [],
    this.closed = false,
    this.error,
  });

  LobbyState copyWith({
    bool? loading,
    BattleRoom? room,
    List<ChatMessage>? messages,
    bool? closed,
    String? error,
  }) =>
      LobbyState(
        loading: loading ?? this.loading,
        room: room ?? this.room,
        messages: messages ?? this.messages,
        closed: closed ?? this.closed,
        error: error ?? this.error,
      );

  @override
  List<Object?> get props => [loading, room, messages, closed, error];
}

class LobbyCubit extends Cubit<LobbyState> {
  final FirestoreService _db;
  final String roomId;
  final UserModel _user;
  StreamSubscription<BattleRoom?>? _roomSub;
  StreamSubscription<List<ChatMessage>>? _chatSub;

  LobbyCubit(this._db, this.roomId, this._user) : super(const LobbyState()) {
    _roomSub = _db.watchRoom(roomId).listen(
          (room) {
        if (room == null) {
          emit(state.copyWith(loading: false, closed: true));
        } else {
          emit(state.copyWith(loading: false, room: room));
        }
      },
      onError: (e) => emit(state.copyWith(loading: false, error: e.toString())),
    );

    _chatSub = _db.watchMessages(roomId).listen(
          (messages) => emit(state.copyWith(messages: messages)),
      onError: (_) {},
    );
  }

  Future<void> setReady(bool ready) =>
      _db.setReady(roomId, _user.uid, ready);

  Future<void> startBattle() => _db.startBattle(roomId, _user.uid);

  Future<void> sendMessage(String text) {
    return _db.sendMessage(
      roomId,
      ChatMessage(
        senderId: _user.uid,
        senderName: _user.displayName,
        text: text.trim(),
      ),
    );
  }

  Future<void> leave() => _db.leaveRoom(roomId, _user.uid);

  @override
  Future<void> close() {
    _roomSub?.cancel();
    _chatSub?.cancel();
    return super.close();
  }
}