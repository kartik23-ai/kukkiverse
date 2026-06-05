import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../home/home_screen.dart';
import '../search/search_screen.dart';
import '../playlist/playlist_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/party_lock_overlay.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/first_launch_support_overlay.dart';
import '../../widgets/elite_background.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/mode_theme.dart';
import '../../core/theme/time_theme.dart';
import '../../core/modes/app_mode.dart';
import '../../providers/providers.dart';
import '../../providers/premium_providers.dart';
import '../../providers/feature_providers.dart';
import '../../services/notification_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  static const _tabs = [
    (Icons.home_rounded, 'Listen Now'),
    (Icons.search_rounded, 'Search'),
    (Icons.library_music_rounded, 'Library'),
    (Icons.tune_rounded, 'Settings'),
  ];

  StreamSubscription<UserAccelerometerEvent>? _shakeSubscription;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: ref.read(mainTabIndexProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupShakeListener();
    });
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupShakeListener();
  }

  void _setupShakeListener() {
    final enabled = ref.read(globalShakeToSkipProvider);
    if (enabled) {
      if (_shakeSubscription == null) {
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          try {
            _shakeSubscription = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen((e) {
              final force = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
              if (force < 18) return;
              final now = DateTime.now();
              if (now.difference(_lastShake).inMilliseconds < 1500) return;
              _lastShake = now;
              _triggerShakeSkip();
            });
          } catch (_) {}
        }
      }
    } else {
      _shakeSubscription?.cancel();
      _shakeSubscription = null;
    }
  }

  Future<void> _triggerShakeSkip() async {
    final handler = ref.read(audioHandlerProvider);
    HapticFeedback.mediumImpact();
    await handler.skipToNext();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.accent,
          duration: Duration(seconds: 1),
          content: Text('⚡ Shake to Skip triggered!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.initialize(context, ref);
    });

    ref.listen<bool>(globalShakeToSkipProvider, (prev, next) {
      _setupShakeListener();
    });

    ref.listen<int>(mainTabIndexProvider, (prev, next) {
      if (next != prev && _pageController.hasClients) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });

    final tab = ref.watch(mainTabIndexProvider);
    final mode = ref.watch(appModeProvider);
    final mt = ModeTheme(mode);
    final tt = ref.watch(timeThemeProvider);
    final showOverlay = ref.watch(supportOverlayVisibilityProvider);
    final party = ref.watch(partyRoomProvider);

    // Blend mode bg with time-of-day bg
    final dynamicBg = mode == RottyAppMode.normal ? tt.bgDeep : mt.bg;

    final scaffold = Scaffold(
      backgroundColor: dynamicBg,
      body: AnimatedContainer(
        duration: ModeTheme.transitionDuration,
        curve: ModeTheme.transitionCurve,
        color: dynamicBg,
        child: AnimatedOpacity(
          opacity: mt.uiOpacity,
          duration: ModeTheme.transitionDuration,
          curve: ModeTheme.transitionCurve,
          child: RottyAuroraBackground(
            intensity: mt.auroraIntensity,
            child: Stack(
              children: [
                // 1. Content Pages switcher (full height)
                Positioned.fill(
                  child: Column(
                    children: [
                      // Mode indicator bar — shows current mode at top
                      if (mode != RottyAppMode.normal)
                        SafeArea(
                          bottom: false,
                          child: AnimatedContainer(
                            duration: ModeTheme.transitionDuration,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: mt.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: mt.accent.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        switch (mode) {
                                          RottyAppMode.focus => Icons.self_improvement_rounded,
                                          RottyAppMode.drive => Icons.speed_rounded,
                                          RottyAppMode.sleep => Icons.bedtime_rounded,
                                          _ => Icons.music_note_rounded,
                                        },
                                        color: mt.accent,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${mt.modeTitle} MODE',
                                        style: GoogleFonts.inter(
                                          color: mt.accent,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: (party.code != null && (tab == 0 || tab == 1 || tab == 2))
                            ? PartyLockOverlay(
                                key: const ValueKey('tab_party_lock'),
                                roomCode: party.code!,
                                isHost: party.isHost,
                              )
                            : RepaintBoundary(
                                child: PageView(
                                  controller: _pageController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    KeepAliveWrapper(child: const HomeScreen(key: ValueKey('tab_home'))),
                                    KeepAliveWrapper(child: const SearchScreen(key: ValueKey('tab_search'), embedded: true)),
                                    KeepAliveWrapper(child: const PlaylistScreen(key: ValueKey('tab_lib'), embedded: true)),
                                    KeepAliveWrapper(child: const SettingsScreen(key: ValueKey('tab_set'), embedded: true)),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                // 2. Floating elements stacked at the bottom (MiniPlayer and Floating Bottom Nav)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: RepaintBoundary(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MiniPlayer(),
                        _buildFloatingBottomNavBar(context, ref, tab, mode, mt, tt),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        scaffold,
        if (showOverlay)
          FirstLaunchSupportOverlay(
            onDismissed: () => ref.read(supportOverlayVisibilityProvider.notifier).dismiss(),
          ),
      ],
    );
  }

  Widget _buildFloatingBottomNavBar(
      BuildContext context, WidgetRef ref, int tab, RottyAppMode mode, ModeTheme mt, TimeThemeData tt) {
    final double barHeight = mode == RottyAppMode.drive ? 68 : (mode == RottyAppMode.focus ? 50 : 58);
    final bottomMargin = max(12.0, MediaQuery.of(context).padding.bottom);
    
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF161522).withValues(alpha: 0.85),
              const Color(0xFF0D0C14).withValues(alpha: 0.90),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Builder(
            builder: (context) {
              final useBlur = ref.watch(albumArtRipplesProvider);
              final content = Stack(
                children: [
                  // 1. Sliding pill background indicator
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment(-1.0 + (tab * 2.0 / (_tabs.length - 1)), 0.0),
                    child: FractionallySizedBox(
                      widthFactor: 1 / _tabs.length,
                      heightFactor: 0.82,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: [
                                mt.accent.withValues(alpha: 0.22),
                                mt.accent.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: mt.accent.withValues(alpha: 0.25),
                              width: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 2. Tab items
                  Row(
                    children: List.generate(_tabs.length, (i) {
                      final selected = tab == i;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            FocusManager.instance.primaryFocus?.unfocus();
                            ref.read(mainTabIndexProvider.notifier).state = i;
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _tabs[i].$1,
                                size: selected
                                    ? (mode == RottyAppMode.drive ? 28 : 24)
                                    : (mode == RottyAppMode.drive ? 23 : 20),
                                color: selected ? Colors.white : mt.textSecondary,
                              ),
                              if (mode != RottyAppMode.focus) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _tabs[i].$2,
                                  style: GoogleFonts.inter(
                                    fontSize: 8.5,
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                                    color: selected ? Colors.white : mt.textSecondary,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
              
              return useBlur
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: content,
                    )
                  : content;
            },
          ),
        ),
      ),
    );
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}
