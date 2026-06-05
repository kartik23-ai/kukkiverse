import 'dart:ui';
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
          : _MiniBar(key: const ValueKey('minibar'), song: song),
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

  @override
  void didUpdateWidget(covariant _MiniBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      setState(() {
        _dragX = 0;
        _dragY = 0;
        _swiped = false;
      });
    }
  }

  void _onSwipe(DragEndDetails details) {
    if (_swiped) return;
    final party = ref.read(partyRoomProvider);
    if (party.code != null && !party.isHost) {
      // Guests cannot swipe-skip
      setState(() => _dragX = 0);
      return;
    }

    final handler = ref.read(audioHandlerProvider);
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 300) {
      setState(() => _dragX = 0);
      return;
    }
    _swiped = true;
    MusicHaptics.skip();
    try {
      if (velocity > 0) {
        // Swipe right → Next song
        handler.skipToNext();
      } else {
        // Swipe left → Previous song
        handler.skipToPrevious();
      }
    } catch (e) {
      debugPrint('Mini Player swipe gesture error: $e');
    }
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() { _dragX = 0; _swiped = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final playing = ref.watch(isPlayingProvider);
    final handler = ref.read(audioHandlerProvider);
    final palette = ref.watch(dynamicPaletteProvider);
    final party = ref.watch(partyRoomProvider);
    final accent = palette.primary;
    final screenWidth = MediaQuery.of(context).size.width;

    return RepaintBoundary(
      child: GestureDetector(
        onHorizontalDragUpdate: (d) {
          if (_dragY > 5) return;
          setState(() => _dragX += d.delta.dx);
        },
        onHorizontalDragEnd: _onSwipe,
        onHorizontalDragCancel: () => setState(() => _dragX = 0),
        // Liquid morph: drag up to expand
        onVerticalDragUpdate: (d) {
          if (_dragX.abs() > 5) return;
          final dy = d.delta.dy;
          setState(() => _dragY = (_dragY - dy).clamp(0, 200));
        },
        onVerticalDragEnd: (d) {
          final screenH = MediaQuery.of(context).size.height;
          // Snap threshold: 15% of screen
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
              0.0,
            )
            ..scale(1.0 + _dragY * 0.001), // Slight scale-up on drag
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF161522).withValues(alpha: 0.85),
                      accent.withValues(alpha: 0.25),
                      const Color(0xFF0D0C14).withValues(alpha: 0.90),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Builder(
                    builder: (context) {
                      final useBlur = ref.watch(albumArtRipplesProvider);
                      final content = InkWell(
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
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (party.code != null && !party.isHost)
                                Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.greenAccent.withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.wifi_tethering_rounded, color: Colors.greenAccent, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          'SYNCED',
                                          style: GoogleFonts.inter(
                                            color: Colors.greenAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else ...[
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
                                    gradient: LinearGradient(
                                      colors: [palette.primary, palette.secondary],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 10),
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
                            ],
                          ),
                        ),
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
            ),
          ),
        ),
      ),
    );
  }
}
