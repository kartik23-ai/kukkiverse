import 'song_model.dart';

class AlbumItem {
  final String id;
  final String name;
  final String image;
  final String year;
  final String language;

  const AlbumItem({
    required this.id,
    required this.name,
    required this.image,
    this.year = '',
    this.language = '',
  });

  factory AlbumItem.fromJson(Map<String, dynamic> json) {
    return AlbumItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Album',
      image: _bestImage(json['image']),
      year: json['year']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
    );
  }
}

class ArtistItem {
  final String id;
  final String name;
  final String image;

  const ArtistItem({
    required this.id,
    required this.name,
    required this.image,
  });

  factory ArtistItem.fromJson(Map<String, dynamic> json) {
    return ArtistItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Artist',
      image: _bestImage(json['image']),
    );
  }
}

String _bestImage(dynamic imageData) {
  if (imageData is String && imageData.isNotEmpty) {
    return SongModel.hiResImage(imageData);
  }
  if (imageData is List && imageData.isNotEmpty) {
    final best = imageData.cast<dynamic>().firstWhere(
          (e) => e is Map && e['quality'] == '500x500',
          orElse: () => imageData.last,
        );
    if (best is Map) return best['url']?.toString() ?? '';
  }
  return '';
}
