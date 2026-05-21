import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/haptics/music_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';

/// ===================================================================
/// DRIVE MODE — Full Landscape HUD with Gesture Pad
/// Left: massive speedometer progress ring + song info
/// Right: full-screen gesture pad (swipe=skip, tap=pause)
/// ===================================================================
class NightDriveScreen extends ConsumerStatefulWidget {
  const NightDriveScreen({super.key});

  @override
  ConsumerState<NightDriveScreen> createState() => _NightDriveScreenState();
}

class _NightDriveScreenState extends ConsumerState<NightDriveScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _scanLine;

  // Gesture pad state
  String _gestureHint = 'TAP TO PAUSE';
  bool _gestureActive = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _scanLine = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    // Force LANDSCAPE for true dashboard feel
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _scanLine.dispose();
    // Restore portrait on exit
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onGestureTap() {
    final handler = ref.read(audioHandlerProvider);
    final playing = ref.read(isPlayingProvider);
    MusicHaptics.playPause();
    playing ? handler.pause() : handler.play();
    setState(() => _gestureHint = playing ? 'PAUSED' : 'PLAYING');
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _gestureHint = 'TAP TO PAUSE');
    });
  }

  void _onSwipeLeft() {
    MusicHaptics.skip();
    ref.read(audioHandlerProvider).skipToNext();
    setState(() { _gestureHint = '⏭ NEXT'; _gestureActive = true; });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() { _gestureHint = 'TAP TO PAUSE'; _gestureActive = false; });
    });
  }

  void _onSwipeRight() {
    MusicHaptics.skip();
    ref.read(audioHandlerProvider).skipToPrevious();
    setState(() { _gestureHint = '⏮ PREV'; _gestureActive = true; });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() { _gestureHint = 'TAP TO PAUSE'; _gestureActive = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(nowPlayingProvider);
    final playing = ref.watch(isPlayingProvider);
    final handler = ref.read(audioHandlerProvider);
    final size = MediaQuery.of(context).size;
    // In landscape: width > height. Avoid exceeding safe width boundaries.
    final maxWidth = size.width * 0.52 - 32;
    final maxHeight = size.height * 0.55;
    final ringSize = math.min(maxWidth, maxHeight).clamp(100.0, 260.0);
    final hideDriveText = (size.width * 0.52) <= 200;

    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF030205)),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ─── Animated Dashboard Background ───
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => CustomPaint(
                painter: _DriveBackgroundPainter(phase: _pulse.value, playing: playing),
                size: Size.infinite,
              ),
            ),
            // ─── Scan Line ───
            AnimatedBuilder(
              animation: _scanLine,
              builder: (_, __) {
                if (!playing) return const SizedBox.shrink();
                return Positioned(
                  top: size.height * _scanLine.value,
                  left: 0, right: 0,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        const Color(0xFFFF6B4A).withValues(alpha: 0.4),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                );
              },
            ),

            // ─── SPLIT LAYOUT ───
            Row(
              children: [
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // LEFT SIDE: HUD — ring + song info + back button
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                SizedBox(
                  width: size.width * 0.52,
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Drive Mode badge + Back
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                      color: Color(0xFFFFAB91), size: 20),
                                  onPressed: () => context.pop(),
                                ),
                                const Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: hideDriveText ? 8 : 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B4A).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFFF6B4A).withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.speed_rounded, color: Color(0xFFFF6B4A), size: 14),
                                      if (!hideDriveText) ...[
                                        const SizedBox(width: 6),
                                        Text('DRIVE', style: GoogleFonts.inter(
                                            color: const Color(0xFFFFE0D6),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            letterSpacing: 2)),
                                      ],
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Progress %
                                StreamBuilder<Duration>(
                                  stream: handler.player.positionStream,
                                  builder: (_, snap) {
                                    final pos = snap.data ?? Duration.zero;
                                    final dur = handler.player.duration ?? song?.duration ?? const Duration(minutes: 3);
                                    final pct = dur.inMilliseconds > 0
                                        ? (pos.inMilliseconds / dur.inMilliseconds * 100).round()
                                        : 0;
                                    return Text('$pct%', style: GoogleFonts.inter(
                                        color: const Color(0xFFFF8A65),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14));
                                  },
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // ── Speedometer Ring ──
                            StreamBuilder<Duration>(
                              stream: handler.player.positionStream,
                              builder: (_, snap) {
                                final pos = snap.data ?? Duration.zero;
                                final dur = handler.player.duration ?? song?.duration ?? const Duration(minutes: 3);
                                final progress = dur.inMilliseconds > 0
                                    ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                                    : 0.0;
                                return _SpeedometerRing(
                                  progress: progress,
                                  playing: playing,
                                  size: ringSize,
                                  pulseFactor: _pulse.value,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // Song title
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                song?.title ?? 'Nothing Playing',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    color: const Color(0xFFFFE0D6),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song?.artist ?? '',
                              style: GoogleFonts.inter(
                                  color: const Color(0xFFFF8A65), fontSize: 13, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // RIGHT SIDE: Full-screen GESTURE PAD
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                Expanded(
                  child: GestureDetector(
                    onTap: _onGestureTap,
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v.abs() < 200) return;
                      if (v < 0) _onSwipeLeft(); else _onSwipeRight();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: const Color(0xFFFF6B4A).withValues(alpha: _gestureActive ? 0.5 : 0.1),
                            width: 1,
                          ),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xFFFF6B4A).withValues(alpha: _gestureActive ? 0.08 : 0.02),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Center gesture hint text
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  _gestureHint,
                                  key: ValueKey(_gestureHint),
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '← SWIPE →',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  fontSize: 10,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                          // Play/Pause state indicator (large fading icon)
                          if (playing)
                            AnimatedBuilder(
                              animation: _pulse,
                              builder: (_, __) => Icon(
                                Icons.pause_rounded,
                                size: 100,
                                color: const Color(0xFFFF6B4A).withValues(alpha: 0.04 + _pulse.value * 0.02),
                              ),
                            )
                          else
                            const Icon(Icons.play_arrow_rounded, size: 100,
                                color: Color(0x06FF6B4A)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Speedometer Ring Widget ───────────────────────────────────────
class _SpeedometerRing extends StatelessWidget {
  const _SpeedometerRing({
    required this.progress,
    required this.playing,
    required this.size,
    required this.pulseFactor,
  });
  final double progress;
  final bool playing;
  final double size;
  final double pulseFactor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SpeedometerPainter(
            progress: progress, playing: playing, pulseFactor: pulseFactor),
        size: Size(size, size),
      ),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double progress;
  final bool playing;
  final double pulseFactor;

  _SpeedometerPainter({required this.progress, required this.playing, required this.pulseFactor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Outer glow ring
    final glowPaint = Paint()
      ..color = const Color(0xFFFF6B4A).withValues(alpha: playing ? 0.08 + pulseFactor * 0.06 : 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi * 0.8, math.pi * 1.6, false, glowPaint);

    // Track
    final trackPaint = Paint()
      ..color = const Color(0xFF2D1515)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi * 0.8, math.pi * 1.6, false, trackPaint);

    // Tick marks
    final tickPaint = Paint()
      ..color = const Color(0xFFFF6B4A).withValues(alpha: 0.2)
      ..strokeWidth = 1;
    for (var i = 0; i <= 24; i++) {
      final angle = -math.pi * 0.8 + (math.pi * 1.6 * i / 24);
      final isMajor = i % 6 == 0;
      final inner = radius - (isMajor ? 14 : 8);
      final outer = radius + 4;
      tickPaint.color = const Color(0xFFFF6B4A).withValues(alpha: isMajor ? 0.35 : 0.15);
      tickPaint.strokeWidth = isMajor ? 2 : 0.8;
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(angle), center.dy + inner * math.sin(angle)),
        Offset(center.dx + outer * math.cos(angle), center.dy + outer * math.sin(angle)),
        tickPaint,
      );
    }

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          colors: const [Color(0xFFFF3D1E), Color(0xFFFF6B4A), Color(0xFFFFAB91)],
          stops: const [0.0, 0.6, 1.0],
          startAngle: -math.pi * 0.8,
          endAngle: math.pi * 0.8,
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          -math.pi * 0.8, math.pi * 1.6 * progress, false, progressPaint);

      // Glowing tip
      final tipAngle = -math.pi * 0.8 + math.pi * 1.6 * progress;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      final tipPaint = Paint()
        ..color = const Color(0xFFFFAB91)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(tipX, tipY), 5, tipPaint);
      canvas.drawCircle(Offset(tipX, tipY), 3, Paint()..color = Colors.white);
    }

    // Center text — show progress %
    final pct = (progress * 100).round();
    final textStyle = GoogleFonts.inter(
      color: const Color(0xFFFFE0D6),
      fontSize: size.width * 0.16,
      fontWeight: FontWeight.w900,
    ).getParagraphStyle();
    final tp = TextPainter(
      text: TextSpan(text: '$pct', style: TextStyle(
        color: const Color(0xFFFFE0D6),
        fontSize: size.width * 0.16,
        fontWeight: FontWeight.w900,
        fontFamily: 'Inter',
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2 + size.width * 0.04));

    final unitPainter = TextPainter(
      text: TextSpan(text: '%', style: TextStyle(
        color: const Color(0xFFFF8A65),
        fontSize: size.width * 0.07,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    unitPainter.paint(canvas,
        Offset(center.dx - unitPainter.width / 2, center.dy + size.width * 0.06));
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter old) =>
      old.progress != progress || old.playing != playing || old.pulseFactor != pulseFactor;
}

// ─── Dashboard Background Painter ─────────────────────────────────
class _DriveBackgroundPainter extends CustomPainter {
  final double phase;
  final bool playing;

  _DriveBackgroundPainter({required this.phase, required this.playing});

  @override
  void paint(Canvas canvas, Size size) {
    // Base ambient glow (left side, red-orange)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, 0),
        colors: [
          Color.fromRGBO(255, 107, 74, playing ? 0.12 + phase * 0.06 : 0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFFF6B4A).withValues(alpha: 0.02)
      ..strokeWidth = 0.5;
    for (var y = 0.0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var x = 0.0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Vertical separator line between left HUD and gesture pad
    if (playing) {
      final sepPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFFFF6B4A).withValues(alpha: 0.1 + phase * 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(size.width * 0.52, 0, 1, size.height))
        ..strokeWidth = 1;
      canvas.drawLine(
          Offset(size.width * 0.52, 0), Offset(size.width * 0.52, size.height), sepPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DriveBackgroundPainter old) =>
      old.phase != phase || old.playing != playing;
}
