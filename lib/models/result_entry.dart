import 'package:equatable/equatable.dart';

/// One row of the final ranking. Also used by Solo Practice in Step 10.
class ResultEntry extends Equatable {
  final String uid;
  final String name;
  final String? photoUrl;
  final int score;

  const ResultEntry({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.score,
  });

  @override
  List<Object?> get props => [uid, name, photoUrl, score];
}