import '../../services/storage_service.dart';

class ApiConstants {
  static const String baseUrl = 'https://www.jiosaavn.com/api.php';
  static const String fallbackBaseUrl = 'https://saavn.sumit.co/api';
  static const String lyricsMirrorUrl = 'https://jiosaavn-api.vercel.app/lyrics';
  
  static String get backendUrl {
    final customIp = StorageService().customBackendIp;
    if (customIp.isNotEmpty) {
      if (customIp.startsWith('http://') || customIp.startsWith('https://')) {
        return customIp;
      }
      return 'http://$customIp:3000';
    }
    return 'https://kukkiverse-production.up.railway.app';
  }
  
  static const Duration timeout = Duration(seconds: 15);

  static const Map<String, String> homeQueries = {
    'Trending': 'trending hindi',
    'Top Hits': 'top hindi songs',
    'Bollywood': 'bollywood hits',
    'Punjabi': 'punjabi hits',
  };

  static const List<String> trendingSearches = [
    'Arijit Singh',
    'AP Dhillon',
    'Kesariya',
    'Chaleya',
    'Taylor Swift',
    'Ed Sheeran',
    'Dhurandhar',
    'Heeriye',
  ];
}
