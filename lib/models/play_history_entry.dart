import 'song_model.dart';

class PlayHistoryEntry {
  final SongModel song;
  final DateTime playedAt;

  const PlayHistoryEntry({required this.song, required this.playedAt});

  Map<String, dynamic> toJson() => {
        'song': song.toJson(),
        'playedAt': playedAt.toIso8601String(),
      };

  factory PlayHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PlayHistoryEntry(
      song: SongModel.fromHive(Map<String, dynamic>.from(json['song'] as Map)),
      playedAt: DateTime.parse(json['playedAt'] as String),
    );
  }
}
