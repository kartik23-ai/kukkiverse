import 'dart:convert';
import 'package:dart_des/dart_des.dart';
import '../core/constants/api_constants.dart';

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String image;
  final Duration duration;
  final String url;
  final String? lyrics;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.image,
    required this.duration,
    required this.url,
    this.lyrics,
  });

  bool get hasPlayableUrl =>
      url.isNotEmpty &&
      (url.startsWith('http://') ||
          url.startsWith('https://') ||
          url.startsWith('file://') ||
          url.startsWith('file:'));

  /// Web API song parser (`search.getResults`, album songs, etc.)
  factory SongModel.fromSaavnWeb(Map<String, dynamic> json, {String quality = '320kbps'}) {
    final is320 = json['320kbps']?.toString() == 'true';
    var downloadUrl = _resolvePlayableUrl(json, prefer320: is320);
    final img = hiResImage(json['image']?.toString() ?? '');
    return SongModel(
      id: json['id']?.toString() ?? '',
      title: json['song']?.toString() ?? json['name']?.toString() ?? 'Unknown',
      artist: json['primary_artists']?.toString() ?? json['singers']?.toString() ?? 'Artist',
      album: json['album']?.toString() ?? 'Single',
      image: img,
      duration: Duration(seconds: int.tryParse(json['duration']?.toString() ?? '0') ?? 0),
      url: downloadUrl,
      lyrics: json['lyrics']?.toString(),
    );
  }

  static String hiResImage(String url) {
    if (url.isEmpty) return url;
    final cleanUrl = url
        .replaceAll('150x150', '500x500')
        .replaceAll('50x50', '500x500')
        .replaceAll('250x250', '500x500');
    return cleanUrl;
  }

  factory SongModel.fromJson(
    Map<String, dynamic> json, {
    String preferredQuality = '320kbps',
  }) {
    final id = json['id']?.toString() ?? '';

    final imageUrl = hiResImage(_bestImage(json['image']));

    var downloadUrl = '';
    if (json['encrypted_media_url'] != null) {
      downloadUrl = _resolvePlayableUrl(json, prefer320: preferredQuality == '320kbps');
    }
    if (downloadUrl.isEmpty && json['downloadUrl'] is List) {
      downloadUrl = _bestAudio(json['downloadUrl'], preferredQuality);
      if (downloadUrl.isNotEmpty) downloadUrl = downloadUrl.replaceFirst('http:', 'https:');
    }
    if (downloadUrl.isEmpty && json['url'] != null) {
      downloadUrl = json['url'].toString();
    }

    final albumName = json['album'] is Map
        ? json['album']['name']?.toString()
        : json['album']?.toString();

    return SongModel(
      id: id,
      title: json['name']?.toString() ?? json['title']?.toString() ?? 'Unknown',
      artist: _parseArtists(json),
      album: albumName ?? 'Single',
      image: imageUrl,
      duration: Duration(
        seconds: int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
      ),
      url: downloadUrl,
      lyrics: json['lyrics']?.toString(),
    );
  }

  factory SongModel.fromHive(Map<String, dynamic> json) {
    return SongModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      album: json['album']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      duration: Duration(seconds: json['duration'] ?? 0),
      url: json['url']?.toString() ?? '',
      lyrics: json['lyrics']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'image': image,
        'duration': duration.inSeconds,
        'url': url,
        'lyrics': lyrics,
      };

  int get durationSeconds => duration.inSeconds;

  String get formattedDuration {
    final m = duration.inMinutes;
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String _parseArtists(Map<String, dynamic> json) {
    if (json['artists'] is Map && json['artists']['primary'] is List) {
      final names = (json['artists']['primary'] as List)
          .map((a) => a is Map ? a['name']?.toString() : null)
          .whereType<String>()
          .toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    if (json['artist'] != null) {
      return json['artist'].toString();
    }
    if (json['primaryArtists'] != null) {
      return json['primaryArtists'].toString();
    }
    if (json['subtitle'] != null) {
      return json['subtitle'].toString();
    }
    return 'Various Artists';
  }

  static String _bestImage(dynamic imageData) {
    if (imageData is List && imageData.isNotEmpty) {
      final best = imageData.cast<dynamic>().firstWhere(
            (e) => e is Map && e['quality'] == '500x500',
            orElse: () => imageData.last,
          );
      if (best is Map) return best['url']?.toString() ?? '';
    }
    return imageData?.toString() ?? '';
  }

  static String _bestAudio(List urls, String preferredQuality) {
    if (urls.isEmpty) return '';
    final qualities = ['320kbps', '160kbps', '96kbps', '48kbps', '12kbps'];
    final order = [preferredQuality, ...qualities.where((q) => q != preferredQuality)];
    for (final q in order) {
      try {
        final match = urls.firstWhere((e) => e is Map && e['quality'] == q);
        if (match is Map) return match['url']?.toString() ?? '';
      } catch (_) {}
    }
    final first = urls.first;
    return first is Map ? first['url']?.toString() ?? '' : '';
  }

  static String _resolvePlayableUrl(Map<String, dynamic> json, {bool prefer320 = true}) {
    var url = '';
    final enc = json['encrypted_media_url']?.toString() ?? '';
    if (enc.isNotEmpty) {
      url = _decrypt(enc, prefer320: prefer320);
    }
    if (url.isEmpty) {
      url = _previewPlayableUrl(json['media_preview_url']?.toString() ?? '', prefer320: prefer320);
    }
    if (url.isNotEmpty) {
      url = url.replaceFirst('http:', 'https:');
      if (url.contains('akamaized.net')) {
        url = url.replaceFirst('media-saavn.akamaized.net', 'aac.saavncdn.com');
      }
    }
    return url;
  }

  static String _previewPlayableUrl(String preview, {bool prefer320 = true}) {
    if (preview.isEmpty) return '';
    var url = preview.replaceFirst('http:', 'https:');
    if (prefer320) {
      url = url
          .replaceAll('_96_p.mp4', '_320.mp4')
          .replaceAll('_96.mp4', '_320.mp4');
    }
    return url;
  }

  static String _decrypt(String encrypted, {bool prefer320 = true}) {
    final raw = encrypted.trim();
    if (raw.isEmpty) return '';
    try {
      final des = DES(key: utf8.encode('38346591'), mode: DESMode.ECB);
      final decrypted = des.decrypt(base64.decode(raw));
      final pad = decrypted.isNotEmpty ? decrypted.last : 0;
      final bytes = (pad > 0 && pad <= 8 && decrypted.length >= pad)
          ? decrypted.sublist(0, decrypted.length - pad)
          : decrypted;
      final match = RegExp(r'https?://[^\s\x00-\x1F]+').firstMatch(utf8.decode(bytes));
      var url = match?.group(0)?.trim() ?? '';
      if (url.isEmpty) return '';
      url = url.replaceFirst('http:', 'https:');
      if (url.contains('akamaized.net')) {
        url = url.replaceFirst('media-saavn.akamaized.net', 'aac.saavncdn.com');
      }
      if (prefer320) {
        url = url.replaceAll('_96.mp4', '_320.mp4').replaceAll('_160.mp4', '_320.mp4');
      }
      return url;
    } catch (_) {}
    return '';
  }

  factory SongModel.fromSaavnReco(Map<String, dynamic> json, {String quality = '320kbps'}) {
    final moreInfo = json['more_info'] is Map ? json['more_info'] as Map<String, dynamic> : const <String, dynamic>{};
    final is320 = moreInfo['320kbps']?.toString() == 'true';
    final encUrl = moreInfo['encrypted_media_url']?.toString() ?? '';
    var downloadUrl = '';
    if (encUrl.isNotEmpty) {
      downloadUrl = _decrypt(encUrl, prefer320: quality == '320kbps');
    }
    
    final img = hiResImage(json['image']?.toString() ?? '');
    
    String artistsStr = 'Unknown Artist';
    final artistMap = moreInfo['artistMap'] is Map ? moreInfo['artistMap'] as Map<String, dynamic> : null;
    if (artistMap != null && artistMap['primary_artists'] is List) {
      final list = artistMap['primary_artists'] as List;
      final names = list
          .whereType<Map>()
          .map((a) => a['name']?.toString())
          .whereType<String>()
          .toList();
      if (names.isNotEmpty) {
        artistsStr = names.join(', ');
      }
    }

    return SongModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown',
      artist: artistsStr,
      album: moreInfo['album']?.toString() ?? 'Single',
      image: img,
      duration: Duration(seconds: int.tryParse(moreInfo['duration']?.toString() ?? '0') ?? 0),
      url: downloadUrl,
      lyrics: json['lyrics']?.toString(),
    );
  }

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? image,
    Duration? duration,
    String? url,
    String? lyrics,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      image: image ?? this.image,
      duration: duration ?? this.duration,
      url: url ?? this.url,
      lyrics: lyrics ?? this.lyrics,
    );
  }
}
