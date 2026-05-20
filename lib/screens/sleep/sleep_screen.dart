import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/haptics/music_haptics.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';

/// ===================================================================
/// SLEEP MODE — The Dreamscape
/// Pitch black. All UI removed. Only a slow nebula cloud pulses.
/// Smart fade: volume gradually drops over last 5 minutes.
/// ===================================================================
class SleepScreen extends ConsumerStatefulWidget {
  const SleepScreen({super.key});

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen>
    with TickerProviderStateMixin {
  // Sleep timer
  int _secondsLeft = 0;
  bool _timerRunning = false;
  Timer? _countdownTimer;

  // Nebula animation
  late AnimationController _nebulaCtrl;
  late AnimationController _rotCtrl;

  // Show UI briefly on tap
  bool _uiVisible = false;
  Timer? _uiHideTimer;

  @override
  void initState() {
    super.initState();
    final mins = ref.read(sleepFadeMinutesProvider);
    _secondsLeft = mins * 60;

    _nebulaCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _rotCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 40))
      ..repeat();

    // Auto dim screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _uiHideTimer?.cancel();
    _nebulaCtrl.dispose();
    _rotCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startTimer() {
    final mins = ref.read(sleepFadeMinutesProvider);
    _secondsLeft = mins * 60;
    _timerRunning = true;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        _onSleepEnd();
      } else {
        setState(() => _secondsLeft--);
        // Smart fade: lower volume in last 5 minutes
        if (_secondsLeft <= 300) {
          final fadeProgress = 1.0 - (_secondsLeft / 300);
          final vol = (1.0 - fadeProgress).clamp(0.0, 1.0);
          ref.read(audioHandlerProvider).player.setVolume(vol);
        }
      }
    });
    setState(() {});
  }

  void _onSleepEnd() {
    ref.read(audioHandlerProvider).pause();
    ref.read(audioHandlerProvider).player.setVolume(1.0);
    setState(() { _timerRunning = false; _secondsLeft = 0; });
  }

  void _onTap() {
    // Show controls briefly on tap
    setState(() => _uiVisible = true);
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _uiVisible = false);
    });
  }

  String get _timeString {
    if (_secondsLeft <= 0) return '💤';
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(nowPlayingProvider);
    final playing = ref.watch(isPlayingProvider);
    final handler = ref.read(audioHandlerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── DREAMSCAPE NEBULA ──
            AnimatedBuilder(
              animation: Listenable.merge([_nebulaCtrl, _rotCtrl]),
              builder: (_, __) => CustomPaint(
                painter: _NebulaPainter(
                  breathFactor: _nebulaCtrl.value,
                  rotFactor: _rotCtrl.value,
                  color: _timerRunning
                      ? const Color(0xFF5B4FA7) // purple during sleep
                      : const Color(0xFF1A3A5A), // blue when idle
                ),
                size: Size.infinite,
              ),
            ),

            // ── OVERLAY CONTROLS (appear on tap, auto-hide) ──
            AnimatedOpacity(
              opacity: _uiVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 22),
                            onPressed: () {
                              _countdownTimer?.cancel();
                              handler.player.setVolume(1.0);
                              context.pop();
                            },
                          ),
                          const Spacer(),
                          // Timer display
                          Text(
                            _timerRunning ? _timeString : 'SLEEP',
                            style: GoogleFonts.inter(
                              color: Colors.white24,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Song info (barely visible)
                    if (song != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          song.title,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.15),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Minimal controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SleepBtn(
                          icon: Icons.skip_previous_rounded,
                          onTap: () { MusicHaptics.skip(); handler.skipToPrevious(); },
                        ),
                        const SizedBox(width: 24),
                        _SleepBtn(
                          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          large: true,
                          onTap: () { MusicHaptics.playPause(); playing ? handler.pause() : handler.play(); },
                        ),
                        const SizedBox(width: 24),
                        _SleepBtn(
                          icon: Icons.skip_next_rounded,
                          onTap: () { MusicHaptics.skip(); handler.skipToNext(); },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Timer buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _timerPill('15 min', 15),
                        const SizedBox(width: 8),
                        _timerPill('30 min', 30),
                        const SizedBox(width: 8),
                        _timerPill('45 min', 45),
                        const SizedBox(width: 8),
                        _timerPill('60 min', 60),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Centered nebula "heartbeat" when UI is hidden
            if (!_uiVisible && _timerRunning)
              Center(
                child: AnimatedBuilder(
                  animation: _nebulaCtrl,
                  builder: (_, __) => Opacity(
                    opacity: 0.06 + _nebulaCtrl.value * 0.04,
                    child: Text(
                      _timeString,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _timerPill(String label, int mins) {
    final active = _timerRunning && (_secondsLeft / 60).round() <= mins;
    return GestureDetector(
      onTap: () {
        ref.read(sleepFadeMinutesProvider.notifier).state = mins;
        _startTimer();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: active ? 0.3 : 0.1),
          ),
          borderRadius: BorderRadius.circular(20),
          color: active ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: active ? 0.6 : 0.25),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Nebula Painter ───────────────────────────────────────────────
class _NebulaPainter extends CustomPainter {
  final double breathFactor;
  final double rotFactor;
  final Color color;

  _NebulaPainter({required this.breathFactor, required this.rotFactor, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rng = math.Random(42); // seeded so it's consistent

    // Main nebula blob — slow-moving, deeply blurred
    for (var i = 0; i < 6; i++) {
      final angle = rotFactor * math.pi * 2 + i * (math.pi * 2 / 6);
      final dist = size.width * (0.12 + rng.nextDouble() * 0.18);
      final blobCenter = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist * 0.6,
      );
      final blobRadius = size.width * (0.15 + breathFactor * 0.08 + rng.nextDouble() * 0.1);

      final blobPaint = Paint()
        ..color = color.withValues(alpha: 0.04 + breathFactor * 0.03)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blobRadius * 0.8);
      canvas.drawCircle(blobCenter, blobRadius, blobPaint);
    }

    // Core center glow
    final corePaint = Paint()
      ..color = color.withValues(alpha: 0.05 + breathFactor * 0.04)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.25);
    canvas.drawCircle(center, size.width * 0.3 + breathFactor * size.width * 0.06, corePaint);
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter old) =>
      old.breathFactor != breathFactor || old.rotFactor != rotFactor;
}

// ─── Sleep Button ─────────────────────────────────────────────────
class _SleepBtn extends StatelessWidget {
  const _SleepBtn({required this.icon, required this.onTap, this.large = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final sz = large ? 56.0 : 40.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: sz, height: sz,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: Icon(icon, color: Colors.white38, size: sz * 0.45),
      ),
    );
  }
}
