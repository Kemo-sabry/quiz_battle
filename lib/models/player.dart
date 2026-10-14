class Player {
  final String uid;
  final String name;
  final String? photoUrl;
  final bool isReady;
  final int score;

  const Player({
    required this.uid,
    required this.name,
    this.photoUrl,
    this.isReady = false,
    this.score = 0,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'photoUrl': photoUrl,
    'isReady': isReady,
    'score': score,
  };

  factory Player.fromMap(Map<String, dynamic> map) => Player(
    uid: (map['uid'] ?? '').toString(),
    name: (map['name'] ?? '').toString(),
    photoUrl: map['photoUrl']?.toString(),
    isReady: map['isReady'] ?? false,
    score: (map['score'] as num?)?.toInt() ?? 0,
  );

  Player copyWith({bool? isReady, int? score}) => Player(
    uid: uid,
    name: name,
    photoUrl: photoUrl,
    isReady: isReady ?? this.isReady,
    score: score ?? this.score,
  );
}