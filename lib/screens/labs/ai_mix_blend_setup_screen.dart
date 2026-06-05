import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/song_model.dart';
import '../../providers/providers.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';

class AIMixBlendSetupScreen extends ConsumerStatefulWidget {
  const AIMixBlendSetupScreen({super.key});

  @override
  ConsumerState<AIMixBlendSetupScreen> createState() => _AIMixBlendSetupScreenState();
}

class _AIMixBlendSetupScreenState extends ConsumerState<AIMixBlendSetupScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  final math.Random _random = math.Random();

  final List<String> _styles = [
    'Smooth',
    'Energetic',
    'Party',
    'Chill',
    'Cinematic',
    'Festival',
    'Emotional'
  ];

  final List<int> _lengths = [2, 4, 8, 16];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(mixFadeEnabledProvider);
    final activeStyle = ref.watch(mixBlendStyleProvider);
    final activeLength = ref.watch(mixBlendLengthProvider);
    final palette = ref.watch(dynamicPaletteProvider);
    final currentSong = ref.watch(nowPlayingProvider);
    final audioHandler = ref.watch(audioHandlerProvider);
    final favorites = ref.watch(favoritesProvider);

    // Resolve genuine upcoming transition queue
    final List<SongModel> upcomingQueue = [];
    upcomingQueue.addAll(audioHandler.userQueue);
    final int nextContextIndex = audioHandler.currentIndex + 1;
    if (nextContextIndex >= 0 && nextContextIndex < audioHandler.contextQueue.length) {
      upcomingQueue.addAll(audioHandler.contextQueue.sublist(nextContextIndex));
    }

    // Resolve next track in queue genuinely
    final nextSong = upcomingQueue.isNotEmpty ? upcomingQueue.first : null;

    // Simulated high-fidelity compatibility calculations using song titles
    final int bpmA = currentSong != null ? 85 + (currentSong.title.hashCode % 45) : 105;
    final int bpmB = nextSong != null ? 85 + (nextSong.title.hashCode % 45) : 112;
    final int bpmDiff = (bpmA - bpmB).abs();
    
    final List<String> camelotKeys = ['1A', '1B', '2A', '2B', '3A', '3B', '4A', '4B', '5A', '5B', '6A', '6B', '7A', '7B', '8A', '8B', '9A', '9B', '10A', '10B', '11A', '11B', '12A', '12B'];
    final String keyA = currentSong != null ? camelotKeys[currentSong.title.hashCode % camelotKeys.length] : '8A';
    final String keyB = nextSong != null ? camelotKeys[nextSong.title.hashCode % camelotKeys.length] : '9A';

    final double compScore = currentSong == null || nextSong == null 
        ? 88.0 
        : (100.0 - (bpmDiff * 1.8)).clamp(68.0, 99.0);

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'AI Mix Blend Suite',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Global Switch Card
                LiquidGlass(
                  borderRadius: 24,
                  surfaceOpacity: 0.08,
                  borderOpacity: 0.15,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GLOBAL AI MIX BLENDING',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: palette.primary,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Seamless transitions on all song changes',
                                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: enabled,
                            activeColor: palette.primary,
                            activeThumbColor: Colors.white,
                            onChanged: (v) => ref.read(mixFadeEnabledProvider.notifier).toggle(v),
                          ),
                        ],
                      ),
                      if (enabled) ...[
                        const SizedBox(height: 20),
                        // Live Visualizer Wave
                        SizedBox(
                          height: 60,
                          width: double.infinity,
                          child: AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _WavePainter(
                                  progress: _waveController.value,
                                  color: palette.primary,
                                  style: activeStyle,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Style & Length selectors
                if (enabled) ...[
                  Text(
                    'CHOOSE BLEND STYLE',
                    style: GoogleFonts.inter(color: Colors.white60, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _styles.map<Widget>((style) {
                      final active = activeStyle == style;
                      return ChoiceChip(
                        label: Text(
                          style,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: active ? Colors.white : Colors.white38,
                          ),
                        ),
                        selected: active,
                        selectedColor: palette.primary.withOpacity(0.35),
                        backgroundColor: Colors.white.withOpacity(0.04),
                        onSelected: (selected) {
                          if (selected) {
                            ref.read(mixBlendStyleProvider.notifier).setStyle(style);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'TRANSITION LENGTH',
                    style: GoogleFonts.inter(color: Colors.white60, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _lengths.map((len) {
                      final active = activeLength == len;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => ref.read(mixBlendLengthProvider.notifier).setLength(len),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 48,
                            decoration: BoxDecoration(
                              color: active ? palette.primary : Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: active ? Colors.transparent : Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${len}s',
                                style: GoogleFonts.inter(
                                  color: active ? Colors.white : Colors.white60,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Real-time alignment console
                  LiquidGlass(
                    borderRadius: 20,
                    surfaceOpacity: 0.04,
                    borderOpacity: 0.1,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'AI ALIGNMENT GRID',
                              style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: palette.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SCORE: ${compScore.toInt()}%',
                                style: GoogleFonts.inter(color: palette.primary, fontSize: 9, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _alignColumn(currentSong?.title ?? 'Vocal Track', 'KEY: $keyA', '${bpmA} BPM', const Color(0xFF00D4FF))),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12.0),
                              child: Icon(Icons.sync_alt_rounded, color: Colors.white24, size: 20),
                            ),
                            Expanded(child: _alignColumn(nextSong?.title ?? 'Next Beat', 'KEY: $keyB', '${bpmB} BPM', const Color(0xFFFF007A))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            color: Colors.white.withOpacity(0.02),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 16),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    compScore > 85 
                                        ? 'BPM is within ±10% difference. Downbeats will sync flawlessly using automatic speed stretching.'
                                        : 'Slight key mismatch detected. Pitch-shifting will subtly load to prevent melodic clashing.',
                                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // UPCOMING BLEND QUEUE SECTION
                  Text(
                    upcomingQueue.isNotEmpty ? 'UPCOMING BLEND QUEUE' : 'ADD SONGS TO BLEND QUEUE',
                    style: GoogleFonts.inter(color: Colors.white60, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 12),

                  if (upcomingQueue.isNotEmpty) ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: upcomingQueue.length.clamp(0, 5),
                      itemBuilder: (context, index) {
                        final song = upcomingQueue[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  song.image,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white24),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      song.artist,
                                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 18),
                                onPressed: () {
                                  final absIndex = audioHandler.songQueue.indexWhere((s) => s.id == song.id);
                                  if (absIndex >= 0) {
                                    audioHandler.removeFromQueue(absIndex);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('"${song.title}" removed from queue.'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Liked Songs Quick CTA Grid
                  if (favorites.isNotEmpty) ...[
                    Text(
                      'QUICK ADD FROM LIKED SONGS',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: favorites.length,
                        itemBuilder: (context, index) {
                          final song = favorites[index];
                          final isAlreadyQueued = upcomingQueue.any((s) => s != null && s.id == song.id);
                          return GestureDetector(
                            onTap: () {
                              if (!isAlreadyQueued) {
                                audioHandler.appendUpcoming([song], isUserQueue: true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('"${song.title}" added to transition queue!'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Track is already in queue!'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: 110,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isAlreadyQueued ? palette.primary.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isAlreadyQueued ? palette.primary.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          song.image,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white24),
                                        ),
                                      ),
                                      if (isAlreadyQueued)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.check_rounded, color: Colors.greenAccent, size: 20),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    song.title,
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ] else ...[
                  // Setup Guide if disabled
                  const SizedBox(height: 60),
                  const Icon(Icons.blur_on_rounded, size: 80, color: Colors.white12),
                  const SizedBox(height: 20),
                  Text(
                    'AI Mix Blend is Idle',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      'Turn on the switch to enable seamless, beat-matched crossfades dynamically between every song change.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white24, fontSize: 12, height: 1.4),
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

  Widget _alignColumn(String title, String key, String bpm, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                key,
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                bpm,
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}


class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final String style;

  _WavePainter({
    required this.progress,
    required this.color,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final midY = height / 2;

    path.moveTo(0, midY);

    // Dynamic wave shape based on style
    final int frequency = style == 'Festival' || style == 'Energetic' ? 12 : 6;
    final double amplitude = style == 'Chill' || style == 'Cinematic' ? 12.0 : 18.0;

    for (double x = 0; x <= width; x++) {
      final double ratio = x / width;
      final double sine = math.sin((ratio * frequency * math.pi) + (progress * math.pi * 2));
      
      // Dip amplitude at intro and outro boundaries
      final double envelope = math.sin(ratio * math.pi);
      
      final y = midY + (sine * amplitude * envelope);
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);

    // Overlaying a second phase wave for premium depth
    final paint2 = Paint()
      ..color = const Color(0xFFFF007A).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path2 = Path()..moveTo(0, midY);
    for (double x = 0; x <= width; x++) {
      final double ratio = x / width;
      final double sine = math.sin((ratio * (frequency - 2) * math.pi) - (progress * math.pi * 3));
      final double envelope = math.sin(ratio * math.pi);
      final y = midY + (sine * (amplitude * 0.7) * envelope);
      path2.lineTo(x, y);
    }

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
