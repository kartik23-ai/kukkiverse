import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'core/config/app_secrets.dart';
import 'services/storage_service.dart';
import 'services/audio_handler.dart';
import 'services/audio_effects.dart';
import 'services/firebase_service.dart';
import 'providers/providers.dart';
import 'providers/premium_providers.dart';
import 'providers/feature_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/dynamic_palette.dart';
import 'router/app_router.dart';

late RottyAudioHandler _audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  await FirebaseService.instance.init();
  if (FirebaseService.instance.isReady && FirebaseService.instance.currentUser != null) {
    await FirebaseService.instance.pullUserData();
    await FirebaseService.instance.syncUserData();
  }
  final eq = StorageService().loadStudioEq();
  RottyAudioEffects.bass = eq.bass;
  RottyAudioEffects.treble = eq.treble;
  RottyAudioEffects.vocal = eq.vocal;
  RottyAudioEffects.width = eq.width;
  RottyAudioEffects.orbitSpeed = eq.orbitSpeed;
  RottyAudioEffects.orbit8d = eq.orbit8d;
  RottyAudioEffects.infiniteBlend = StorageService().getBoolFlag('infinite_blend');
  RottyAudioEffects.applySoundSpace(storage.soundSpace);

  // AudioService.init with notification only on mobile
  if (Platform.isAndroid || Platform.isIOS) {
    _audioHandler = await AudioService.init(
      builder: () => RottyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.rottymusic.rotty_music.audio',
        androidNotificationChannelName: 'ROTTY MUSIC',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
  } else {
    // Desktop: no AudioService wrapper, just raw handler
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

    final accent = auraFull ? palette.primary : const Color(0xFFFA2D48);

    return MaterialApp.router(
      title: 'ROTTY MUSIC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark.copyWith(
        colorScheme: ColorScheme.dark(
          primary: accent,
          secondary: palette.secondary,
          surface: const Color(0xFF121212),
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
