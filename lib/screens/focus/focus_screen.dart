import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/haptics/music_haptics.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';

/// ===================================================================
/// FOCUS MODE — Monochrome Brutalist UI + Pomodoro Breathing Ring
/// ===================================================================
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with TickerProviderStateMixin {
  // Pomodoro timer
  late int _focusMinutes;
  int _secondsLeft = 0;
  bool _timerRunning = false;
  bool _onBreak = false;
  int _pomodoroCount = 0;
  Timer? _countdownTimer;

  // Breathing ring animation
  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;

  // Phase label
  String _phaseLabel = 'READY';

  @override
  void initState() {
    super.initState();
    _focusMinutes = ref.read(focusTimerMinutesProvider);
    _secondsLeft = _focusMinutes * 60;

    // Breathing animation: 4s in, 4s hold, 4s out cycle
    _breathCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _breathAnim = CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOutSine);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _breathCtrl.dispose();
    super.dispose();
  }

  void _startPause() {
    MusicHaptics.playPause();
    if (_timerRunning) {
      _countdownTimer?.cancel();
      setState(() { _timerRunning = false; _phaseLabel = 'PAUSED'; });
    } else {
      setState(() { _timerRunning = true; _phaseLabel = _onBreak ? 'BREAK' : 'FOCUS'; });
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_secondsLeft <= 0) {
          t.cancel();
          _onTimerEnd();
        } else {
          setState(() => _secondsLeft--);
        }
      });
    }
  }

  void _onTimerEnd() {
    HapticFeedback.heavyImpact();
    if (!_onBreak) {
      setState(() {
        _pomodoroCount++;
        _onBreak = true;
        _phaseLabel = 'BREAK';
        _secondsLeft = (_pomodoroCount % 4 == 0 ? 15 : 5) * 60;
        _timerRunning = false;
      });
    } else {
      setState(() {
        _onBreak = false;
        _phaseLabel = 'READY';
        _secondsLeft = _focusMinutes * 60;
        _timerRunning = false;
      });
    }
  }

  void _reset() {
    _countdownTimer?.cancel();
    setState(() {
      _timerRunning = false;
      _onBreak = false;
      _phaseLabel = 'READY';
      _secondsLeft = _focusMinutes * 60;
    });
  }

  String get _timeString {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _timerProgress {
    final total = (_onBreak ? ((_pomodoroCount % 4 == 0 ? 15 : 5)) : _focusMinutes) * 60;
    return total > 0 ? 1.0 - (_secondsLeft / total) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(nowPlayingProvider);
    final playing = ref.watch(isPlayingProvider);
    final handler = ref.read(audioHandlerProvider);
    final size = MediaQuery.of(context).size;

    // Monochrome color scheme
    const monoWhite = Color(0xFFE8E8E8);
    const monoGray = Color(0xFF888888);
    const monoDark = Color(0xFF111111);
    final accentColor = _onBreak ? const Color(0xFF4FC3F7) : const Color(0xFFE8E8E8);

    return Scaffold(
      backgroundColor: monoDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Subtle noise/grain background ──
          CustomPaint(
            painter: _MonoBgPainter(),
            size: Size.infinite,
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _MonoBtn(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => context.pop(),
                      ),
                      const Spacer(),
                      // Pomodoro count dots
                      Row(
                        children: List.generate(4, (i) => Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < (_pomodoroCount % 4)
                                ? monoWhite
                                : monoGray.withValues(alpha: 0.3),
                            border: Border.all(color: monoGray.withValues(alpha: 0.4)),
                          ),
                        )),
                      ),
                      const Spacer(),
                      _MonoBtn(
                        icon: Icons.refresh_rounded,
                        onTap: _reset,
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // ── Phase Label ──
                Text(
                  _phaseLabel,
                  style: GoogleFonts.inter(
                    color: monoGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 16),

                // ── BREATHING RING with TIMER in center ──
                SizedBox(
                  width: size.width * 0.75,
                  height: size.width * 0.75,
                  child: AnimatedBuilder(
                    animation: _breathAnim,
                    builder: (_, __) => CustomPaint(
                      painter: _BreathingRingPainter(
                        breathFactor: _timerRunning ? _breathAnim.value : 0.0,
                        timerProgress: _timerProgress,
                        onBreak: _onBreak,
                        running: _timerRunning,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // BREATHE instruction
                            if (_timerRunning)
                              Text(
                                _breathAnim.value < 0.5 ? 'BREATHE IN' : 'BREATHE OUT',
                                style: GoogleFonts.inter(
                                  color: monoGray.withValues(alpha: 0.5),
                                  fontSize: 9,
                                  letterSpacing: 2,
                                ),
                              ),
                            // Time
                            Text(
                              _timeString,
                              style: GoogleFonts.inter(
                                color: monoWhite,
                                fontSize: size.width * 0.14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2,
                              ),
                            ),
                            // Start/Pause button
                            GestureDetector(
                              onTap: _startPause,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _timerRunning ? 'PAUSE' : 'START',
                                  style: GoogleFonts.inter(
                                    color: accentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // ── Now Playing (stripped of color) ──
                if (song != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: monoGray.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(song.title,
                                  style: GoogleFonts.spaceMono(
                                      color: monoWhite,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(song.artist,
                                  style: GoogleFonts.spaceMono(
                                      color: monoGray, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        // Minimal controls
                        IconButton(
                          icon: Icon(Icons.skip_previous_rounded, color: monoGray, size: 20),
                          onPressed: () { MusicHaptics.skip(); handler.skipToPrevious(); },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        IconButton(
                          icon: Icon(
                            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: monoWhite,
                            size: 24,
                          ),
                          onPressed: () { MusicHaptics.playPause(); playing ? handler.pause() : handler.play(); },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_next_rounded, color: monoGray, size: 20),
                          onPressed: () { MusicHaptics.skip(); handler.skipToNext(); },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Breathing Ring Painter ────────────────────────────────────────
class _BreathingRingPainter extends CustomPainter {
  final double breathFactor;
  final double timerProgress;
  final bool onBreak;
  final bool running;

  _BreathingRingPainter({
    required this.breathFactor,
    required this.timerProgress,
    required this.onBreak,
    required this.running,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Breathing outer glow ring
    if (running) {
      final breathRadius = size.width * 0.38 + breathFactor * size.width * 0.05;
      final breathPaint = Paint()
        ..color = (onBreak ? const Color(0xFF4FC3F7) : Colors.white)
            .withValues(alpha: breathFactor * 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(center, breathRadius, breathPaint);
    }

    // Concentric rings (brutalist feel)
    for (var i = 3; i >= 1; i--) {
      final r = size.width * (0.25 + i * 0.06);
      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.03 + i * 0.01)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawCircle(center, r, ringPaint);
    }

    // Track ring
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, size.width * 0.44, trackPaint);

    // Progress arc
    if (timerProgress > 0) {
      final progressPaint = Paint()
        ..color = onBreak ? const Color(0xFF4FC3F7) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: size.width * 0.44),
        -math.pi / 2,
        math.pi * 2 * timerProgress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BreathingRingPainter old) =>
      old.breathFactor != breathFactor ||
      old.timerProgress != timerProgress ||
      old.running != running;
}

// ─── Mono Background ──────────────────────────────────────────────
class _MonoBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Very subtle scan lines for texture
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.012)
      ..strokeWidth = 0.5;
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Mono Button ──────────────────────────────────────────────────
class _MonoBtn extends StatelessWidget {
  const _MonoBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white54, size: 18),
      ),
    );
  }
}
