import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/battle_room.dart';
import '../models/chat_message.dart';
import '../models/player.dart';
import '../models/user_model.dart';
import '../models/answer.dart';
import '../utils/constants.dart';
import '../models/question.dart';

/// A friendly error we can show directly to the user.
class RoomException implements Exception {
  final String message;
  const RoomException(this.message);
  @override
  String toString() => message;
}
/// A friendly error for the friends feature.
class FriendException implements Exception {
  final String message;
  const FriendException(this.message);
  @override
  String toString() => message;
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('battleRooms');

  // ---------------------------------------------------------------
  // USERS
  // ---------------------------------------------------------------
  
  /// Creates users/{uid} the first time someone logs in.
  /// For existing users it keeps the saved email in sync.
  Future<void> createUserIfMissing(User user) async {
    final ref = _users.doc(user.uid);
    final snap = await ref.get();
    final email = (user.email ?? '').toLowerCase();

    if (snap.exists) {
      final stored = snap.data()?['email']?.toString() ?? '';
      if (email.isNotEmpty && stored != email) {
        await ref.update({'email': email});
      }
      return;
    }

    final model = UserModel(
      uid: user.uid,
      displayName: user.displayName ?? user.email?.split('@').first ?? 'Player',
      email: email,
      photoUrl: user.photoURL,
    );
    await ref.set(model.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromMap(snap.data()!);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map(
          (s) => s.exists ? UserModel.fromMap(s.data()!) : null,
    );
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _users.doc(uid).update(data);
  }

  // ---------------------------------------------------------------
  // ROOMS
  // ---------------------------------------------------------------

  /// Public rooms that are still waiting for players (live).
  Stream<List<BattleRoom>> watchPublicRooms() {
    return _rooms
        .where('status', isEqualTo: 'waiting')
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(BattleRoom.fromDoc).toList());
  }

  Stream<BattleRoom?> watchRoom(String roomId) {
    return _rooms
        .doc(roomId)
        .snapshots()
        .map((s) => s.exists ? BattleRoom.fromDoc(s) : null);
  }

  /// 6-digit code that no waiting room is using.
  Future<String> generateUniqueRoomCode() async {
    final rand = Random.secure();
    for (var i = 0; i < 10; i++) {
      final code = (100000 + rand.nextInt(900000)).toString();
      final existing =
      await _rooms.where('roomCode', isEqualTo: code).get();
      final inUse =
      existing.docs.any((d) => d.data()['status'] == 'waiting');
      if (!inUse) return code;
    }
    throw const RoomException('Could not create a room code. Try again.');
  }

  Future<String> createRoom(BattleRoom room) async {
    final doc = await _rooms.add(room.toMap());
    return doc.id;
  }

  /// Safe join: a transaction stops two people taking the last seat at once.
  Future<void> joinRoom(String roomId, Player player) async {
    final ref = _rooms.doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const RoomException('This room no longer exists.');
      }
      final room = BattleRoom.fromDoc(snap);

      // Already inside (for example, reopened the app): nothing to do.
      if (room.players.any((p) => p.uid == player.uid)) return;

      if (room.status != RoomStatus.waiting) {
        throw const RoomException('This battle has already started.');
      }
      if (room.isFull) {
        throw const RoomException('This room is full.');
      }

      tx.update(ref, {
        'players': [
          ...room.players.map((p) => p.toMap()),
          player.toMap(),
        ],
      });
    });
  }

  /// Joins a private room by its 6-digit code. Returns the room id.
  Future<String> joinByCode(String code, Player player) async {
    final result = await _rooms.where('roomCode', isEqualTo: code).get();

    QueryDocumentSnapshot<Map<String, dynamic>>? found;
    for (final doc in result.docs) {
      if (doc.data()['status'] == 'waiting') {
        found = doc;
        break;
      }
    }
    if (found == null) {
      throw const RoomException('No waiting room found with that code.');
    }

    await joinRoom(found.id, player);
    return found.id;
  }

  /// Leaving: last player out deletes the room, and if the host leaves,
  /// the next player becomes the host.
  Future<void> leaveRoom(String roomId, String uid) async {
    final ref = _rooms.doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final room = BattleRoom.fromDoc(snap);

      final remaining = room.players.where((p) => p.uid != uid).toList();
      if (remaining.isEmpty) {
        tx.delete(ref);
        return;
      }

      final updates = <String, dynamic>{
        'players': remaining.map((p) => p.toMap()).toList(),
      };
      if (room.hostId == uid) {
        updates['hostId'] = remaining.first.uid;
        updates['hostName'] = remaining.first.name;
      }
      tx.update(ref, updates);
    });
  }

  Future<void> setReady(String roomId, String uid, bool ready) async {
    final ref = _rooms.doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final room = BattleRoom.fromDoc(snap);
      if (room.status != RoomStatus.waiting) return;

      final players = room.players
          .map((p) => p.uid == uid ? p.copyWith(isReady: ready) : p)
          .toList();
      tx.update(ref, {'players': players.map((p) => p.toMap()).toList()});
    });
  }

  /// Host only. Needs at least 2 ready players.
  Future<void> startBattle(String roomId, String uid) async {
    final ref = _rooms.doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const RoomException('This room no longer exists.');
      }
      final room = BattleRoom.fromDoc(snap);

      if (room.hostId != uid) {
        throw const RoomException('Only the host can start the battle.');
      }
      if (!room.canStart) {
        throw const RoomException('At least 2 players must be ready.');
      }
      if (room.questions.isEmpty) {
        throw const RoomException('This room has no questions.');
      }

      tx.update(ref, {
        'status': 'active',
        'currentQuestionIndex': 0,
        'phase': kPhaseQuestion,
        'questionStartedAt': DateTime.now().millisecondsSinceEpoch,
        'players':
        room.players.map((p) => p.copyWith(score: 0).toMap()).toList(),
      });
    });
  }
  // ---------------------------------------------------------------
  // BATTLE (answers + moving between phases)
  // ---------------------------------------------------------------

  /// One document per player per question: answers/{uid}_{questionIndex}.
  Future<void> submitAnswer(String roomId, Answer answer) {
    return _rooms
        .doc(roomId)
        .collection('answers')
        .doc(answer.docId)
        .set(answer.toMap());
  }

  Stream<List<Answer>> watchAnswers(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('answers')
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => Answer.fromMap(d.data())).toList());
  }

  /// question -> reveal. Guarded, so if several phones ask at the same
  /// moment only the first one changes anything.
  Future<void> moveToReveal(String roomId, int questionIndex) async {
    final ref = _rooms.doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final room = BattleRoom.fromDoc(snap);

      if (room.status != RoomStatus.active) return;
      if (room.currentQuestionIndex != questionIndex) return;
      if (room.phase != kPhaseQuestion) return;

      tx.update(ref, {'phase': kPhaseReveal});
    });
  }

  /// reveal -> next question, or finish the battle after the last one.
  /// Guarded in the same way. [finalScores] is only used when finishing.
  Future<void> advanceQuestion(
      String roomId,
      int fromIndex,
      Map<String, int> finalScores,
      ) async {
    final ref = _rooms.doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final room = BattleRoom.fromDoc(snap);

      if (room.status != RoomStatus.active) return;
      if (room.currentQuestionIndex != fromIndex) return;
      if (room.phase != kPhaseReveal) return;

      final next = fromIndex + 1;
      if (next < room.questions.length) {
        tx.update(ref, {
          'currentQuestionIndex': next,
          'phase': kPhaseQuestion,
          'questionStartedAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        final players = room.players
            .map((p) => p.copyWith(score: finalScores[p.uid] ?? 0).toMap())
            .toList();
        tx.update(ref, {'status': 'finished', 'players': players});
      }
    });
  }
  // ---------------------------------------------------------------
  // RESULTS (end of battle, stats, rematch)
  // ---------------------------------------------------------------

  Future<BattleRoom?> getRoom(String roomId) async {
    final snap = await _rooms.doc(roomId).get();
    return snap.exists ? BattleRoom.fromDoc(snap) : null;
  }

  Future<List<Answer>> getAnswers(String roomId) async {
    final snap = await _rooms.doc(roomId).collection('answers').get();
    return snap.docs.map((d) => Answer.fromMap(d.data())).toList();
  }

  /// Adds this battle to my stats. Runs only once per player per battle,
  /// because the marker document results/{uid} is created in the same step.
  Future<void> applyBattleResult({
    required String roomId,
    required String uid,
    required int points,
    required bool won,
  }) async {
    final markerRef = _rooms.doc(roomId).collection('results').doc(uid);
    final userRef = _users.doc(uid);

    await _db.runTransaction((tx) async {
      final marker = await tx.get(markerRef);
      if (marker.exists) return; // already counted

      final userSnap = await tx.get(userRef);
      final streak = (userSnap.data()?['streak'] as num?)?.toInt() ?? 0;

      tx.update(userRef, {
        'totalBattles': FieldValue.increment(1),
        'wins': FieldValue.increment(won ? 1 : 0),
        'totalPoints': FieldValue.increment(points),
        'streak': won ? streak + 1 : 0,
      });
      tx.set(markerRef, {'appliedAt': FieldValue.serverTimestamp()});
    });
  }

  /// The rematch room someone already created for this battle (or null).
  Future<String?> getNextRoomId(String roomId) async {
    final snap = await _rooms.doc(roomId).get();
    final id = snap.data()?['nextRoomId']?.toString();
    return (id == null || id.isEmpty) ? null : id;
  }

  /// First player to call this wins the right to host the rematch.
  /// Returns the id of the rematch room that everyone should use.
  Future<String> claimRematch(String roomId, String newRoomId) async {
    final ref = _rooms.doc(roomId);
    return _db.runTransaction<String>((tx) async {
      final snap = await tx.get(ref);
      final existing = snap.data()?['nextRoomId']?.toString();
      if (existing != null && existing.isNotEmpty) return existing;
      tx.update(ref, {'nextRoomId': newRoomId});
      return newRoomId;
    });
  }

  Future<void> deleteRoom(String roomId) => _rooms.doc(roomId).delete();
  // ---------------------------------------------------------------
  // DAILY CHALLENGE
  // ---------------------------------------------------------------

  /// Today's shared quiz, or null if nobody has generated it yet.
  Future<List<Question>?> getDailyQuestions(String dateKey) async {
    final snap = await _db.collection('dailyChallenges').doc(dateKey).get();
    if (!snap.exists) return null;
    final list = snap.data()?['questions'] as List?;
    if (list == null || list.isEmpty) return null;
    return list
        .map((q) => Question.fromMap(Map<String, dynamic>.from(q)))
        .toList();
  }

  Future<void> saveDailyQuestions(
      String dateKey,
      String topic,
      List<Question> questions,
      ) {
    return _db.collection('dailyChallenges').doc(dateKey).set({
      'topic': topic,
      'questions': questions.map((q) => q.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Gives the daily bonus once per day. Returns true if it was awarded.
  Future<bool> claimDailyBonus(String uid, String dateKey, int bonus) {
    final ref = _users.doc(uid);
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (snap.data()?['lastDailyChallenge'] == dateKey) return false;
      tx.update(ref, {
        'lastDailyChallenge': dateKey,
        'totalPoints': FieldValue.increment(bonus),
      });
      return true;
    });
  }
  // ---------------------------------------------------------------
  // LEADERBOARD
  // ---------------------------------------------------------------

  /// Top players by total points (live). Only finished profiles are shown.
  Stream<List<UserModel>> watchTopUsers({int limit = 50}) {
    return _users
        .orderBy('totalPoints', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => UserModel.fromMap(d.data()))
        .where((u) => u.profileComplete)
        .toList());
  }

  /// How many players have more points than this (used to find my rank).
  Future<int> countUsersAbove(int points) async {
    final agg = await _users
        .where('totalPoints', isGreaterThan: points)
        .count()
        .get();
    return agg.count ?? 0;
  }

  // ---------------------------------------------------------------
  // FRIENDS (a list of friend ids saved on my user document)
  // ---------------------------------------------------------------

  Stream<List<String>> watchFriendIds(String uid) {
    return _users.doc(uid).snapshots().map((s) {
      final list = s.data()?['friends'] as List?;
      return list == null
          ? <String>[]
          : list.map((e) => e.toString()).toList();
    });
  }

  Future<List<UserModel>> getUsersByIds(List<String> ids) async {
    final result = <UserModel>[];
    // Firestore allows a limited number of ids per query, so go in chunks.
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, min(i + 10, ids.length));
      final snap =
      await _users.where(FieldPath.documentId, whereIn: chunk).get();
      result.addAll(snap.docs.map((d) => UserModel.fromMap(d.data())));
    }
    return result;
  }

  /// Adds a friend by email. Returns the friend's name.
  Future<String> addFriendByEmail(String myUid, String email) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) {
      throw const FriendException('Enter an email address.');
    }

    final found =
    await _users.where('email', isEqualTo: clean).limit(1).get();
    if (found.docs.isEmpty) {
      throw const FriendException('No player found with that email.');
    }

    final friend = UserModel.fromMap(found.docs.first.data());
    if (friend.uid == myUid) {
      throw const FriendException("That's your own email.");
    }

    final me = await _users.doc(myUid).get();
    final existing = (me.data()?['friends'] as List?) ?? [];
    if (existing.contains(friend.uid)) {
      throw FriendException('${friend.displayName} is already your friend.');
    }

    await _users.doc(myUid).update({
      'friends': FieldValue.arrayUnion([friend.uid]),
    });
    return friend.displayName;
  }

  Future<void> removeFriend(String myUid, String friendUid) {
    return _users.doc(myUid).update({
      'friends': FieldValue.arrayRemove([friendUid]),
    });
  }

  // ---------------------------------------------------------------
  // CHAT (battleRooms/{roomId}/messages)
  // ---------------------------------------------------------------

  Future<void> sendMessage(String roomId, ChatMessage message) {
    return _rooms.doc(roomId).collection('messages').add(message.toMap());
  }

  Stream<List<ChatMessage>> watchMessages(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp')
        .limitToLast(100)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }
}