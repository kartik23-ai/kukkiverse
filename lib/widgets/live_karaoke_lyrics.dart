import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/premium_providers.dart';
import '../core/theme/app_colors.dart';
import '../models/lyrics_line.dart';
import 'rotty_glass.dart';

/// ═══════════════════════════════════════════════════════════════
/// ELITE Karaoke Lyrics v2.0
/// • Ticker-based 120fps sync (no StreamBuilder jank)
/// • Fluid blur on inactive lines (Apple Music style)
/// • Word-by-word gradient karaoke sweep
/// • Dead-center locked active line (never scrolls off-screen)
/// • Native language support (Devanagari, Gurmukhi, etc.)
/// ═══════════════════════════════════════════════════════════════
class LiveKaraokeLyrics extends ConsumerStatefulWidget {
  const LiveKaraokeLyrics({
    super.key,
    required this.lines,
    required this.position,
    required this.accent,
    this.dualLanguage = false,
    this.maxHeight = 220,
  });

  final List<LyricsLine> lines;
  final Duration position;
  final Color accent;
  final bool dualLanguage;
  final double maxHeight;

  @override
  ConsumerState<LiveKaraokeLyrics> createState() => _LiveKaraokeLyricsState();
}

class _LiveKaraokeLyricsState extends ConsumerState<LiveKaraokeLyrics>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  int _active = 0;
  late AnimationController _tickCtrl;

  // Smooth interpolated position
  Duration _smoothPos = Duration.zero;
  Duration _lastTargetPos = Duration.zero;

  @override
  void initState() {
    super.initState();
    _active = _indexForPosition(widget.position);
    _smoothPos = widget.position;
    _lastTargetPos = widget.position;

    // 120fps ticker for butter-smooth interpolation
    _tickCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _tickCtrl.addListener(_onTick);
  }

  void _onTick() {
    // Interpolate smoothly toward the target position
    final targetMs = _lastTargetPos.inMilliseconds;
    final currentMs = _smoothPos.inMilliseconds;
    // Lerp at ~85% speed for ultra-smooth motion
    final newMs = currentMs + ((targetMs - currentMs) * 0.15).round();
    _smoothPos = Duration(milliseconds: newMs);

    // Check if active line changed
    final newActive = _indexForPosition(_smoothPos);
    if (newActive != _active) {
      if (ref.read(hapticLyricsProvider)) {
        HapticFeedback.selectionClick();
      }
      setState(() => _active = newActive);
      _scrollToCenter(newActive);
    }
  }

  @override
  void didUpdateWidget(covariant LiveKaraokeLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      _lastTargetPos = widget.position;
    }
  }

  int _indexForPosition(Duration pos) {
    if (widget.lines.isEmpty) return 0;
    var idx = 0;
    for (var i = widget.lines.length - 1; i >= 0; i--) {
      if (pos >= widget.lines[i].start) {
        idx = i;
        break;
      }
    }
    return idx;
  }

  void _scrollToCenter(int idx) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      // Each item ~80px. Lock active line to center of viewport.
      final viewportHeight = _scroll.position.viewportDimension;
      final targetOffset = (idx * 80.0) - (viewportHeight / 2) + 40;
      final clamped = targetOffset.clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(
        clamped,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutQuart,
      );
    });
  }

  @override
  void dispose() {
    _tickCtrl.removeListener(_onTick);
    _tickCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Calculate line progress (0.0 to 1.0) for karaoke sweep
  double _lineProgress(int index) {
    if (index != _active) return index < _active ? 1.0 : 0.0;
    final line = widget.lines[index];
    final nextStart = index + 1 < widget.lines.length
        ? widget.lines[index + 1].start
        : _smoothPos + const Duration(seconds: 4);
    final lineDurMs = (nextStart - line.start).inMilliseconds;
    if (lineDurMs <= 0) return 1.0;
    return ((_smoothPos - line.start).inMilliseconds / lineDurMs).clamp(0.0, 1.0);
  }

  /// Distance from active line (for blur calculation)
  double _distanceFromActive(int index) {
    return (index - _active).abs().toDouble();
  }

  /// Detect non-latin script for font adjustments
  bool _isNonLatin(String text) {
    // Check for Devanagari, Gurmukhi, Bengali, Tamil, Telugu, etc.
    return text.runes.any((c) =>
        (c >= 0x0900 && c <= 0x097F) || // Devanagari
        (c >= 0x0A00 && c <= 0x0A7F) || // Gurmukhi
        (c >= 0x0980 && c <= 0x09FF) || // Bengali
        (c >= 0x0B80 && c <= 0x0BFF) || // Tamil
        (c >= 0x0C00 && c <= 0x0C7F) || // Telugu
        (c >= 0x0600 && c <= 0x06FF) || // Arabic/Urdu
        (c >= 0x0D00 && c <= 0x0D7F)    // Malayalam
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      return RottyGlass(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No synced lines to show.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textTertiary),
          ),
        ),
      );
    }

    return RottyGlass(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      tint: widget.accent,
      child: SizedBox(
        height: widget.maxHeight,
        child: ListView.builder(
          controller: _scroll,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(vertical: widget.maxHeight * 0.35),
          itemCount: widget.lines.length,
          itemBuilder: (context, i) => _buildLine(i),
        ),
      ),
    );
  }

  Widget _buildLine(int i) {
    final line = widget.lines[i];
    final active = i == _active;
    final dist = _distanceFromActive(i);
    final progress = _lineProgress(i);
    final isNonLatin = _isNonLatin(line.text);

    // Blur: active=0, adjacent=1.5, far=4+
    final blurSigma = active ? 0.0 : (dist * 1.8).clamp(0.0, 5.0);
    // Opacity: active=1.0, fade with distance
    final opacity = active ? 1.0 : (1.0 - dist * 0.18).clamp(0.25, 0.7);
    // Scale: active=1.0, shrink slightly with distance
    final scale = active ? 1.0 : (1.0 - dist * 0.04).clamp(0.82, 0.95);

    // Font size — larger for active, adjusted for non-latin
    final baseFontSize = active ? 22.0 : 16.0;
    final fontSize = isNonLatin ? baseFontSize * 1.05 : baseFontSize;
    final lineHeight = isNonLatin ? 1.6 : 1.4;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutQuart,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 300),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
              tileMode: TileMode.decal,
            ),
            child: Column(
              children: [
                // ─── Karaoke Sweep Text ───
                active
                    ? _KaraokeSweepText(
                        text: line.text,
                        progress: progress,
                        accent: widget.accent,
                        fontSize: fontSize,
                        lineHeight: lineHeight,
                        isNonLatin: isNonLatin,
                      )
                    : Text(
                        line.text,
                        textAlign: TextAlign.center,
                        style: _textStyle(
                          active: false,
                          fontSize: fontSize,
                          lineHeight: lineHeight,
                        ),
                      ),
                // ─── Translation ───
                if (widget.dualLanguage && line.translation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      line.translation!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: active ? 14 : 12,
                        color: active
                            ? widget.accent.withValues(alpha: 0.9)
                            : AppColors.textTertiary.withValues(alpha: 0.4),
                        height: isNonLatin ? 1.5 : 1.3,
                      ),
                    ),
                  ),
                // ─── Progress bar ───
                if (active) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.5,
                      backgroundColor: Colors.white10,
                      color: widget.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _textStyle({
    required bool active,
    required double fontSize,
    required double lineHeight,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: active ? FontWeight.w800 : FontWeight.w400,
      color: active ? Colors.white : Colors.white38,
      height: lineHeight,
      letterSpacing: active ? 0.3 : 0.0,
    );
  }
}

/// ═══════════════════════════════════════════════════
/// Karaoke Sweep — Gradient fill left-to-right
/// ═══════════════════════════════════════════════════
class _KaraokeSweepText extends StatelessWidget {
  const _KaraokeSweepText({
    required this.text,
    required this.progress,
    required this.accent,
    required this.fontSize,
    required this.lineHeight,
    required this.isNonLatin,
  });

  final String text;
  final double progress;
  final Color accent;
  final double fontSize;
  final double lineHeight;
  final bool isNonLatin;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        final sweepPos = progress * bounds.width;
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white,
            Colors.white,
            accent,
            Colors.white38,
          ],
          stops: [
            0.0,
            (sweepPos / bounds.width).clamp(0.0, 0.98),
            ((sweepPos + 15) / bounds.width).clamp(0.01, 1.0),
            1.0,
          ],
        ).createShader(bounds);
      },
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white, // Will be masked by ShaderMask
          height: lineHeight,
          letterSpacing: 0.3,
          shadows: [
            Shadow(color: accent.withValues(alpha: 0.4), blurRadius: 16),
          ],
        ),
      ),
    );
  }
}
