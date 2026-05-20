import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/song_model.dart';
import '../providers/providers.dart';
import '../providers/premium_providers.dart';
import '../providers/feature_providers.dart';
import '../core/theme/app_colors.dart';
import '../core/haptics/music_haptics.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(nowPlayingProvider);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: song == null
          ? const SizedBox.shrink()
          : _MiniBar(key: ValueKey(song.id), song: song),
    );
  }
}

class _MiniBar extends ConsumerStatefulWidget {
  const _MiniBar({super.key, required this.song});
  final SongModel song;

  @override
  ConsumerState<_MiniBar> createState() => _MiniBarState();
}

class _MiniBarState extends ConsumerState<_MiniBar> with SingleTickerProviderStateMixin {
  double _dragX = 0;
  double _dragY = 0;  // Vertical drag for liquid morph
  bool _swiped = false;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onSwipe(DragEndDetails details) {
    if (_swiped) return;
    final handler = ref.read(audioHandlerProvider);
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 300) {
      setState(() => _dragX = 0);
      return;
    }
    _swiped = true;
    MusicHaptics.skip();
    if (velocity > 0) {
      // Swipe right → Next song
      handler.skipToNext();
    } else {
      // Swipe left → Previous song
      handler.skipToPrevious();
    }
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() { _dragX = 0; _swiped = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final playing = ref.watch(isPlayingProvider);
    final handler = ref.read(audioHandlerProvider);
    final accent = AppColors.accent;
    final screenWidth = MediaQuery.of(context).size.width;

    return RepaintBoundary(
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => setState(() => _dragX += d.delta.dx),
        onHorizontalDragEnd: _onSwipe,
        onHorizontalDragCancel: () => setState(() => _dragX = 0),
        // Liquid morph: drag up to expand
        onVerticalDragUpdate: (d) {
          final dy = d.delta.dy;
          if (dy < 0) { // Dragging up
            setState(() => _dragY = (_dragY - dy).clamp(0, 200));
          } else {
            setState(() => _dragY = (_dragY - dy).clamp(0, 200));
          }
        },
        onVerticalDragEnd: (d) {
          final screenH = MediaQuery.of(context).size.height;
          // Snap threshold: 40% of screen
          if (_dragY > screenH * 0.15) {
            // Navigate to player with spring
            MusicHaptics.playPause();
            context.push('/player');
          }
          setState(() => _dragY = 0);
        },
        onVerticalDragCancel: () => setState(() => _dragY = 0),
        child: AnimatedContainer(
          duration: _dragY > 0 ? Duration.zero : const Duration(milliseconds: 350),
          curve: Curves.elasticOut,
          transform: Matrix4.identity()
            ..translate(
              _dragX.clamp(-60, 60),
              -_dragY * 0.5, // Float upward
            )
            ..scale(1.0 + _dragY * 0.001), // Slight scale-up on drag
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E),
                      accent.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    // ✨ 1px inner glass edge-light
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    // Colored glow shadow from accent
                    BoxShadow(
                      color: accent.withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => context.push('/player'),
                  child: SizedBox(
                    height: 64,
                    width: screenWidth - 20, // Explicit width prevents overflow
                    child: Row(
                      children: [
                        Hero(
                          tag: 'album_art_${widget.song.id}',
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: widget.song.image,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              memCacheWidth: 128,
                              fadeInDuration: Duration.zero,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.song.title,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.song.artist,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Skip previous (small)
                        SizedBox(
                          width: 32,
                          child: IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70, size: 22),
                            onPressed: () {
                              MusicHaptics.skip();
                              handler.skipToPrevious();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ),
                        // Play/Pause
                        Container(
                          width: 38,
                          height: 38,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.accentGradient,
                            boxShadow: [
                              BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 8),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: () {
                              MusicHaptics.playPause();
                              playing ? handler.pause() : handler.play();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          ),
                        ),
                        // Skip next (small)
                        SizedBox(
                          width: 36,
                          child: IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 22),
                            onPressed: () {
                              MusicHaptics.skip();
                              handler.skipToNext();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
