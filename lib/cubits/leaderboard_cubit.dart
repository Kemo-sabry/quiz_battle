import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class LeaderboardState extends Equatable {
  final bool loadingGlobal;
  final bool loadingFriends;
  final List<UserModel> top; // global top 50
  final int? myRank; // my place among all players
  final int myPoints;
  final List<UserModel> friends; // my friends plus me, best first
  final String? error;

  const LeaderboardState({
    this.loadingGlobal = true,
    this.loadingFriends = true,
    this.top = const [],
    this.myRank,
    this.myPoints = 0,
    this.friends = const [],
    this.error,
  });

  LeaderboardState copyWith({
    bool? loadingGlobal,
    bool? loadingFriends,
    List<UserModel>? top,
    int? myRank,
    int? myPoints,
    List<UserModel>? friends,
    String? error,
  }) =>
      LeaderboardState(
        loadingGlobal: loadingGlobal ?? this.loadingGlobal,
        loadingFriends: loadingFriends ?? this.loadingFriends,
        top: top ?? this.top,
        myRank: myRank ?? this.myRank,
        myPoints: myPoints ?? this.myPoints,
        friends: friends ?? this.friends,
        error: error,
      );

  @override
  List<Object?> get props => [
    loadingGlobal,
    loadingFriends,
    top,
    myRank,
    myPoints,
    friends,
    error,
  ];
}

class LeaderboardCubit extends Cubit<LeaderboardState> {
  final FirestoreService _db;
  final String uid;

  StreamSubscription<List<UserModel>>? _topSub;
  StreamSubscription<List<String>>? _friendsSub;
  List<String> _friendIds = [];
  bool _friendsLoaded = false;

  LeaderboardCubit(this._db, this.uid) : super(const LeaderboardState()) {
    _topSub = _db.watchTopUsers().listen(
      _onTop,
      onError: (e) => emit(
          state.copyWith(loadingGlobal: false, error: e.toString())),
    );

    _friendsSub = _db.watchFriendIds(uid).listen(
          (ids) {
        _friendIds = ids;
        _friendsLoaded = true;
        _loadFriends();
      },
      onError: (_) {},
    );
  }

  Future<void> _onTop(List<UserModel> top) async {
    int? rank;
    var points = 0;

    try {
      final index = top.indexWhere((u) => u.uid == uid);
      if (index >= 0) {
        // I'm in the top 50. Equal points share the same rank.
        points = top[index].totalPoints;
        rank = 1 + top.where((u) => u.totalPoints > points).length;
      } else {
        // I'm lower down: count how many players are above me.
        final me = await _db.getUser(uid);
        points = me?.totalPoints ?? 0;
        rank = await _db.countUsersAbove(points) + 1;
      }
    } catch (_) {}

    if (isClosed) return;
    emit(state.copyWith(
      loadingGlobal: false,
      top: top,
      myRank: rank,
      myPoints: points,
    ));

    // Scores changed somewhere, so refresh the friends ranking too.
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final ids = {..._friendIds, uid}.toList();
      final users = await _db.getUsersByIds(ids);
      users.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
      if (isClosed) return;
      emit(state.copyWith(loadingFriends: !_friendsLoaded, friends: users));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loadingFriends: false, error: e.toString()));
    }
  }

  Future<void> refresh() => _loadFriends();

  /// Returns the friend's name, or throws a FriendException.
  Future<String> addFriend(String email) => _db.addFriendByEmail(uid, email);

  Future<void> removeFriend(String friendUid) =>
      _db.removeFriend(uid, friendUid);

  @override
  Future<void> close() {
    _topSub?.cancel();
    _friendsSub?.cancel();
    return super.close();
  }
}