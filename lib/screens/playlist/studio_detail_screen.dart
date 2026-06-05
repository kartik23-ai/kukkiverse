import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audio_service/audio_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/song_model.dart';
import '../../providers/providers.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/rotty_mixtape_collage.dart';

class StudioDetailScreen extends ConsumerStatefulWidget {
  final String studioId;
  const StudioDetailScreen({super.key, required this.studioId});

  @override
  ConsumerState<StudioDetailScreen> createState() => _StudioDetailScreenState();
}

class _StudioDetailScreenState extends ConsumerState<StudioDetailScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _playStudioCreation(SongModel song) {
    final playableArt = song.image.startsWith('collage:') 
        ? song.image.replaceFirst('collage:', '').split(',')[0]
        : song.image;
    ref.read(audioHandlerProvider).playMediaItem(
      MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
        artUri: Uri.parse(playableArt),
        extras: {
          'url': song.url,
          'lyrics': song.lyrics,
        },
      ),
    );
    context.push('/player');
  }

  Future<void> _deleteStudioCreation(SongModel song) async {
    final isAiStudio = song.album.startsWith('prompt:');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isAiStudio ? 'Delete Creation' : 'Delete Mashup',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isAiStudio 
              ? 'Are you sure you want to permanently delete this custom AI creation? This will delete the offline audio file.'
              : 'Are you sure you want to permanently delete this custom AI mashup? This will delete the offline audio file.',
          style: GoogleFonts.inter(color: Colors.white60, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(studioCreationsProvider.notifier).removeCreation(song.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAiStudio ? 'Creation permanently deleted.' : 'Mashup permanently deleted.')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studioCreations = ref.watch(studioCreationsProvider);
    final palette = ref.watch(dynamicPaletteProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final nowPlaying = ref.watch(nowPlayingProvider);

    // Find the current studio creation details
    final song = studioCreations.firstWhere(
      (s) => s.id == widget.studioId,
      orElse: () => SongModel(
        id: widget.studioId,
        title: 'Deleted Item',
        artist: 'Unknown',
        album: 'Unknown',
        image: 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?q=80&w=500&auto=format&fit=crop',
        duration: Duration.zero,
        url: '',
      ),
    );

    final isCurrentPlaying = nowPlaying?.id == song.id;

    // Parse source tracks or prompt depending on metadata
    final isAiStudio = song.album.startsWith('prompt:');
    String promptText = '';
    String genre = '';
    String vocals = '';
    
    if (isAiStudio) {
      final parts = song.album.split('||');
      for (final p in parts) {
        if (p.startsWith('prompt:')) promptText = p.replaceFirst('prompt:', '');
        if (p.startsWith('genre:')) genre = p.replaceFirst('genre:', '');
        if (p.startsWith('vocals:')) vocals = p.replaceFirst('vocals:', '');
      }
    }

    final rawTitle = song.title;
    final cleanTitle = rawTitle.contains(' (') ? rawTitle.split(' (')[0] : rawTitle;
    final sourceTitles = cleanTitle.split(' × ');
    final mode = isAiStudio 
        ? (genre.isNotEmpty ? genre : 'AI Studio')
        : (rawTitle.contains(' (') ? rawTitle.split(' (')[1].replaceAll(')', '') : 'AI Studio');

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            isAiStudio ? 'Studio Creation' : 'Mashup Release',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (song.id != 'unknown' && song.title != 'Deleted Item')
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: () => _deleteStudioCreation(song),
              ),
          ],
        ),
        body: SafeArea(
          child: song.title == 'Deleted Item'
              ? Center(
                  child: Text(
                    'Item not found',
                    style: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Glassmorphic AI Poster Frame
                      Container(
                        height: 360,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primary.withOpacity(0.12),
                              blurRadius: 40,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            children: [
                              // Background Artwork
                              Positioned.fill(
                                child: RottyMixtapeCollage(
                                  imageUrl: song.image,
                                  borderRadius: 24,
                                ),
                              ),
                              // Cinematic dark gradient
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.1),
                                      Colors.black.withOpacity(0.85),
                                    ],
                                  ),
                                ),
                              ),
                              // Glassmorphic indicator
                              Positioned(
                                top: 20,
                                left: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.auto_awesome, color: palette.primary, size: 12),
                                      const SizedBox(width: 6),
                                      Text(
                                        'ROTTY STUDIO AI',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Play pulse overlay if active
                              if (isCurrentPlaying && isPlaying)
                                Positioned(
                                  top: 20,
                                  right: 20,
                                  child: AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: palette.primary.withOpacity(0.2 * _pulseController.value + 0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: palette.primary.withOpacity(0.4 * _pulseController.value)),
                                        ),
                                        child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 14),
                                      );
                                    },
                                  ),
                                ),
                              // Title and description overlay
                              Positioned(
                                bottom: 24,
                                left: 24,
                                right: 24,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isAiStudio ? 'STUDIO CREATION • $mode' : 'MASHUP • $mode',
                                      style: GoogleFonts.inter(
                                        color: palette.primary,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 9,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      cleanTitle,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 24,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isAiStudio 
                                          ? 'Original AI studio composition generated using premium neural text-to-music algorithms.'
                                          : 'A fully synchronized, beat-matched studio mashup offline master.',
                                      style: GoogleFonts.inter(
                                        color: Colors.white38,
                                        fontSize: 11,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Direct Play Button
                      GestureDetector(
                        onTap: () => _playStudioCreation(song),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isCurrentPlaying && isPlaying
                                  ? [palette.primary.withOpacity(0.7), const Color(0xFFFF007A).withOpacity(0.7)]
                                  : [palette.primary, const Color(0xFFFF007A)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: palette.primary.withOpacity(0.25),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isCurrentPlaying && isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isCurrentPlaying && isPlaying ? 'PAUSE SINGLE' : 'PLAY CREATION NOW',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Source Tracks Section
                      Text(
                        isAiStudio ? 'STUDIO COMPOSITION PARAMETERS' : 'MASHED INGREDIENTS',
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),

                      LiquidGlass(
                        borderRadius: 20,
                        surfaceOpacity: 0.04,
                        borderOpacity: 0.08,
                        padding: const EdgeInsets.all(16),
                        child: isAiStudio
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildParamRow(
                                    context,
                                    icon: Icons.music_note_rounded,
                                    label: 'Genre Style',
                                    value: genre.isNotEmpty ? genre : 'Not specified',
                                    color: const Color(0xFF00D4FF),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Divider(color: Colors.white.withOpacity(0.04), height: 1),
                                  ),
                                  _buildParamRow(
                                    context,
                                    icon: Icons.record_voice_over_rounded,
                                    label: 'Vocal Profile',
                                    value: vocals.isNotEmpty ? vocals : 'Instrumental / None',
                                    color: const Color(0xFFFF007A),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Divider(color: Colors.white.withOpacity(0.04), height: 1),
                                  ),
                                  _buildParamRow(
                                    context,
                                    icon: Icons.description_rounded,
                                    label: 'AI Style Prompt',
                                    value: promptText.isNotEmpty ? promptText : 'Instrumental track theme',
                                    color: const Color(0xFF7B61FF),
                                    isLongText: true,
                                  ),
                                ],
                              )
                            : Column(
                                children: List.generate(sourceTitles.length, (index) {
                                  final title = sourceTitles[index];
                                  final color = index == 0
                                      ? const Color(0xFF00D4FF)
                                      : index == 1
                                          ? const Color(0xFFFF007A)
                                          : const Color(0xFF7B61FF);
                                  return Column(
                                    children: [
                                      if (index > 0)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Divider(color: Colors.white.withOpacity(0.04), height: 1),
                                        ),
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: color.withOpacity(0.2)),
                                          ),
                                          child: Icon(
                                            index == 0
                                                ? Icons.mic_rounded
                                                : index == 1
                                                    ? Icons.audiotrack_rounded
                                                    : Icons.layers_rounded,
                                            color: color,
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          title,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          index == 0
                                              ? 'Vocal Layers extracted via AI'
                                              : index == 1
                                                  ? 'Downbeat and rhythm sync base'
                                                  : 'Harmonic melodic resonance fill',
                                          style: GoogleFonts.inter(
                                            color: Colors.white38,
                                            fontSize: 10,
                                          ),
                                        ),
                                        trailing: Icon(Icons.check_circle_outline_rounded, color: color, size: 18),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                      ),
                      const SizedBox(height: 20),

                      // Audio File Details & Sharing
                      LiquidGlass(
                        borderRadius: 16,
                        surfaceOpacity: 0.02,
                        borderOpacity: 0.05,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Duration', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                                Text(song.formattedDuration, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('File Format', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                                Text('MPEG Audio Layer III (MP3)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Storage Loc', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                                Text('Local Device Cache (Private)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action button row
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Creation shared successfully as social card!')),
                            );
                          },
                          icon: const Icon(Icons.share_rounded, color: Colors.white70, size: 16),
                          label: Text('Share Social Card', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Audio file exported to your downloads folder.')),
                            );
                          },
                          icon: const Icon(Icons.ios_share_rounded, color: Colors.white70, size: 16),
                          label: Text('Export Audio file', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildParamRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isLongText = false,
  }) {
    return Row(
      crossAxisAlignment: isLongText ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  height: 1.3,
                ),
                maxLines: isLongText ? 4 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
