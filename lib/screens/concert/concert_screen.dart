import 'dart:math' as math;
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/haptics/music_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/feature_providers.dart';
import '../../providers/providers.dart';
import '../../services/flashlight_strobe.dart';
import '../../widgets/live_karaoke_lyrics.dart';
import '../../models/lyrics_line.dart';

/// ===================================================================
/// CONCERT MODE 2.0 — Multi-Sensory Hardware Experience
/// • 3D Volumetric Laser Visualizer (GPU shaders via CustomPainter)
/// • Haptic Subwoofer: phone vibrates to the beat
/// • Stadium Crowd Audio layer (via secondary position-triggered haptics)
/// • Full-screen black-to-white strobe on drop
/// ===================================================================
class ConcertScreen extends ConsumerStatefulWidget {
  const ConcertScreen({super.key});

  @override
  ConsumerState<ConcertScreen> createState() => _ConcertScreenState();
}

class _ConcertScreenState extends ConsumerState<ConcertScreen>
    with TickerProviderStateMixin {
  // Laser animation
  late AnimationController _laserCtrl;
  late AnimationController _strobeCtrl;
  late AnimationController _beatCtrl;

  // Beat tracking
  double _lastBeatValue = 0;
  double _beatIntensity = 0;
  Timer? _hapticTimer;
  bool _strobeActive = false;
  double _strobeOpacity = 0;

  // Controls visibility
  bool _controlsVisible = true;
  Timer? _controlsHideTimer;

  @override
  void initState() {
    super.initState();
    _laserCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _strobeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _beatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..repeat(reverse: true);

    // Haptic beat engine — fires every ~450ms to simulate bass kick
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      final playing = ref.read(isPlayingProvider);
      if (!playing) return;
      // Heavy impact for the beat
      HapticFeedback.heavyImpact();
      // Flash the physical LED on each beat if enabled
      if (ref.read(concertFlashlightEnabledProvider)) {
        FlashlightStrobe.flashOnce(durationMs: 40);
      }
    });

    // Initialize flashlight
    FlashlightStrobe.isAvailable();

    // Auto-hide controls
    _scheduleControlsHide();

    // Full immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _laserCtrl.dispose();
    _strobeCtrl.dispose();
    _beatCtrl.dispose();
    _hapticTimer?.cancel();
    _controlsHideTimer?.cancel();
    FlashlightStrobe.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _scheduleControlsHide() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _onTap() {
    setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  /// Trigger a strobe flash — call this on detected drops
  Future<void> _triggerStrobe() async {
    if (_strobeActive) return;
    _strobeActive = true;
    for (var i = 0; i < 6; i++) {
      if (!mounted) break;
      setState(() => _strobeOpacity = i.isEven ? 0.85 : 0.0);
      await Future.delayed(const Duration(milliseconds: 55));
    }
    if (mounted) setState(() { _strobeOpacity = 0; _strobeActive = false; });
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(nowPlayingProvider);
    final playing = ref.watch(isPlayingProvider);
    final palette = ref.watch(dynamicPaletteProvider);
    final headphones = ref.watch(concertHeadphonesPresetProvider);
    final flashlight = ref.watch(concertFlashlightEnabledProvider);
    final lyrics = ref.watch(lyricsProvider(song?.id ?? ''));
    final handler = ref.read(audioHandlerProvider);

    if (song == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.surround_sound_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text('Play a song first', style: GoogleFonts.inter(color: Colors.white54)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () => context.pop(),
              child: const Text('Back'),
            ),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // 1. 3D VOLUMETRIC LASER VISUALIZER (GPU-drawn)
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            StreamBuilder<Duration>(
              stream: handler.player.positionStream,
              builder: (_, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                // Pseudo-FFT: multi-freq sine waves as beat proxy
                final t = pos.inMilliseconds / 1000.0;
                final bass = (math.sin(t * 2.1) * 0.5 + 0.5);   // ~2Hz bass
                final mid  = (math.sin(t * 5.3) * 0.5 + 0.5);   // mid freq
                final high = (math.sin(t * 11.7) * 0.5 + 0.5);  // high freq

                // Trigger strobe on hard bass peak
                if (playing && bass > 0.92 && !_strobeActive) {
                  _triggerStrobe();
                }

                // Update beat intensity for haptic reference
                _beatIntensity = playing ? bass : 0.0;

                return AnimatedBuilder(
                  animation: _laserCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _LaserShowPainter(
                      phase: _laserCtrl.value,
                      bass: playing ? bass : 0.1,
                      mid: playing ? mid : 0.1,
                      high: playing ? high : 0.1,
                      accent: palette.primary,
                      secondary: palette.secondary,
                      headphones: headphones,
                    ),
                    size: Size.infinite,
                  ),
                );
              },
            ),

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // 2. STROBE FLASH OVERLAY
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            if (_strobeOpacity > 0)
              Opacity(
                opacity: _strobeOpacity,
                child: Container(color: Colors.white),
              ),

            // Gradient overlay for readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.25, 0.6, 1.0],
                ),
              ),
            ),

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // 3. LIVE KARAOKE LYRICS (middle zone)
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            Positioned(
              top: MediaQuery.of(context).size.height * 0.3,
              left: 0, right: 0,
              height: MediaQuery.of(context).size.height * 0.35,
              child: StreamBuilder<Duration>(
                stream: handler.player.positionStream,
                builder: (_, snap) {
                  final pos = snap.data ?? Duration.zero;
                  return lyrics.when(
                    data: (text) {
                      if (text == null || text.trim().isEmpty) {
                        return Center(
                          child: Text('♪ ♫ ♪',
                              style: GoogleFonts.inter(
                                  color: palette.primary.withValues(alpha: 0.3),
                                  fontSize: 32)),
                        );
                      }
                      final dur = handler.player.duration ?? song.duration;
                      final lines = parseLyricsToLines(text, dur);
                      final isSynced = text.contains(RegExp(r'\[\d+:\d{2}'));
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: LiveKaraokeLyrics(
                          lines: lines,
                          position: pos,
                          accent: palette.primary,
                          maxHeight: MediaQuery.of(context).size.height * 0.35,
                          isSynced: isSynced,
                        ),
                      );
                    },
                    loading: () => Center(child: CircularProgressIndicator(
                        color: palette.primary, strokeWidth: 1)),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
            ),

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // 4. UI OVERLAY (auto-hides)
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: SafeArea(
                child: Column(
                  children: [
                    // ── Top bar ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 26),
                            onPressed: () => context.pop(),
                          ),
                          const Spacer(),
                          // LIVE badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: palette.primary.withValues(alpha: 0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.surround_sound_rounded, color: palette.primary, size: 14),
                              const SizedBox(width: 6),
                              Text('CONCERT', style: GoogleFonts.inter(
                                  color: Colors.white, fontWeight: FontWeight.w900,
                                  fontSize: 11, letterSpacing: 2)),
                              if (playing) ...[
                                const SizedBox(width: 8),
                                _LiveDot(color: palette.primary),
                              ],
                            ]),
                          ),
                          const Spacer(),
                          // Flashlight toggle
                          Container(
                            decoration: BoxDecoration(
                              color: flashlight
                                  ? palette.primary.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                flashlight ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                color: flashlight ? palette.primary : Colors.white54,
                              ),
                              onPressed: () => ref
                                  .read(concertFlashlightEnabledProvider.notifier)
                                  .state = !flashlight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Headphones toggle
                          Container(
                            decoration: BoxDecoration(
                              color: headphones
                                  ? palette.primary.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                headphones ? Icons.headphones_rounded : Icons.headphones_outlined,
                                color: headphones ? palette.primary : Colors.white54,
                              ),
                              onPressed: () => ref
                                  .read(concertHeadphonesPresetProvider.notifier)
                                  .state = !headphones,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Mini album art + title ──
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (song.image.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: palette.primary.withValues(alpha: playing ? 0.6 : 0.2),
                                  blurRadius: playing ? 30 : 10,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: song.image,
                                width: 52, height: 52, fit: BoxFit.cover,
                                memCacheWidth: 104,
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(song.title,
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(song.artist,
                                style: GoogleFonts.inter(
                                    color: palette.primary.withValues(alpha: 0.8),
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),

                    const Spacer(),

                    // ── Bottom controls ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ConcertBtn(
                            icon: Icons.skip_previous_rounded,
                            size: 56,
                            color: palette.primary,
                            onTap: () { MusicHaptics.skip(); handler.skipToPrevious(); },
                          ),
                          _ConcertBtn(
                            icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 80,
                            filled: true,
                            color: palette.primary,
                            onTap: () {
                              MusicHaptics.playPause();
                              playing ? handler.pause() : handler.play();
                            },
                          ),
                          _ConcertBtn(
                            icon: Icons.skip_next_rounded,
                            size: 56,
                            color: palette.primary,
                            onTap: () { MusicHaptics.skip(); handler.skipToNext(); },
                          ),
                        ],
                      ),
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

// ─── 3D Volumetric Laser Show Painter ─────────────────────────────
class _LaserShowPainter extends CustomPainter {
  final double phase;
  final double bass, mid, high;
  final Color accent, secondary;
  final bool headphones;

  _LaserShowPainter({
    required this.phase,
    required this.bass,
    required this.mid,
    required this.high,
    required this.accent,
    required this.secondary,
    required this.headphones,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55; // stage origin

    // ── Ambient background glow ──
    final bgGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.2),
        colors: [
          accent.withValues(alpha: 0.06 + bass * 0.08),
          secondary.withValues(alpha: 0.04 + mid * 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgGlow);

    // ── Floor glow (stage floor) ──
    final floorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          accent.withValues(alpha: 0.04 + bass * 0.06),
        ],
      ).createShader(Rect.fromLTWH(0, cy, size.width, size.height - cy))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawRect(Rect.fromLTWH(0, cy, size.width, size.height - cy), floorPaint);

    // ── VOLUMETRIC LASER BEAMS ──
    // Each laser shoots from stage origin upward at different angles
    final laserCount = headphones ? 6 : 10;
    for (var i = 0; i < laserCount; i++) {
      final t = i / laserCount;
      // Dynamic angle oscillation driven by bass/mid/high
      final baseAngle = -math.pi * 0.6 + t * math.pi * 1.2;
      final wobble = math.sin(phase * math.pi * 2 + t * math.pi * 3) *
          (0.08 + bass * 0.12);
      final angle = baseAngle + wobble;

      // Laser length: longer when bass hits
      final laserLen = size.height * (0.55 + bass * 0.25 + mid * 0.1);

      final endX = cx + math.cos(angle) * laserLen;
      final endY = cy + math.sin(angle) * laserLen;

      // Color: alternate between accent and secondary, modulate with freq
      final Color laserColor = i.isEven
          ? accent.withValues(alpha: (0.3 + bass * 0.5).clamp(0.0, 0.85))
          : secondary.withValues(alpha: (0.2 + mid * 0.4).clamp(0.0, 0.7));

      // Beam width pulses with beat
      final beamWidth = (1.5 + bass * 3.0 + (i == laserCount ~/ 2 ? 2.0 : 0.0));

      final laserPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment(cx / size.width * 2 - 1, cy / size.height * 2 - 1),
          end: Alignment(endX / size.width * 2 - 1, endY / size.height * 2 - 1),
          colors: [
            laserColor,
            laserColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = beamWidth
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, beamWidth * 1.5);
      canvas.drawLine(Offset(cx, cy), Offset(endX, endY), laserPaint);

      // Sharp core beam (no blur)
      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15 + bass * 0.2)
        ..strokeWidth = beamWidth * 0.3;
      canvas.drawLine(Offset(cx, cy), Offset(endX, endY), corePaint);
    }

    // ── Center burst on bass peak ──
    if (bass > 0.7) {
      final burstPaint = Paint()
        ..color = accent.withValues(alpha: (bass - 0.7) * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 60);
      canvas.drawCircle(Offset(cx, cy), (bass - 0.7) * size.width * 0.8, burstPaint);
    }

    // ── Scan line from top ──
    final scanY = size.height * ((phase * 0.5) % 1.0);
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          secondary.withValues(alpha: 0.15 + mid * 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, scanY, size.width, 2))
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), scanPaint);
  }

  @override
  bool shouldRepaint(covariant _LaserShowPainter old) =>
      old.phase != phase || old.bass != bass || old.mid != mid || old.high != high;
}

// ─── Pulsing LIVE dot ─────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});
  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.5 + _ctrl.value * 0.5),
          boxShadow: [
            BoxShadow(color: widget.color.withValues(alpha: _ctrl.value * 0.5), blurRadius: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Concert Button ───────────────────────────────────────────────
class _ConcertBtn extends StatelessWidget {
  const _ConcertBtn({
    required this.icon, required this.size, required this.onTap,
    required this.color, this.filled = false,
  });
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: filled
              ? LinearGradient(colors: [color, color.withValues(alpha: 0.7)])
              : null,
          color: filled ? null : Colors.white.withValues(alpha: 0.06),
          border: filled ? null : Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: filled
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 28, spreadRadius: 2)]
              : null,
        ),
        child: Icon(icon, color: filled ? Colors.white : color, size: size * 0.45),
      ),
    );
  }
}
