import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_secrets.dart';
import 'services/storage_service.dart';
import 'services/audio_handler.dart';
import 'services/audio_effects.dart';
import 'services/firebase_service.dart';
import 'services/rotty_connect_service.dart';
import 'providers/providers.dart';
import 'providers/premium_providers.dart';
import 'providers/feature_providers.dart';
import 'services/update_service.dart';
import 'screens/main/update_lock_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/dynamic_palette.dart';
import 'core/theme/time_theme.dart';
import 'router/app_router.dart';

final updateLockProvider = ChangeNotifierProvider<UpdateService>((ref) {
  return UpdateService.instance;
});

late RottyAudioHandler _audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Color(0xFF050508),
      titleBarStyle: TitleBarStyle.hidden,
      skipTaskbar: false,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Only set mobile-specific UI chrome on mobile platforms
  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  final storage = StorageService();
  await storage.init();

  try {
    await Supabase.initialize(
      url: AppSecrets.supabaseUrl,
      anonKey: AppSecrets.supabaseAnonKey,
    );
    debugPrint('[Supabase] Initialized successfully');
  } catch (e) {
    debugPrint('[Supabase] Init error: $e');
  }

  if (AppSecrets.hasGroq && storage.groqApiKey.isEmpty) {
    await storage.setGroqApiKey(AppSecrets.groqApiKey);
  }

  await FirebaseService.instance.init().timeout(const Duration(seconds: 4), onTimeout: () => true);
  if (FirebaseService.instance.isReady) {
    // Run network integrations asynchronously in the background to prevent blocking UI startup when offline
    RottyConnectService.instance.init(FirebaseService.instance.userId).catchError((e) {
      debugPrint('[RottyConnect] Init failed in background: $e');
    });
    if (FirebaseService.instance.currentUser != null) {
      FirebaseService.instance.pullUserData().catchError((e) {
        debugPrint('pullUserData failed in background: $e');
      });
      FirebaseService.instance.syncUserData().catchError((e) {
        debugPrint('syncUserData failed in background: $e');
      });
    }
  }

  // Trigger background version OTA and Firestore configuration checking
  UpdateService.instance.checkForUpdates();
  final eq = StorageService().loadStudioEq();
  RottyAudioEffects.bass = eq.bass;
  RottyAudioEffects.treble = eq.treble;
  RottyAudioEffects.vocal = eq.vocal;
  RottyAudioEffects.width = eq.width;
  RottyAudioEffects.orbitSpeed = eq.orbitSpeed;
  RottyAudioEffects.orbit8d = eq.orbit8d;
  RottyAudioEffects.infiniteBlend = StorageService().getBoolFlag('infinite_blend');
  RottyAudioEffects.applySoundSpace(storage.soundSpace);

  // AudioService.init with notification on mobile and Windows
  if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
    _audioHandler = await AudioService.init(
      builder: () => RottyAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.rottymusic.rotty_music.audio',
        androidNotificationChannelName: 'ROTTY MUSIC',
        androidNotificationOngoing: false, // Changed to false to satisfy assertion when stopForegroundOnPause is false
        androidStopForegroundOnPause: false, // Prevent foreground service from stopping on pause, stabilizing background execution
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
  } else {
    // Other Desktop: raw handler
    _audioHandler = RottyAudioHandler();
  }

  runApp(ProviderScope(
    overrides: [
      audioHandlerProvider.overrideWithValue(_audioHandler),
    ],
    child: const RottyApp(),
  ));
}

class RottyApp extends ConsumerWidget {
  const RottyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(dynamicPaletteProvider);
    final auraFull = ref.watch(auraFullAppProvider);
    final timeTheme = ref.watch(timeThemeProvider);
    final updateLock = ref.watch(updateLockProvider);

    final accent = auraFull ? palette.primary : const Color(0xFFFA2D48);

    return MaterialApp.router(
      title: 'ROTTY MUSIC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark.copyWith(
        scaffoldBackgroundColor: timeTheme.bgDeep,
        colorScheme: ColorScheme.dark(
          primary: accent,
          secondary: palette.secondary,
          surface: timeTheme.bgSurface,
          onSurface: timeTheme.textPrimary,
        ),
      ),
      routerConfig: appRouter,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            if (updateLock.isLockActive) const UpdateLockScreen(),
          ],
        );
      },
    );
  }
}
