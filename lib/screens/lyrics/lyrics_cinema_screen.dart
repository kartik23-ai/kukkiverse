import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/lyrics_line.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';

/// ═══════════════════════════════════════════════════════════════
/// 3D SPATIAL LYRICS — Cinematic Mode
/// Lines fly in from deep background (Z-axis), stop at camera,
/// then fly past overhead. Star Wars intro meets hologram.
/// ═══════════════════════════════════════════════════════════════
class LyricsCinemaScreen extends ConsumerStatefulWidget {
  const LyricsCinemaScreen({super.key, required this.songId});
  final String songId;

  @override
  ConsumerState<LyricsCinemaScreen> createState() => _LyricsCinemaScreenState();
}

class _LyricsCinemaScreenState extends ConsumerState<LyricsCinemaScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _tickCtrl;
  Duration _smoothPos = Duration.zero;
  Duration _targetPos = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tickCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _tickCtrl.addListener(_interpolatePosition);
    Future.microtask(() => ref.invalidate(lyricsProvider(widget.songId)));
  }

  void _interpolatePosition() {
    final tMs = _targetPos.inMilliseconds;
    final cMs = _smoothPos.inMilliseconds;
    final newMs = cMs + ((tMs - cMs) * 0.12).round();
    setState(() => _smoothPos = Duration(milliseconds: newMs));
  }

  @override
  void dispose() {
    _tickCtrl.removeListener(_interpolatePosition);
    _tickCtrl.dispose();
    super.dispose();
  }

  int _activeIndex(List<LyricsLine> lines) {
    if (lines.isEmpty) return 0;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (_smoothPos >= lines[i].start) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(lyricsProvider(widget.songId));
    final song = ref.watch(nowPlayingProvider);
    final palette = ref.watch(dynamicPaletteProvider);
    final handler = ref.read(audioHandlerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Deep space gradient background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  colors: [
                    palette.primary.withValues(alpha: 0.2),
                    const Color(0xFF050508),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  radius: 1.5,
                ),
              ),
            ),
          ),
          // Subtle star particles
          Positioned.fill(child: _StarField()),
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'CINEMA MODE',
                              style: GoogleFonts.inter(
                                color: palette.primary.withValues(alpha: 0.6),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                              ),
                            ),
                            Text(
                              song?.title ?? '',
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48), // Balance
                    ],
                  ),
                ),
                // Lyrics body
                Expanded(
                  child: lyrics.when(
                    data: (text) {
                      if (text == null || text.trim().isEmpty) {
                        return Center(
                          child: Text('No lyrics available',
                              style: GoogleFonts.inter(color: Colors.white38)),
                        );
                      }
                      return StreamBuilder<Duration>(
                        stream: handler.player.positionStream,
                        builder: (context, snap) {
                          _targetPos = snap.data ?? Duration.zero;
                          final dur = handler.player.duration ??
                              song?.duration ??
                              const Duration(minutes: 3, seconds: 30);
                          final lines = parseLyricsToLines(text, dur);
                          final active = _activeIndex(lines);

                          return _Spatial3DLyrics(
                            lines: lines,
                            activeIndex: active,
                            position: _smoothPos,
                            accent: palette.primary,
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                    error: (_, __) => Center(
                      child: Text('Could not load lyrics',
                          style: GoogleFonts.inter(color: Colors.white38)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════
/// 3D Spatial Line Renderer
/// Each line exists in a 3D z-space relative to active
/// ═══════════════════════════════════════════════════
class _Spatial3DLyrics extends StatelessWidget {
  const _Spatial3DLyrics({
    required this.lines,
    required this.activeIndex,
    required this.position,
    required this.accent,
  });

  final List<LyricsLine> lines;
  final int activeIndex;
  final Duration position;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Show 7 lines around the active: 3 upcoming (behind), active, 3 past (flew by)
    const visible = 7;
    final start = (activeIndex - 3).clamp(0, lines.length);
    final end = (activeIndex + 4).clamp(0, lines.length);

    return SizedBox(
      width: size.width,
      height: size.height * 0.72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = start; i < end; i++)
            _build3DLine(i, size),
        ],
      ),
    );
  }

  Widget _build3DLine(int i, Size size) {
    final offset = i - activeIndex; // -3..+3, 0=active
    final isNonLatin = lines[i].text.runes.any((c) =>
        (c >= 0x0900 && c <= 0x0D7F) || (c >= 0x0600 && c <= 0x06FF));

    // Z-depth: upcoming lines are far away, past lines flew over
    // offset < 0 = upcoming (far, small, blurred)
    // offset == 0 = active (flat, full size, sharp)
    // offset > 0 = past (flew overhead, fading)

    double zScale; // 0.3 (far) → 1.0 (active) → 0.8 (past)
    double yOffset; // vertical position
    double opacity;
    double blurSigma;

    if (offset < 0) {
      // Upcoming: flying in from deep background
      final t = offset.abs() / 4.0; // 0..1
      zScale = 1.0 - t * 0.5; // 0.5 → 1.0
      yOffset = 100 + offset * 55; // Below center
      opacity = (1.0 - t * 0.6).clamp(0.2, 1.0);
      blurSigma = t * 4;
    } else if (offset == 0) {
      // Active: perfect center, full clarity
      zScale = 1.0;
      yOffset = 0;
      opacity = 1.0;
      blurSigma = 0;
    } else {
      // Past: flew over camera
      final t = offset / 4.0;
      zScale = 1.0 - t * 0.3; // Shrink slightly
      yOffset = -80 - offset * 50; // Above center
      opacity = (1.0 - t * 0.7).clamp(0.0, 0.6);
      blurSigma = t * 3;
    }

    final fontSize = offset == 0 ? 24.0 : 17.0;
    final adjustedFontSize = isNonLatin ? fontSize * 1.05 : fontSize;

    // 3D perspective transform
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.002) // Perspective
      ..translate(0.0, yOffset, 0.0)
      ..scale(zScale);

    // Calculate line progress for active line karaoke sweep
    double sweepProgress = 0;
    if (offset == 0) {
      final nextStart = i + 1 < lines.length
          ? lines[i + 1].start
          : position + const Duration(seconds: 4);
      final durMs = (nextStart - lines[i].start).inMilliseconds;
      if (durMs > 0) {
        sweepProgress = ((position - lines[i].start).inMilliseconds / durMs).clamp(0.0, 1.0);
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuart,
      transform: matrix,
      transformAlignment: Alignment.center,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 300),
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
            tileMode: TileMode.decal,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: offset == 0
                ? _CinemaSweepText(
                    text: lines[i].text,
                    progress: sweepProgress,
                    accent: accent,
                    fontSize: adjustedFontSize,
                    isNonLatin: isNonLatin,
                  )
                : Text(
                    lines[i].text,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: adjustedFontSize,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: opacity),
                      height: isNonLatin ? 1.6 : 1.4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Cinema sweep text with gradient fill
class _CinemaSweepText extends StatelessWidget {
  const _CinemaSweepText({
    required this.text,
    required this.progress,
    required this.accent,
    required this.fontSize,
    required this.isNonLatin,
  });

  final String text;
  final double progress;
  final Color accent;
  final double fontSize;
  final bool isNonLatin;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        final sweepPos = progress * bounds.width;
        return LinearGradient(
          colors: [
            Colors.white,
            Colors.white,
            accent,
            Colors.white30,
          ],
          stops: [
            0.0,
            (sweepPos / bounds.width).clamp(0.0, 0.97),
            ((sweepPos + 20) / bounds.width).clamp(0.02, 1.0),
            1.0,
          ],
        ).createShader(bounds);
      },
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.playfairDisplay(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: isNonLatin ? 1.6 : 1.3,
          letterSpacing: 0.5,
          shadows: [
            Shadow(color: accent.withValues(alpha: 0.5), blurRadius: 24),
            Shadow(color: accent.withValues(alpha: 0.2), blurRadius: 48),
          ],
        ),
      ),
    );
  }
}

/// Background star field for cinematic atmosphere
class _StarField extends StatefulWidget {
  @override
  State<_StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<_StarField>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _stars = List.generate(40, (_) => _Star.random(rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _StarPainter(stars: _stars, time: _ctrl.value),
        ),
      ),
    );
  }
}

class _Star {
  final double x, y, size, speed, phase;
  const _Star(this.x, this.y, this.size, this.speed, this.phase);
  factory _Star.random(math.Random r) => _Star(
        r.nextDouble(),
        r.nextDouble(),
        0.5 + r.nextDouble() * 1.5,
        0.2 + r.nextDouble() * 0.8,
        r.nextDouble() * math.pi * 2,
      );
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double time;
  _StarPainter({required this.stars, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final t = (time * s.speed + s.phase) % 1.0;
      final twinkle = (math.sin(t * math.pi * 2) * 0.5 + 0.5);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15 + twinkle * 0.25);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => true;
}
