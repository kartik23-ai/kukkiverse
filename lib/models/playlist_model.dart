import 'song_model.dart';

class PlaylistModel {
  final String id;
  final String name;
  final String description;
  final String image;
  final List<SongModel> songs;
  final DateTime createdAt;
  final bool isLocal;

  PlaylistModel({
    required this.id,
    required this.name,
    this.description = '',
    this.image = '',
    this.songs = const [],
    DateTime? createdAt,
    this.isLocal = true,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'image': image,
    'songs': songs.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'isLocal': isLocal,
  };

  factory PlaylistModel.fromJson(Map<dynamic, dynamic> json) {
    return PlaylistModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      image: json['image'] ?? '',
      songs: (json['songs'] as List?)?.map<SongModel>((s) => SongModel.fromHive(Map<String, dynamic>.from(s))).toList() ?? [],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      isLocal: json['isLocal'] ?? true,
    );
  }

  PlaylistModel copyWith({
    String? name,
    String? description,
    String? image,
    List<SongModel>? songs,
  }) {
    return PlaylistModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      image: image ?? this.image,
      songs: songs ?? this.songs,
      createdAt: createdAt,
      isLocal: isLocal,
    );
  }
}
