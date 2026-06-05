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
  final String? bio;
  final String? listeners;

  const ArtistItem({
    required this.id,
    required this.name,
    required this.image,
    this.bio,
    this.listeners,
  });

  factory ArtistItem.fromJson(Map<String, dynamic> json) {
    String? bioText = json['bio']?.toString();
    if (bioText == null || bioText.trim().isEmpty) {
      bioText = json['description']?.toString();
    }
    
    String? listenersText = json['listeners']?.toString();
    if (listenersText == null || listenersText.trim().isEmpty) {
      final rawFollowers = json['followerCount'] ?? json['follower_count'] ?? json['fanCount'] ?? json['fan_count'];
      if (rawFollowers != null) {
        final numFollowers = int.tryParse(rawFollowers.toString());
        if (numFollowers != null) {
          if (numFollowers >= 1000000) {
            listenersText = '${(numFollowers / 1000000).toStringAsFixed(1)}M';
          } else if (numFollowers >= 1000) {
            listenersText = '${(numFollowers / 1000).toStringAsFixed(1)}K';
          } else {
            listenersText = '$numFollowers';
          }
        } else {
          listenersText = rawFollowers.toString();
        }
      }
    }

    return ArtistItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Artist',
      image: _bestImage(json['image']),
      bio: bioText,
      listeners: listenersText,
    );
  }

}


String _bestImage(dynamic imageData) {
  String url = '';
  if (imageData is String && imageData.isNotEmpty) {
    url = imageData;
  } else if (imageData is List && imageData.isNotEmpty) {
    final best = imageData.cast<dynamic>().firstWhere(
          (e) => e is Map && e['quality'] == '500x500',
          orElse: () => imageData.last,
        );
    if (best is Map) url = best['url']?.toString() ?? '';
  }
  return SongModel.hiResImage(url);
}
