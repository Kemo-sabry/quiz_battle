import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/battle_room.dart';
import '../services/firestore_service.dart';

class RoomsState extends Equatable {
  final bool loading;
  final List<BattleRoom> rooms;
  final String? error;

  const RoomsState({this.loading = true, this.rooms = const [], this.error});

  @override
  List<Object?> get props => [loading, rooms, error];
}

class RoomsCubit extends Cubit<RoomsState> {
  StreamSubscription<List<BattleRoom>>? _sub;

  RoomsCubit(FirestoreService db) : super(const RoomsState()) {
    _sub = db.watchPublicRooms().listen(
          (rooms) => emit(RoomsState(loading: false, rooms: rooms)),
      onError: (e) => emit(RoomsState(loading: false, error: e.toString())),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}