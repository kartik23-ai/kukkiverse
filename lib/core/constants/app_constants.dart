class AppConstants {
  AppConstants._();

  static const String appName = 'ROTTY MUSIC';
  static const String appTagline = 'Feel The Future Of Music';
  static const String version = '1.2.0';

  // Hive boxes
  static const String playlistBox = 'playlists';
  static const String recentBox = 'recent_songs';
  static const String favoritesBox = 'favorites';
  static const String searchHistoryBox = 'search_history';
  static const String settingsBox = 'settings';
  static const String downloadedSongsBox = 'downloaded_songs';

  // SharedPrefs keys
  static const String onboardingDone = 'onboarding_done';
  static const String authSessionDone = 'auth_session_done';
  static const String premiumExpiresAt = 'premium_expires_at';
  static const String premiumTxnId = 'premium_last_txn_id';
  static const String audioQuality = 'audio_quality';
  static const String themeMode = 'theme_mode';
  static const String appMode = 'app_mode';
  static const String soundSpace = 'sound_space';
  static const String zenMode = 'zen_mode';
  static const String playHistoryBox = 'play_history';
  static const String partyRoomBox = 'party_room';
  static const String offlinePacksBox = 'offline_packs';
  static const String interactiveOnboardingDone = 'interactive_onboarding_done';
  static const String auraFullApp = 'aura_full_app';
  static const String hapticLyrics = 'haptic_lyrics';
  static const String streakCount = 'streak_count';
  static const String streakLastDate = 'streak_last_date';
  static const String dislikedSongs = 'disliked_songs';
  static const String vaultPin = 'vault_pin';
  static const String studioEqJson = 'studio_eq_json';

  // Audio qualities
  static const String quality96 = '_96.mp4';
  static const String quality160 = '_160.mp4';
  static const String quality320 = '_320.mp4';

  // Home page search queries for sections
  static const List<String> trendingQueries = [
    'trending hindi 2026',
    'latest bollywood',
    'top hindi songs',
  ];

  static const List<String> moodQueries = [
    'romantic songs',
    'party songs',
    'sad songs',
    'workout songs',
    'chill vibes',
    'devotional',
  ];
}
