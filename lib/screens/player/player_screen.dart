import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/haptics/music_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/time_theme.dart';
import '../../models/song_model.dart';
import '../../providers/providers.dart';
import '../../providers/premium_providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/player_story_sheet.dart';
import '../../widgets/song_options_sheet.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/fluid_bleed_background.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  double _speed = 1.0;

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(nowPlayingProvider);
    if (song == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('Nothing playing', style: TextStyle(color: Colors.white54))),
      );
    }

    final playing = ref.watch(isPlayingProvider);
    final handler = ref.read(audioHandlerProvider);
    final insight = ref.watch(aiInsightProvider);

    final timeTheme = ref.watch(timeThemeProvider);

    final palette = ref.watch(dynamicPaletteProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: FluidBleedBackground(
        colors: [palette.primary, palette.secondary, palette.tertiary],
        bassIntensity: playing ? 0.5 : 0.0,
        child: RottyAuroraBackground(
          intensity: 0.5,
          child: SafeArea(
          child: GestureDetector(
            // Swipe down to dismiss player
            onVerticalDragEnd: (d) {
              if (d.primaryVelocity != null && d.primaryVelocity! > 400) {
                context.pop();
              }
            },
            // Horizontal swipe for skip
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 400) return;
              MusicHaptics.skip();
              if (v > 0) {
                handler.skipToPrevious();
              } else {
                handler.skipToNext();
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final artSide = (constraints.maxWidth - 64).clamp(180.0, 300.0);
                return Column(
                  children: [
                    _topBar(context, song),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            GestureDetector(
                              onVerticalDragEnd: (d) {
                                if (d.primaryVelocity != null && d.primaryVelocity! < -200) {
                                  showPlayerStorySheet(context, ref, song);
                                }
                              },
                              onTap: () => showPlayerStorySheet(context, ref, song),
                              child: _AlbumArt(song: song, maxSide: artSide),
                            ),
                            const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(song.title, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(song.artist, style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    ref.read(favoritesProvider.notifier).isFavorite(song.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: AppColors.accent,
                                  ),
                                  onPressed: () {
                                    MusicHaptics.like();
                                    ref.read(favoritesProvider.notifier).toggle(song);
                                  },
                                ),
                                // Song options (queue management)
                                IconButton(
                                  icon: const Icon(Icons.more_horiz_rounded, color: Colors.white60),
                                  onPressed: () => showSongOptionsSheet(context, ref, song),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              insight.message,
                              style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ProgressSection(handler: handler, song: song),
                          const SizedBox(height: 8),
                          _Controls(playing: playing, handler: handler),
                          const SizedBox(height: 8),
                            _Actions(context, song: song, insight: insight),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        ),  // RottyAuroraBackground
      ),    // FluidBleedBackground
    );
  }

  Widget _topBar(BuildContext context, SongModel song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32), onPressed: () => context.pop()),
          Expanded(child: Text('NOW PLAYING', style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 10, letterSpacing: 1), textAlign: TextAlign.center)),
          IconButton(icon: const Icon(Icons.queue_music_rounded, color: Colors.white70), onPressed: () => context.push('/queue')),
        ],
      ),
    );
  }

  Widget _Actions(BuildContext context, {required SongModel song, required dynamic insight}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _chip('Lyrics', Icons.lyrics_outlined, () => context.push('/lyrics/${song.id}')),
        _chip('Concert', Icons.surround_sound_rounded, () => context.push('/concert')),
        _chip('Focus', Icons.self_improvement_rounded, () => context.push('/focus')),
        _chip('Drive', Icons.directions_car_rounded, () => context.push('/drive')),
        _chip('Sleep', Icons.bedtime_rounded, () => context.push('/sleep')),
      ],
    );
  }

  Widget _chip(String label, IconData icon, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white60, size: 20),
      label: Text(label, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
    );
  }
}

class _AlbumArt extends ConsumerWidget {
  const _AlbumArt({required this.song, required this.maxSide});
  final SongModel song;
  final double maxSide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = maxSide;
    final accent = ref.watch(dynamicPaletteProvider).primary;
    return RepaintBoundary(
      child: Hero(
        tag: 'album_art_${song.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 32, spreadRadius: -4),
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: song.image,
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: 600,
              fadeInDuration: Duration.zero,
              errorWidget: (_, __, ___) => Container(
                width: size,
                height: size,
                color: AppColors.bgCard,
                child: const Icon(Icons.music_note, size: 64, color: Colors.white24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressSection extends StatefulWidget {
  const _ProgressSection({required this.handler, required this.song});
  final dynamic handler;
  final SongModel song;

  @override
  State<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<_ProgressSection> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.handler.player.positionStream,
      builder: (context, snap) {
        final position = snap.data ?? Duration.zero;
        final duration = widget.handler.player.duration ?? widget.song.duration;
        final total = duration.inSeconds > 0 ? duration : const Duration(minutes: 3);
        final progress = total.inMilliseconds > 0
            ? position.inMilliseconds / total.inMilliseconds
            : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // ── Glowing Tactile Progress Bar ──
              GestureDetector(
                onHorizontalDragStart: (_) {
                  setState(() => _dragging = true);
                  HapticFeedback.selectionClick();
                },
                onHorizontalDragEnd: (_) {
                  setState(() => _dragging = false);
                },
                onHorizontalDragUpdate: (d) {
                  HapticFeedback.selectionClick();
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final localX = (d.localPosition.dx).clamp(0.0, box.size.width);
                  final ratio = localX / box.size.width;
                  final seekTo = Duration(
                      milliseconds: (ratio * total.inMilliseconds).round());
                  MusicHaptics.seek();
                  widget.handler.seek(seekTo);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: _dragging ? 8 : 4,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
                  child: Stack(
                    children: [
                      // Track
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Progress fill
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.accentGradient,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.6),
                                blurRadius: _dragging ? 12 : 6,
                                spreadRadius: _dragging ? 2 : 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Time labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmtDur(position),
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Text(
                    _fmtDur(total),
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.playing, required this.handler});
  final bool playing;
  final dynamic handler;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(Icons.shuffle_rounded, color: handler.player.shuffleModeEnabled ? AppColors.accent : Colors.white54),
          onPressed: () => handler.setShuffleMode(handler.player.shuffleModeEnabled ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all),
        ),
        _SpringBtn(
          child: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
          onTap: () {
            MusicHaptics.skip();
            handler.skipToPrevious();
          },
        ),
        _SpringBtn(
          onTap: () {
            MusicHaptics.playPause();
            playing ? handler.pause() : handler.play();
          },
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.accentGradient,
              boxShadow: [
                BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: -2),
              ],
            ),
            child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 38),
          ),
        ),
        _SpringBtn(
          child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
          onTap: () {
            MusicHaptics.skip();
            handler.skipToNext();
          },
        ),
        IconButton(
          icon: Icon(
            handler.player.loopMode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
            color: handler.player.loopMode != LoopMode.off ? AppColors.accent : Colors.white54,
          ),
          onPressed: () async {
            final m = handler.player.loopMode;
            await handler.setRepeatMode(m == LoopMode.off ? AudioServiceRepeatMode.all : (m == LoopMode.all ? AudioServiceRepeatMode.one : AudioServiceRepeatMode.none));
          },
        ),
      ],
    );
  }
}

/// Spring Physics Button — squishes on tap, bounces back like rubber
class _SpringBtn extends StatefulWidget {
  const _SpringBtn({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_SpringBtn> createState() => _SpringBtnState();
}

class _SpringBtnState extends State<_SpringBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic, reverseCurve: Curves.elasticOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();
  void _onTapUp(TapUpDetails _) {
    _ctrl.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
