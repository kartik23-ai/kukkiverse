import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/live_karaoke_lyrics.dart';
import '../../models/lyrics_line.dart';

/// ═══════════════════════════════════════════════════════════════
/// Desktop Full Screen Canvas — Immersive player mode
/// Big album art, live lyrics, visualizer, floating controls
/// Controls auto-hide when mouse idle
/// ═══════════════════════════════════════════════════════════════
class DesktopFullScreen extends ConsumerStatefulWidget {
  const DesktopFullScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  ConsumerState<DesktopFullScreen> createState() => _DesktopFullScreenState();
}

class _DesktopFullScreenState extends ConsumerState<DesktopFullScreen>
    with TickerProviderStateMixin {
  bool _showControls = true;
  Timer? _hideTimer;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onMouseMove() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(nowPlayingProvider);
    final playing = ref.watch(isPlayingProvider);
    final handler = ref.read(audioHandlerProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    if (song == null) {
      widget.onClose();
      return const SizedBox.shrink();
    }

    return MouseRegion(
      onHover: (_) => _onMouseMove(),
      cursor: _showControls ? SystemMouseCursors.basic : SystemMouseCursors.none,
      child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onClose();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ─── Background: Aurora + huge blurred art ───
            Container(color: const Color(0xFF020204)),
            RottyAuroraBackground(
              intensity: 0.8,
              paletteOverride: [palette.primary, palette.secondary, palette.tertiary],
              child: const SizedBox.expand(),
            ),

            // Blurred album art overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: CachedNetworkImage(
                  imageUrl: song.image,
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: 0.5),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ),

            // ─── Center: Album art + lyrics ───
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Big album art with glow
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, child) {
                      final glow = 0.3 + 0.15 * sin(_pulseCtrl.value * 2 * pi);
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: palette.primary.withValues(alpha: glow), blurRadius: 60, spreadRadius: 10),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: song.image,
                            width: 340, height: 340,
                            fit: BoxFit.cover,
                            memCacheWidth: 680,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 60),

                  // Lyrics panel
                  SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Song info
                        Text(
                          song.title,
                          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          song.artist,
                          style: GoogleFonts.inter(fontSize: 16, color: palette.primary.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                        ),
                        if (song.album.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(song.album, style: GoogleFonts.inter(fontSize: 13, color: Colors.white24)),
                        ],
                        const SizedBox(height: 28),

                        // Live lyrics
                        SizedBox(
                          height: 300,
                          child: Consumer(
                            builder: (context, ref, _) {
                              final lyrics = ref.watch(lyricsProvider(song.id));
                              return lyrics.when(
                                data: (text) {
                                  if (text == null || text.trim().isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.lyrics_rounded, size: 48, color: Colors.white.withValues(alpha: 0.08)),
                                          const SizedBox(height: 12),
                                          Text('No lyrics available', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.15), fontSize: 14)),
                                        ],
                                      ),
                                    );
                                  }
                                  final lines = parseLyricsToLines(text, song.duration);
                                  final isSynced = text.contains(RegExp(r'\[\d+:\d{2}'));
                                  return StreamBuilder<Duration>(
                                    stream: handler.player.positionStream,
                                    builder: (context, snap) {
                                      return LiveKaraokeLyrics(
                                        lines: lines,
                                        position: snap.data ?? Duration.zero,
                                        accent: palette.primary,
                                        maxHeight: 300,
                                        isSynced: isSynced,
                                      );
                                    },
                                  );
                                },
                                loading: () => Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary.withValues(alpha: 0.3)),
                                ),
                                error: (_, __) => const SizedBox.shrink(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Floating controls (auto-hide) ───
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              bottom: _showControls ? 0 : -120,
              left: 0, right: 0,
              child: _FloatingControls(
                song: song, playing: playing, handler: handler, palette: palette,
                onClose: widget.onClose,
              ),
            ),

            // ─── Top bar: Close button ───
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              top: _showControls ? 0 : -60,
              left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    _TopBarButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      tooltip: 'Exit Full Screen (Esc)',
                      onTap: widget.onClose,
                    ),
                    const Spacer(),
                    Text('ROTTY CANVAS', style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white24, letterSpacing: 3,
                    )),
                    const Spacer(),
                    _TopBarButton(
                      icon: Icons.more_horiz_rounded,
                      tooltip: 'More',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Floating bottom controls ───
class _FloatingControls extends StatelessWidget {
  const _FloatingControls({required this.song, required this.playing, required this.handler, required this.palette, required this.onClose});
  final dynamic song, handler, palette;
  final bool playing;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(80, 0, 80, 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress
          StreamBuilder<Duration>(
            stream: handler.player.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final dur = handler.player.duration ?? song.duration;
              final progress = dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
              return Column(
                children: [
                  // Seek
                  GestureDetector(
                    onTapDown: (d) {
                      final w = MediaQuery.of(context).size.width - 208;
                      final ratio = (d.localPosition.dx / w).clamp(0.0, 1.0);
                      handler.player.seek(Duration(milliseconds: (dur.inMilliseconds * ratio).round()));
                    },
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Time labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(pos), style: GoogleFonts.inter(fontSize: 10, color: Colors.white30)),
                      Text(_fmt(dur), style: GoogleFonts.inter(fontSize: 10, color: Colors.white30)),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CtrlBtn(Icons.shuffle_rounded, Colors.white30, () {}),
              const SizedBox(width: 24),
              _CtrlBtn(Icons.skip_previous_rounded, Colors.white70, () => handler.skipToPrevious(), size: 28),
              const SizedBox(width: 16),
              // Play
              GestureDetector(
                onTap: () => playing ? handler.pause() : handler.play(),
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                    boxShadow: [BoxShadow(color: (palette.primary as Color).withValues(alpha: 0.4), blurRadius: 20)],
                  ),
                  child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              _CtrlBtn(Icons.skip_next_rounded, Colors.white70, () => handler.skipToNext(), size: 28),
              const SizedBox(width: 24),
              _CtrlBtn(Icons.repeat_rounded, Colors.white30, () {}),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _CtrlBtn extends StatefulWidget {
  const _CtrlBtn(this.icon, this.color, this.onTap, {this.size = 22});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  State<_CtrlBtn> createState() => _CtrlBtnState();
}

class _CtrlBtnState extends State<_CtrlBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Icon(widget.icon, size: widget.size, color: _h ? Colors.white : widget.color),
      ),
    );
  }
}

class _TopBarButton extends StatefulWidget {
  const _TopBarButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_TopBarButton> createState() => _TopBarButtonState();
}

class _TopBarButtonState extends State<_TopBarButton> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _h ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06),
            ),
            child: Icon(widget.icon, color: Colors.white70, size: 22),
          ),
        ),
      ),
    );
  }
}
