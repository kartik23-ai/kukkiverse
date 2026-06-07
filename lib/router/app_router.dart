import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/navigation/app_transitions.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/premium/premium_screen.dart';
import '../screens/main/main_screen.dart';
import '../screens/desktop/desktop_shell.dart';
import '../screens/search/search_screen.dart';
import '../screens/player/player_screen.dart';
import '../screens/lyrics/lyrics_screen.dart';
import '../screens/lyrics/lyrics_clip_studio.dart';
import '../screens/playlist/playlist_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/about_screen.dart';
import '../screens/settings/support_screen.dart';
import '../screens/settings/contact_support_screen.dart';
import '../screens/album/album_screen.dart';
import '../screens/artist/artist_screen.dart';
import '../screens/queue/queue_screen.dart';
import '../screens/dj/dual_deck_screen.dart';
import '../screens/concert/concert_screen.dart';
import '../screens/scenes/scenes_screen.dart';
import '../screens/party/party_sync_screen.dart';
import '../screens/memory/memory_lane_screen.dart';
import '../screens/wrapped/weekly_wrapped_screen.dart';
import '../screens/labs/labs_hub_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/labs/studio_lab_screen.dart';
import '../screens/labs/time_machine_screen.dart';
import '../screens/labs/sleep_oracle_screen.dart';
import '../screens/labs/vault_screen.dart';
import '../screens/labs/mood_shake_screen.dart';
import '../screens/labs/vibe_match_screen.dart';
import '../screens/labs/reverse_discover_screen.dart';
import '../screens/labs/focus_lock_screen.dart';
import '../screens/labs/ai_mix_blend_setup_screen.dart';
import '../screens/labs/ai_studio_screen.dart';
import '../screens/playlist/studio_detail_screen.dart';
import '../screens/lyrics/lyrics_cinema_screen.dart';
import '../screens/drive/night_drive_screen.dart';
import '../screens/focus/focus_screen.dart';
import '../screens/sleep/sleep_screen.dart';
import '../screens/onboarding/taste_selection_screen.dart';
import '../screens/desktop/desktop_taste_screen.dart';
import '../providers/feature_providers.dart';
import '../models/song_model.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(
      path: '/taste-selection',
      pageBuilder: (context, state) {
        final isOnboarding = state.uri.queryParameters['onboarding'] == 'true';
        if (Theme.of(context).platform == TargetPlatform.windows) {
          return rottyPage(
            child: DesktopTasteScreen(isOnboarding: isOnboarding),
            from: AxisDirection.right,
          );
        }
        return rottyPage(
          child: TasteSelectionScreen(isOnboarding: isOnboarding),
          from: AxisDirection.right,
        );
      },
    ),
    GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
    GoRoute(path: '/premium', pageBuilder: (_, __) => rottyPage(child: const PremiumScreen(), from: AxisDirection.up)),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/home', builder: (context, __) {
      if (Theme.of(context).platform == TargetPlatform.windows) {
        return const DesktopShell();
      }
      return const MainScreen();
    }),
    GoRoute(
      path: '/search',
      pageBuilder: (_, __) => rottyPage(child: const SearchScreen(), from: AxisDirection.right),
    ),
    GoRoute(
      path: '/player',
      pageBuilder: (_, __) => rottyPage(child: const PlayerScreen(), from: AxisDirection.up),
      redirect: (context, state) {
        if (Theme.of(context).platform == TargetPlatform.windows) {
          return '/home';
        }
        return null;
      },
    ),
    GoRoute(
      path: '/lyrics/:id',
      pageBuilder: (context, state) => rottyPage(
        child: LyricsScreen(songId: state.pathParameters['id'] ?? ''),
        from: AxisDirection.up,
      ),
    ),
    GoRoute(
      path: '/lyrics-clip/:id',
      pageBuilder: (context, state) => rottyPage(
        child: LyricsClipStudio(songId: state.pathParameters['id'] ?? ''),
        from: AxisDirection.up,
      ),
    ),
    GoRoute(
      path: '/album/:id',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return rottyPage(
          child: AlbumScreen(
            albumId: state.pathParameters['id'] ?? '',
            title: extra?['title']?.toString() ?? 'Album',
            songs: extra?['songs'] as List<SongModel>?,
            image: extra?['image']?.toString(),
          ),
          from: AxisDirection.right,
        );
      },
    ),
    GoRoute(
      path: '/artist/:id',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return rottyPage(
          child: ArtistScreen(
            artistId: state.pathParameters['id'] ?? '',
            name: extra?['name']?.toString(),
            image: extra?['image']?.toString(),
          ),
          from: AxisDirection.right,
        );
      },
    ),
    GoRoute(
      path: '/queue',
      pageBuilder: (_, __) => rottyPage(child: const QueueScreen(), from: AxisDirection.up),
    ),
    GoRoute(path: '/dj', pageBuilder: (_, __) => rottyPage(child: const DualDeckScreen(), from: AxisDirection.up)),
    GoRoute(path: '/concert', pageBuilder: (_, __) => rottyPage(child: const ConcertScreen(), from: AxisDirection.up)),
    GoRoute(path: '/scenes', pageBuilder: (_, __) => rottyPage(child: const ScenesScreen(), from: AxisDirection.right)),
    GoRoute(
      path: '/scene/:id',
      pageBuilder: (context, state) {
        final scene = state.extra as DiscoverScene? ?? DiscoverScene.lateNight;
        return rottyPage(child: SceneDetailScreen(scene: scene), from: AxisDirection.right);
      },
    ),
    GoRoute(path: '/party', pageBuilder: (_, __) => rottyPage(child: const PartySyncScreen(), from: AxisDirection.right)),
    GoRoute(path: '/memory', pageBuilder: (_, __) => rottyPage(child: const MemoryLaneScreen(), from: AxisDirection.right)),
    GoRoute(path: '/wrapped', pageBuilder: (_, __) => rottyPage(child: const WeeklyWrappedScreen(), from: AxisDirection.up)),
    GoRoute(path: '/library', builder: (_, __) => const PlaylistScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/admin', pageBuilder: (_, __) => rottyPage(child: const AdminDashboardScreen(), from: AxisDirection.right)),
    GoRoute(path: '/labs', pageBuilder: (_, __) => rottyPage(child: const LabsHubScreen(), from: AxisDirection.right)),
    GoRoute(path: '/labs/studio', pageBuilder: (_, __) => rottyPage(child: const StudioLabScreen(), from: AxisDirection.right)),
    GoRoute(path: '/labs/time-machine', pageBuilder: (_, __) => rottyPage(child: const TimeMachineScreen(), from: AxisDirection.right)),
    GoRoute(path: '/labs/sleep', pageBuilder: (_, __) => rottyPage(child: const SleepOracleScreen(), from: AxisDirection.right)),
    GoRoute(path: '/labs/vault', pageBuilder: (_, __) => rottyPage(child: const VaultScreen(), from: AxisDirection.right)),
    GoRoute(path: '/labs/shake', pageBuilder: (_, __) => rottyPage(child: const MoodShakeScreen(), from: AxisDirection.right)),
    GoRoute(path: '/labs/vibe', pageBuilder: (_, __) => rottyPage(child: const VibeMatchScreen(), from: AxisDirection.right)),
    GoRoute(path: '/labs/reverse', pageBuilder: (_, __) => rottyPage(child: const ReverseDiscoverScreen(), from: AxisDirection.right)),
    GoRoute(path: '/labs/focus', pageBuilder: (_, __) => rottyPage(child: const FocusLockScreen(), from: AxisDirection.right)),
    GoRoute(path: '/labs/blend', pageBuilder: (_, __) => rottyPage(child: const AIMixBlendSetupScreen(), from: AxisDirection.right)),
    GoRoute(
      path: '/labs/ai-studio',
      pageBuilder: (_, __) => rottyPage(child: const AIStudioScreen(), from: AxisDirection.right),
      redirect: (context, state) => '/labs',
    ),
    GoRoute(
      path: '/library/studio/:id',
      pageBuilder: (context, state) => rottyPage(
        child: StudioDetailScreen(studioId: state.pathParameters['id'] ?? ''),
        from: AxisDirection.right,
      ),
    ),
    GoRoute(
      path: '/cinema/:id',
      pageBuilder: (context, state) => rottyPage(
        child: LyricsCinemaScreen(songId: state.pathParameters['id'] ?? ''),
        from: AxisDirection.up,
      ),
    ),
    GoRoute(path: '/drive', pageBuilder: (_, __) => rottyPage(child: const NightDriveScreen(), from: AxisDirection.up)),
    GoRoute(path: '/focus', pageBuilder: (_, __) => rottyPage(child: const FocusScreen(), from: AxisDirection.up)),
    GoRoute(path: '/sleep', pageBuilder: (_, __) => rottyPage(child: const SleepScreen(), from: AxisDirection.up)),
    GoRoute(
      path: '/about',
      pageBuilder: (_, __) => rottyPage(child: const AboutScreen(), from: AxisDirection.right),
    ),
    GoRoute(
      path: '/support',
      pageBuilder: (_, __) => rottyPage(child: const SupportScreen(), from: AxisDirection.right),
    ),
    GoRoute(
      path: '/contact-support',
      pageBuilder: (_, __) => rottyPage(child: const ContactSupportScreen(), from: AxisDirection.right),
    ),
  ],
);
