import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  static const _tabs = [
    (Icons.home_rounded, 'Listen Now'),
    (Icons.search_rounded, 'Search'),
    (Icons.library_music_rounded, 'Library'),
    (Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.initialize(context, ref);
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: (party.code != null && (tab == 0 || tab == 1 || tab == 2))
                        ? PartyLockOverlay(
                            key: const ValueKey('tab_party_lock'),
                            roomCode: party.code!,
                            isHost: party.isHost,
                          )
                        : switch (tab) {
                            0 => const HomeScreen(key: ValueKey('tab_home')),
                            1 => const SearchScreen(key: ValueKey('tab_search'), embedded: true),
                            2 => const PlaylistScreen(key: ValueKey('tab_lib')),
                            _ => const SettingsScreen(key: ValueKey('tab_set'), embedded: true),
                          },
                  ),
                ),
                const MiniPlayer(),
                // Bottom nav — adapts to mode + time theme
                AnimatedContainer(
                  duration: ModeTheme.transitionDuration,
                  decoration: BoxDecoration(
                    color: (mode == RottyAppMode.normal ? tt.bgSurface : mt.bg).withValues(alpha: 0.92),
                    border: Border(
                      top: BorderSide(
                        color: (mode == RottyAppMode.normal ? tt.glassEdge : mt.accent.withValues(alpha: 0.15)),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: mode == RottyAppMode.drive ? 72 : (mode == RottyAppMode.focus ? 52 : 60),
                      child: Row(
                        children: List.generate(_tabs.length, (i) {
                          final selected = tab == i;
                          return Expanded(
                            child: InkWell(
                              onTap: () => ref.read(mainTabIndexProvider.notifier).state = i,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: selected ? 16 : 0,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: selected ? mt.accent.withValues(alpha: 0.12) : Colors.transparent,
                                    ),
                                    child: Icon(
                                      _tabs[i].$1,
                                      size: selected
                                          ? (mode == RottyAppMode.drive ? 30 : 26)
                                          : (mode == RottyAppMode.drive ? 24 : 22),
                                      color: selected ? mt.accent : mt.textSecondary,
                                    ),
                                  ),
                                  if (mode != RottyAppMode.focus) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _tabs[i].$2,
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                        color: selected ? mt.accent : mt.textSecondary,
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
}
