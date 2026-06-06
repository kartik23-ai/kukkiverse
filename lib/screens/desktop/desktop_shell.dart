import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/mode_theme.dart';
import '../../core/modes/app_mode.dart';
import '../../core/sound/sound_space.dart';
import '../../providers/providers.dart';
import '../../providers/premium_providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/first_launch_support_overlay.dart';
import '../../utils/play_song.dart';
import 'desktop_sidebar.dart';
import 'desktop_player_bar.dart';
import 'desktop_home.dart';
import 'desktop_search.dart';
import 'desktop_now_playing.dart';
import 'desktop_full_screen.dart';
import '../../services/spotify_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart';
import '../../models/song_model.dart';
import '../../widgets/desktop_song_row.dart';
import '../../widgets/desktop_titlebar.dart';
import '../../widgets/party_lock_overlay.dart';


/// ═══════════════════════════════════════════════════════════════
/// Desktop Shell 4.0 — Liquid Glass Architecture
/// Aurora background, translucent panels, no opaque black
/// [Sidebar 240px] [Content flex] [NowPlaying 300px]
/// Bottom: [Player Bar 90px]
/// Tabs: Home, Search, Library, Labs, Settings
/// ═══════════════════════════════════════════════════════════════
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _tab = 0;
  bool _showNowPlaying = true;
  bool _fullScreen = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.initialize(context, ref);
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.dispose();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // CRITICAL: Don't intercept when typing in a TextField or EditableText
    final pf = FocusManager.instance.primaryFocus;
    if (pf != null) {
      final ctx = pf.context;
      if (ctx != null && ctx.findAncestorWidgetOfExactType<EditableText>() != null) {
        return false;
      }
    }

    final handler = ref.read(audioHandlerProvider);

    if (event.logicalKey == LogicalKeyboardKey.space) {
      final playing = ref.read(isPlayingProvider);
      playing ? handler.pause() : handler.play();
      return true;
    }
    if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.arrowRight) {
      handler.skipToNext();
      return true;
    }
    if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      handler.skipToPrevious();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      setState(() => _showNowPlaying = !_showNowPlaying);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      setState(() => _fullScreen = !_fullScreen);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appModeProvider);
    final mt = ModeTheme(mode);
    final palette = ref.watch(dynamicPaletteProvider);
    final showOverlay = ref.watch(supportOverlayVisibilityProvider);
    final party = ref.watch(partyRoomProvider);

    final shell = Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: RottyDynamicAuroraBackground(
        intensity: 0.7,
        child: Column(
          children: [
            const DesktopTitlebar(),
            // Mode indicator
            if (mode != RottyAppMode.normal)
              _ModeIndicator(mode: mode, mt: mt),
            // Main area
            Expanded(
              child: Row(
                children: [
                  DesktopSidebar(
                    activeTab: _tab,
                    onTabChanged: (i) => setState(() => _tab = i),
                  ),
                  // Center content
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: _buildTab(party),
                    ),
                  ),
                  // Right panel
                  ClipRect(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: _showNowPlaying ? 300 : 0,
                      child: _showNowPlaying
                          ? const DesktopNowPlaying()
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
            DesktopPlayerBar(
              onToggleFullScreen: () => setState(() => _fullScreen = true),
              onToggleNowPlaying: () => setState(() => _showNowPlaying = !_showNowPlaying),
            ),
          ],
        ),
      ),
    );

    Widget display = shell;

    if (_fullScreen) {
      display = Stack(
        children: [
          shell,
          DesktopFullScreen(onClose: () => setState(() => _fullScreen = false)),
        ],
      );
    }

    return Stack(
      children: [
        display,
        if (showOverlay)
          FirstLaunchSupportOverlay(
            onDismissed: () => ref.read(supportOverlayVisibilityProvider.notifier).dismiss(),
          ),
      ],
    );
  }

  Widget _buildTab(PartyRoomState party) {
    if (party.code != null && (_tab == 0 || _tab == 1 || _tab == 2)) {
      return PartyLockOverlay(
        key: const ValueKey('d_party_lock'),
        roomCode: party.code!,
        isHost: party.isHost,
      );
    }
    return switch (_tab) {
      0 => const DesktopHome(key: ValueKey('d_home')),
      1 => const DesktopSearch(key: ValueKey('d_search')),
      2 => const _DesktopLibrary(key: ValueKey('d_lib')),
      3 => const _DesktopLabs(key: ValueKey('d_labs')),
      _ => const _DesktopSettings(key: ValueKey('d_set')),
    };
  }
}

/// ─── Mode Indicator ───
class _ModeIndicator extends StatelessWidget {
  const _ModeIndicator({required this.mode, required this.mt});
  final RottyAppMode mode;
  final ModeTheme mt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          LiquidGlassButton(
            accentColor: mt.accent,
            isActive: true,
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
                  color: mt.accent, size: 14,
                ),
                const SizedBox(width: 6),
                Text('${mt.modeTitle} MODE', style: TextStyle(color: mt.accent, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Desktop Library — Liquid glass chips, hover tiles
/// ═══════════════════════════════════════════════════════════════
class _DesktopLibrary extends ConsumerStatefulWidget {
  const _DesktopLibrary({super.key});
  @override
  ConsumerState<_DesktopLibrary> createState() => _DesktopLibraryState();
}

class _DesktopLibraryState extends ConsumerState<_DesktopLibrary> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider).where((p) => !p.isPrivate).toList();
    final favorites = ref.watch(favoritesProvider);
    final recent = ref.watch(recentSongsProvider);
    final downloaded = ref.watch(downloadedSongsProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 100),
      children: [
        Row(
          children: [
            Expanded(child: Text('Library', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white))),
            LiquidGlassButton(
              accentColor: palette.primary,
              onTap: () => _createPlaylist(context, palette.primary),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: palette.primary),
                  const SizedBox(width: 6),
                  Text('New Playlist', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.primary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            LiquidGlassButton(
              accentColor: const Color(0xFF1DB954),
              onTap: () => _syncSpotifyPlaylist(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF1DB954)),
                  const SizedBox(width: 6),
                  Text('Sync Spotify', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1DB954))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Chips
        Row(
          children: [
            for (final (label, idx) in [('Playlists', 0), ('Liked', 1), ('Recent', 2), ('Downloaded', 3)]) ...[
              LiquidGlassButton(
                accentColor: palette.primary,
                isActive: _tab == idx,
                onTap: () => setState(() => _tab = idx),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                borderRadius: 20,
                child: Text(label, style: GoogleFonts.inter(color: _tab == idx ? palette.primary : Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 20),
        if (_tab == 0) ...[
          _LibTile(Icons.favorite_rounded, AppColors.accent, 'Liked Songs', '${favorites.length} songs', () => setState(() => _tab = 1)),
          _LibTile(Icons.history_rounded, const Color(0xFF7B61FF), 'Recently Played', '${recent.length} songs', () => setState(() => _tab = 2)),
          _LibTile(Icons.download_done_rounded, Colors.green, 'Downloaded Songs', '${downloaded.length} songs', () => setState(() => _tab = 3)),
          ...playlists.map((p) => _LibTile(Icons.queue_music_rounded, palette.primary, p.name, '${p.songs.length} songs', () => context.push('/album/${p.id}', extra: {'title': p.name, 'songs': p.songs}))),
        ],
        if (_tab == 1) ..._songList(favorites),
        if (_tab == 2) ..._songList(recent),
        if (_tab == 3) ..._songList(downloaded),
      ],
    );
  }

  List<Widget> _songList(List songs) {
    if (songs.isEmpty) return [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('Empty', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.3)))))];
    return songs.map<Widget>((s) => DesktopSongRow(song: s as SongModel, playlist: songs.cast<SongModel>())).toList();
  }

  void _createPlaylist(BuildContext context, Color accent) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Playlist', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: c, autofocus: true,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Name', hintStyle: GoogleFonts.inter(color: Colors.white30),
            filled: true, fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) { if (v.trim().isNotEmpty) { ref.read(playlistsProvider.notifier).create(v.trim()); Navigator.pop(ctx); } },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38))),
          TextButton(onPressed: () { if (c.text.trim().isNotEmpty) { ref.read(playlistsProvider.notifier).create(c.text.trim()); Navigator.pop(ctx); } }, child: Text('Create', style: GoogleFonts.inter(color: accent, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Future<void> _syncSpotifyPlaylist(BuildContext context) async {
    final c = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.sync_rounded, color: Color(0xFF1DB954)),
                  const SizedBox(width: 10),
                  Text('Spotify Sync', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Paste a public Spotify playlist URL below to import its tracks.',
                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                      ),
                    )
                  else
                    TextField(
                      controller: c,
                      autofocus: true,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'https://open.spotify.com/playlist/...',
                        hintStyle: GoogleFonts.inter(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.03),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1DB954), width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                if (!isLoading) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final url = c.text.trim();
                      if (url.isEmpty) return;
                      setDialogState(() {
                        isLoading = true;
                      });
                      try {
                        final spotifyService = SpotifyService();
                        final playlist = await spotifyService.syncPlaylist(url);
                        
                        await ref.read(playlistsProvider.notifier).saveSyncedPlaylist(playlist);
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Successfully synced "${playlist.name}" (${playlist.songs.length} tracks)'),
                            ),
                          );
                        }
                        Navigator.pop(ctx);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                            ),
                          );
                        }
                        setDialogState(() {
                          isLoading = false;
                        });
                      }
                    },
                    child: Text('Sync', style: GoogleFonts.inter(color: const Color(0xFF1DB954), fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Desktop Labs — VIP logic FIXED, liquid glass cards
/// isPro=true means REQUIRES premium (same as Android)
/// ═══════════════════════════════════════════════════════════════
class _DesktopLabs extends ConsumerWidget {
  const _DesktopLabs({super.key});

  // (title, sub, icon, route, isPro)
  // isPro=true → needs premium, isPro=false → free for all
  // SAME as Android labs_hub_screen.dart
  static const _items = [
    ('Studio Lab', 'EQ • 8D orbit • presets', Icons.tune_rounded, '/labs/studio', false),
    ('Time Machine', 'Year + mood stations', Icons.history_edu_rounded, '/labs/time-machine', false),
    ('Sleep Oracle', 'Fade + ambient layers', Icons.bedtime_rounded, '/labs/sleep', false),
    ('Infinite Blend', 'Long crossfade mix', Icons.blur_on_rounded, '/labs/blend', false),
    ('Party Sync', 'Connect phone & laptop', Icons.celebration_rounded, '/party', false),
    ('Vault', 'PIN private playlists', Icons.lock_rounded, '/labs/vault', false),
    ('Vibe Match', 'Same energy queue', Icons.graphic_eq_rounded, '/labs/vibe', false),
    ('Reverse Discover', 'Teach from skips', Icons.thumb_down_off_alt_rounded, '/labs/reverse', false),
    ('Focus Lock', 'Pomodoro + music', Icons.timer_rounded, '/labs/focus', false),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(rottyPremiumProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 100),
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [palette.primary, const Color(0xFF7B61FF), const Color(0xFF00D4FF)],
              ).createShader(bounds),
              child: Text('ROTTY Labs', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Experimental tools • clean & fast', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
        const SizedBox(height: 24),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.6,
          ),
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final item = _items[i];
            // FIX: isPro=true means needs premium
            // locked = needs premium AND user is not premium
            final needsPremium = item.$5;
            final locked = needsPremium && !premium;
            return _DesktopLabCard(
              title: item.$1,
              sub: item.$2,
              icon: item.$3,
              isPro: false,
              locked: false,
              accent: palette.primary,
              onTap: () {
                context.push(item.$4);
              },
            );
          },
        ),
      ],
    );
  }
}

class _DesktopLabCard extends StatefulWidget {
  const _DesktopLabCard({required this.title, required this.sub, required this.icon, required this.isPro, required this.locked, required this.accent, required this.onTap});
  final String title, sub;
  final IconData icon;
  final bool isPro, locked;
  final Color accent;
  final VoidCallback onTap;
  @override
  State<_DesktopLabCard> createState() => _DesktopLabCardState();
}

class _DesktopLabCardState extends State<_DesktopLabCard> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      accentColor: widget.accent,
      onTap: widget.onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: widget.accent.withValues(alpha: 0.15),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 18),
              ),
              const Spacer(),
              if (widget.isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: widget.locked ? Colors.white.withValues(alpha: 0.08) : widget.accent.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    widget.locked ? '🔒 PRO' : '✓ PRO',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700,
                        color: widget.locked ? Colors.white.withValues(alpha: 0.4) : widget.accent),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(widget.sub, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Desktop Settings — Liquid glass, working toggles
/// ═══════════════════════════════════════════════════════════════
class _DesktopSettings extends ConsumerStatefulWidget {
  const _DesktopSettings({super.key});
  @override
  ConsumerState<_DesktopSettings> createState() => _DesktopSettingsState();
}

class _DesktopSettingsState extends ConsumerState<_DesktopSettings> {
  @override
  Widget build(BuildContext context) {
    final aiOn = ref.watch(aiDjEnabledProvider);
    final mode = ref.watch(appModeProvider);
    final sound = ref.watch(soundSpaceProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 100),
      children: [
        Text('Settings', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 28),

        _sectionHeader('Account & Support'),
        const SizedBox(height: 14),
        // Support Kartik Card
        LiquidGlassCard(
          accentColor: palette.primary,
          padding: const EdgeInsets.all(16),
          onTap: () => context.push('/support'), // Open direct to Support/Gift Developer screen
          child: Row(
            children: [
              const Icon(Icons.volunteer_activism_rounded, color: Colors.pinkAccent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Support Kartik & Gift ₹99', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Keep Rotty alive, fast & 100% ad-free forever', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
                  ],
                ),
              ),
              if (StorageService().isSupporter) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.pink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text('SUPPORTER 💖', style: GoogleFonts.inter(color: Colors.pinkAccent, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
              ],
              const Icon(Icons.chevron_right_rounded, color: Colors.white30),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Help & Support Card
        LiquidGlassCard(
          accentColor: palette.primary,
          padding: const EdgeInsets.all(16),
          onTap: () => context.push('/contact-support'),
          child: Row(
            children: [
              const Icon(Icons.support_agent_rounded, color: Colors.cyanAccent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Help & Support', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Submit feedback, bug reports or query to Kartik', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white30),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Edit Profile Card
        LiquidGlassCard(
          accentColor: palette.primary,
          padding: const EdgeInsets.all(16),
          onTap: _showEditProfileDialog,
          child: Row(
            children: [
              const Icon(Icons.person_outline_rounded, color: Colors.cyanAccent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Profile Name', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      StorageService().profileName.isEmpty ? 'Set your display name' : StorageService().profileName,
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white30),
            ],
          ),
        ),
        const SizedBox(height: 28),

        _sectionHeader('Experience Modes'),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final m in RottyAppMode.values) ...[
              Expanded(child: _modeCard(m, mode, palette.primary)),
              if (m != RottyAppMode.values.last) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 28),

        _sectionHeader('Sound Space'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: SoundSpace.values.map((s) {
            final sel = sound == s;
            return LiquidGlassButton(
              accentColor: palette.primary,
              isActive: sel,
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              onTap: () => ref.read(soundSpaceProvider.notifier).set(s),
              child: Text(s.label, style: GoogleFonts.inter(color: sel ? palette.primary : Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),

        _sectionHeader('Playback'),
        const SizedBox(height: 14),
        _settingToggle('Smart Queue Autoplay', 'Automatically refill queue with similar songs matching active taste & session vibe', Icons.auto_awesome_rounded, aiOn, palette.primary, (v) => ref.read(aiDjEnabledProvider.notifier).state = v),
        const SizedBox(height: 10),
        _settingToggle('Album Art Ripples', 'Hardware-accelerated fluid canvas waves', Icons.waves_rounded, ref.watch(albumArtRipplesProvider), palette.primary, (v) => ref.read(albumArtRipplesProvider.notifier).toggle(v)),
        const SizedBox(height: 28),

        _sectionHeader('About'),
        const SizedBox(height: 14),
        LiquidGlassCard(
          accentColor: palette.primary,
          padding: const EdgeInsets.all(16),
          onTap: () => context.push('/about'), // Open direct to About Rotty screen
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('About Rotty', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Our story, legal safe-harbor disclaimer & open licenses', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white30),
            ],
          ),
        ),
        const SizedBox(height: 28),

        _sectionHeader('System'),
        const SizedBox(height: 14),
        Text('Rotty Music Desktop v2.0', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
        const SizedBox(height: 4),
        Text('Built with 🔥 by Kartik', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.25), fontSize: 11)),
      ],
    );
  }

  Widget _sectionHeader(String title) => Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.5));

  Widget _modeCard(RottyAppMode m, RottyAppMode current, Color accent) {
    final sel = m == current;
    final icon = switch (m) {
      RottyAppMode.normal => Icons.music_note_rounded,
      RottyAppMode.drive => Icons.speed_rounded,
      RottyAppMode.focus => Icons.self_improvement_rounded,
      RottyAppMode.sleep => Icons.bedtime_rounded,
    };
    return LiquidGlassCard(
      accentColor: accent,
      onTap: () => ref.read(appModeProvider.notifier).set(m),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        children: [
          Icon(icon, color: sel ? accent : Colors.white.withValues(alpha: 0.4), size: 24),
          const SizedBox(height: 8),
          Text(m.name[0].toUpperCase() + m.name.substring(1), style: GoogleFonts.inter(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, color: sel ? accent : Colors.white.withValues(alpha: 0.5))),
          if (sel) ...[
            const SizedBox(height: 4),
            Container(width: 16, height: 3, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: accent)),
          ],
        ],
      ),
    );
  }

  Widget _settingToggle(String title, String sub, IconData icon, bool val, Color accent, ValueChanged<bool> onChanged) {
    return LiquidGlassCard(
      accentColor: accent,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: val ? accent : Colors.white.withValues(alpha: 0.4), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(sub, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
              ],
            ),
          ),
          Switch(value: val, onChanged: onChanged, activeColor: accent, activeTrackColor: accent.withValues(alpha: 0.3)),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final TextEditingController nameCtrl = TextEditingController(text: StorageService().profileName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Edit Profile Name',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aapka display name jo party sync aur profile badges me visible hoga.',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Display Name',
                hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              await StorageService().setProfileName(newName);
              try {
                if (FirebaseService.instance.isReady) {
                  await FirebaseService.instance.updateUserDisplayName(newName);
                }
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// ─── Library tile with hover ───
class _LibTile extends StatefulWidget {
  const _LibTile(this.icon, this.color, this.title, this.sub, this.onTap, {this.imageUrl});
  final IconData icon;
  final Color color;
  final String title, sub;
  final VoidCallback onTap;
  final String? imageUrl;
  @override
  State<_LibTile> createState() => _LibTileState();
}

class _LibTileState extends State<_LibTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _h ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: Row(
            children: [
              if (widget.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(widget.imageUrl!, width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 48, height: 48, decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)))),
                )
              else
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Icon(widget.icon, color: Colors.white.withValues(alpha: 0.7), size: 22),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(widget.sub, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (_h) Icon(Icons.play_circle_filled_rounded, color: widget.color, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
