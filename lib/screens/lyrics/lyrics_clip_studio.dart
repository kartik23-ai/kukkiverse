import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../models/lyrics_line.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';

/// ═══════════════════════════════════════════════════════════════
/// INTERACTIVE CLIP STUDIO — Story Mode
/// • Drag to select 15-sec lyric snippet
/// • Morphs into Instagram-story canvas
/// • Live audio visualizer background
/// • Lyrics stamped as sticker overlay
/// ═══════════════════════════════════════════════════════════════
class LyricsClipStudio extends ConsumerStatefulWidget {
  const LyricsClipStudio({super.key, required this.songId});
  final String songId;

  @override
  ConsumerState<LyricsClipStudio> createState() => _LyricsClipStudioState();
}

class _LyricsClipStudioState extends ConsumerState<LyricsClipStudio>
    with TickerProviderStateMixin {
  int _selectStart = 0;
  int _selectEnd = 3;
  bool _storyMode = false;
  late AnimationController _vizCtrl;
  late AnimationController _morphCtrl;

  @override
  void initState() {
    super.initState();
    _vizCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _morphCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _vizCtrl.dispose();
    _morphCtrl.dispose();
    super.dispose();
  }

  void _enterStoryMode() {
    setState(() => _storyMode = true);
    _morphCtrl.forward();
  }

  void _exitStoryMode() {
    _morphCtrl.reverse().then((_) {
      if (mounted) setState(() => _storyMode = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(nowPlayingProvider);
    final lyrics = ref.watch(lyricsProvider(widget.songId));
    final palette = ref.watch(dynamicPaletteProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _storyMode
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              title: Text('Lyrics Clip Studio',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  onPressed: () =>
                      Share.share('${song?.title ?? "Track"} — made on ROTTY MUSIC'),
                ),
              ],
            ),
      body: lyrics.when(
        data: (text) {
          if (text == null || text.trim().isEmpty) {
            return Center(
              child: Text('No lyrics available',
                  style: GoogleFonts.inter(color: AppColors.textTertiary)),
            );
          }
          final lines = parseLyricsToLines(
              text, song?.duration ?? const Duration(seconds: 180));
          if (lines.isEmpty) {
            return Center(
              child: Text('No synced lyrics found',
                  style: GoogleFonts.inter(color: AppColors.textTertiary)),
            );
          }
          // Clamp selection
          _selectEnd = _selectEnd.clamp(0, lines.length - 1);
          _selectStart = _selectStart.clamp(0, _selectEnd);

          if (_storyMode) {
            return _StoryCanvas(
              lines: lines.sublist(_selectStart, _selectEnd + 1),
              accent: palette.primary,
              vizCtrl: _vizCtrl,
              morphCtrl: _morphCtrl,
              songTitle: song?.title ?? '',
              onBack: _exitStoryMode,
            );
          }

          return _SelectionMode(
            lines: lines,
            selectStart: _selectStart,
            selectEnd: _selectEnd,
            accent: palette.primary,
            onRangeChanged: (start, end) {
              setState(() {
                _selectStart = start;
                _selectEnd = end.clamp(start, lines.length - 1);
              });
            },
            onCreateClip: _enterStoryMode,
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (_, __) =>
            Center(child: Text('Error loading lyrics', style: GoogleFonts.inter(color: Colors.white38))),
      ),
    );
  }
}

/// ─── Selection Mode: Drag to pick lyrics ───
class _SelectionMode extends StatelessWidget {
  const _SelectionMode({
    required this.lines,
    required this.selectStart,
    required this.selectEnd,
    required this.accent,
    required this.onRangeChanged,
    required this.onCreateClip,
  });

  final List<LyricsLine> lines;
  final int selectStart;
  final int selectEnd;
  final Color accent;
  final void Function(int start, int end) onRangeChanged;
  final VoidCallback onCreateClip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.swipe_vertical_rounded, color: accent, size: 18),
              const SizedBox(width: 8),
              Text('Tap lines to select a clip',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
              const Spacer(),
              Text('${selectEnd - selectStart + 1} lines',
                  style: GoogleFonts.inter(
                      color: accent, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: lines.length,
            itemBuilder: (context, i) {
              final selected = i >= selectStart && i <= selectEnd;
              return GestureDetector(
                onTap: () {
                  // Tap to set start, then tap another to set end
                  if (i <= selectStart) {
                    onRangeChanged(i, (i + 3).clamp(i, lines.length - 1));
                  } else {
                    onRangeChanged(selectStart, i);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selected
                        ? accent.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.03),
                    border: Border.all(
                      color: selected
                          ? accent.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Text(
                    lines[i].text,
                    style: GoogleFonts.inter(
                      color: selected ? Colors.white : Colors.white38,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Create clip button
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onCreateClip,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text('Create Story Clip',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ─── Story Canvas: Instagram-style with visualizer ───
class _StoryCanvas extends StatelessWidget {
  const _StoryCanvas({
    required this.lines,
    required this.accent,
    required this.vizCtrl,
    required this.morphCtrl,
    required this.songTitle,
    required this.onBack,
  });

  final List<LyricsLine> lines;
  final Color accent;
  final AnimationController vizCtrl;
  final AnimationController morphCtrl;
  final String songTitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AnimatedBuilder(
      animation: Listenable.merge([vizCtrl, morphCtrl]),
      builder: (context, _) {
        final morph = Curves.easeOutBack.transform(morphCtrl.value);

        return Stack(
          children: [
            // Audio visualizer background
            Positioned.fill(
              child: CustomPaint(
                painter: _VisualizerPainter(
                  time: vizCtrl.value,
                  accent: accent,
                ),
              ),
            ),
            // Dark overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ),
            // Story frame (9:16 aspect)
            Center(
              child: Transform.scale(
                scale: morph,
                child: Container(
                  width: size.width * 0.85,
                  height: size.width * 0.85 * (16 / 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accent.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.7),
                        accent.withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Visualizer inside frame
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _VisualizerPainter(
                              time: vizCtrl.value,
                              accent: accent,
                              compact: true,
                            ),
                          ),
                        ),
                        // Lyrics sticker
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final line in lines)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Text(
                                      line.text,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.playfairDisplay(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        height: 1.4,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // ROTTY watermark
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Text(
                            'ROTTY',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        // Song title
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: Text(
                            songTitle,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Back button
            Positioned(
              top: 50,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: onBack,
              ),
            ),
            // Share button
            Positioned(
              top: 50,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () =>
                    Share.share('$songTitle — made on ROTTY MUSIC'),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// GPU Audio Visualizer background
class _VisualizerPainter extends CustomPainter {
  final double time;
  final Color accent;
  final bool compact;

  _VisualizerPainter({
    required this.time,
    required this.accent,
    this.compact = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = time * math.pi * 2;
    final bars = compact ? 24 : 32;
    final barWidth = size.width / bars;

    for (var i = 0; i < bars; i++) {
      final normalX = i / bars;
      // Multi-wave function for organic look
      final wave1 = math.sin(t * 2 + normalX * 8) * 0.3;
      final wave2 = math.sin(t * 3.5 + normalX * 12) * 0.2;
      final wave3 = math.cos(t * 1.5 + normalX * 5) * 0.15;
      final height = (0.3 + wave1 + wave2 + wave3).clamp(0.05, 0.85) * size.height;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            accent.withValues(alpha: 0.5),
            accent.withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromLTWH(i * barWidth, size.height - height, barWidth - 1, height),
        );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * barWidth, size.height - height, barWidth - 2, height),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter old) => true;
}
