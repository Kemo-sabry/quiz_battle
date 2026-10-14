class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final List<String> topics;
  final String difficulty; // Easy | Medium | Hard
  final bool profileComplete;
  final int totalBattles;
  final int wins;
  final int streak;
  final int totalPoints;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.topics = const [],
    this.difficulty = 'Medium',
    this.profileComplete = false,
    this.totalBattles = 0,
    this.wins = 0,
    this.streak = 0,
    this.totalPoints = 0,
  });

  double get winRate => totalBattles == 0 ? 0 : (wins / totalBattles) * 100;

  /// Level badge based on total points.
  String get level {
    if (totalPoints >= 5000) return 'Diamond';
    if (totalPoints >= 2000) return 'Gold';
    if (totalPoints >= 500) return 'Silver';
    return 'Bronze';
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
    'topics': topics,
    'difficulty': difficulty,
    'profileComplete': profileComplete,
    'totalBattles': totalBattles,
    'wins': wins,
    'streak': streak,
    'totalPoints': totalPoints,
  };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    uid: map['uid'] ?? '',
    displayName: map['displayName'] ?? '',
    email: map['email'] ?? '',
    photoUrl: map['photoUrl'],
    topics: List<String>.from(map['topics'] ?? []),
    difficulty: map['difficulty'] ?? 'Medium',
    profileComplete: map['profileComplete'] ?? false,
    totalBattles: map['totalBattles'] ?? 0,
    wins: map['wins'] ?? 0,
    streak: map['streak'] ?? 0,
    totalPoints: map['totalPoints'] ?? 0,
  );

  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    List<String>? topics,
    String? difficulty,
    bool? profileComplete,
    int? totalBattles,
    int? wins,
    int? streak,
    int? totalPoints,
  }) =>
      UserModel(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        topics: topics ?? this.topics,
        difficulty: difficulty ?? this.difficulty,
        profileComplete: profileComplete ?? this.profileComplete,
        totalBattles: totalBattles ?? this.totalBattles,
        wins: wins ?? this.wins,
        streak: streak ?? this.streak,
        totalPoints: totalPoints ?? this.totalPoints,
      );
}