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
import 'services/update_service.dart';
import 'screens/main/update_lock_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/time_theme.dart';
import 'router/app_router.dart';

final updateLockProvider = ChangeNotifierProvider<UpdateService>((ref) {
  return UpdateService.instance;
});

class RottyErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;
  const RottyErrorWidget({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF050508),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF16162A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  blurRadius: 32,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 30),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Rendering Halt',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A visual rendering exception occurred. We have isolated this error to keep the rest of the application running.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    details.exceptionAsString(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

late RottyAudioHandler _audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Error UI instead of Red Screen of Death
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return RottyErrorWidget(details: details);
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('GLOBAL FLUTTER ERROR: ${details.exceptionAsString()}');
  };

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

  if (AppSecrets.hasGroq && storage.groqApiKey.isEmpty) {
    await storage.setGroqApiKey(AppSecrets.groqApiKey);
  }

  // Optimize startup time by running non-dependent initializations concurrently
  await Future.wait([
    (() async {
      try {
        await Supabase.initialize(
          url: AppSecrets.supabaseUrl,
          anonKey: AppSecrets.supabaseAnonKey,
        );
        debugPrint('[Supabase] Initialized successfully');
      } catch (e) {
        debugPrint('[Supabase] Init error: $e');
      }
    })(),
    (() async {
      try {
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
      } catch (e) {
        debugPrint('[Firebase] Concurrent init error: $e');
      }
    })(),
    (() async {
      try {
        // AudioService.init with notification on mobile and Windows
        if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
          _audioHandler = await AudioService.init(
            builder: () => RottyAudioHandler(),
            config: AudioServiceConfig(
              androidNotificationChannelId: 'com.rottymusic.rotty_music.audio',
              androidNotificationChannelName: 'ROTTY MUSIC',
              androidNotificationOngoing: false,
              androidStopForegroundOnPause: false,
              androidNotificationIcon: 'mipmap/ic_launcher',
            ),
          );
        } else {
          // Other Desktop: raw handler
          _audioHandler = RottyAudioHandler();
        }
      } catch (e) {
        debugPrint('[AudioService] Concurrent init error: $e');
        // Fallback: create raw handler directly if AudioService.init crashes
        _audioHandler = RottyAudioHandler();
      }
    })(),
  ]);

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
