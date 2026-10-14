import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'user_state.dart';

class UserCubit extends Cubit<UserState> {
  final FirestoreService _db;
  final String uid;
  StreamSubscription<UserModel?>? _sub;

  UserCubit(this._db, this.uid) : super(UserLoading()) {
    _sub = _db.watchUser(uid).listen(
          (user) {
        if (user == null) {
          emit(UserLoading());
        } else {
          emit(UserLoaded(user));
        }
      },
      onError: (e) => emit(UserError(e.toString())),
    );
  }

  /// First-time profile setup. Marks the profile as complete.
  Future<void> completeProfile({
    required String name,
    required List<String> topics,
    required String difficulty,
  }) {
    return _db.updateUser(uid, {
      'displayName': name.trim(),
      'topics': topics,
      'difficulty': difficulty,
      'profileComplete': true,
    });
  }

  Future<void> updateTopics(List<String> topics) =>
      _db.updateUser(uid, {'topics': topics});

  Future<void> updateDifficulty(String difficulty) =>
      _db.updateUser(uid, {'difficulty': difficulty});

  Future<void> updateName(String name) =>
      _db.updateUser(uid, {'displayName': name.trim()});

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}