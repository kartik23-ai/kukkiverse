class ApiConstants {
  static const String baseUrl = 'https://www.jiosaavn.com/api.php';
  static const String fallbackBaseUrl = 'https://saavn.sumit.co/api';
  static const String lyricsMirrorUrl = 'https://jiosaavn-api.vercel.app/lyrics';
  static const String backendUrl = 'https://kukkiverse-production.up.railway.app';
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
