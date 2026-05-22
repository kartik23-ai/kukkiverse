import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/haptics/music_haptics.dart';
import '../core/theme/app_colors.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../providers/providers.dart';

/// ═══════════════════════════════════════════════════════════════
/// Magnetic Drag & Drop — Long-press a song → it becomes a
/// glowing disk. Screen zooms out to show playlists as gravity
/// wells. Drag the disk into a well to add to playlist.
/// ═══════════════════════════════════════════════════════════════
class MagneticPlaylistDrop extends StatefulWidget {
  const MagneticPlaylistDrop({
    super.key,
    required this.song,
    required this.playlists,
    required this.onAddToPlaylist,
    required this.onDismiss,
  });

  final SongModel song;
  final List<PlaylistModel> playlists;
  final void Function(String playlistId) onAddToPlaylist;
  final VoidCallback onDismiss;

  @override
  State<MagneticPlaylistDrop> createState() => _MagneticPlaylistDropState();
}

class _MagneticPlaylistDropState extends State<MagneticPlaylistDrop>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  Offset _diskPos = Offset.zero;
  int _hoveredWell = -1;
  bool _dropped = false;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sz = MediaQuery.of(context).size;
      setState(() => _diskPos = Offset(sz.width / 2, sz.height * 0.3));
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  List<Offset> _wellPositions(Size size) {
    final count = widget.playlists.length;
    if (count == 0) return [];
    final centerY = size.height * 0.65;
    final positions = <Offset>[];
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * math.pi + math.pi / 6;
      final rx = size.width * 0.3;
      final ry = size.height * 0.15;
      positions.add(Offset(
        size.width / 2 + math.cos(angle) * rx,
        centerY + math.sin(angle) * ry,
      ));
    }
    return positions;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dropped) return;
    setState(() {
      _diskPos += d.delta;
      // Check proximity to wells
      final sz = MediaQuery.of(context).size;
      final wells = _wellPositions(sz);
      _hoveredWell = -1;
      for (var i = 0; i < wells.length; i++) {
        final dist = (wells[i] - _diskPos).distance;
        if (dist < 50) {
          _hoveredWell = i;
          break;
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_dropped) return;
    if (_hoveredWell >= 0) {
      _dropIntoBell(_hoveredWell);
    }
  }

  void _dropIntoBell(int index) {
    setState(() => _dropped = true);
    MusicHaptics.dropImpact();
    final pId = widget.playlists[index].id;

    Future.delayed(const Duration(milliseconds: 600), () {
      widget.onAddToPlaylist(pId);
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final wells = _wellPositions(sz);

    return AnimatedBuilder(
      animation: Listenable.merge([_entryCtrl, _pulseCtrl]),
      builder: (context, _) {
        final entry = Curves.easeOutBack.transform(_entryCtrl.value);
        final pulse = _pulseCtrl.value;

        return Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              width: sz.width,
              height: sz.height,
              color: Color.lerp(Colors.transparent, Colors.black, entry * 0.85),
              child: Stack(
                children: [
                  // Gravity wells (playlists)
                  for (var i = 0; i < wells.length; i++)
                    Positioned(
                      left: wells[i].dx - 40,
                      top: wells[i].dy - 40,
                      child: AnimatedScale(
                        scale: entry * (_hoveredWell == i ? 1.3 + pulse * 0.1 : 1.0),
                        duration: const Duration(milliseconds: 200),
                        child: _GravityWell(
                          playlist: widget.playlists[i],
                          isHovered: _hoveredWell == i,
                          pulse: pulse,
                        ),
                      ),
                    ),

                  // Floating disk (the song)
                  if (!_dropped)
                    Positioned(
                      left: _diskPos.dx - 35,
                      top: _diskPos.dy - 35,
                      child: GestureDetector(
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: AnimatedScale(
                          scale: entry,
                          duration: Duration.zero,
                          child: _FloatingDisk(
                            song: widget.song,
                            pulse: pulse,
                          ),
                        ),
                      ),
                    ),

                  // Absorbed effect
                  if (_dropped && _hoveredWell >= 0)
                    Positioned(
                      left: wells[_hoveredWell].dx - 30,
                      top: wells[_hoveredWell].dy - 30,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1.0, end: 0.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInBack,
                        builder: (_, val, child) => Transform.scale(
                          scale: val,
                          child: Opacity(opacity: val, child: child),
                        ),
                        child: _FloatingDisk(song: widget.song, pulse: 0),
                      ),
                    ),

                  // Instructions
                  Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: entry,
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        'Drag to a playlist',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FloatingDisk extends StatelessWidget {
  const _FloatingDisk({required this.song, required this.pulse});
  final SongModel song;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.9),
            AppColors.accent.withValues(alpha: 0.4),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3 + pulse * 0.2),
            blurRadius: 20 + pulse * 10,
            spreadRadius: 2 + pulse * 4,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white.withValues(alpha: 0.9),
          size: 28,
        ),
      ),
    );
  }
}

class _GravityWell extends StatelessWidget {
  const _GravityWell({
    required this.playlist,
    required this.isHovered,
    required this.pulse,
  });
  final PlaylistModel playlist;
  final bool isHovered;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final glowColor = isHovered
        ? const Color(0xFF06B6D4)
        : const Color(0xFF6366F1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                glowColor.withValues(alpha: isHovered ? 0.4 : 0.15),
                glowColor.withValues(alpha: isHovered ? 0.15 : 0.05),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: glowColor.withValues(alpha: isHovered ? 0.6 : 0.2),
              width: isHovered ? 2 : 1,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.3 + pulse * 0.1),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.album_rounded,
                color: glowColor.withValues(alpha: isHovered ? 0.8 : 0.4),
                size: 22,
              ),
              Text(
                '${playlist.songs.length}',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: isHovered ? 0.8 : 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: Text(
            playlist.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: isHovered ? 0.8 : 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Shows the magnetic drop overlay as a full-screen modal.
void showMagneticPlaylistDrop(
  BuildContext context,
  WidgetRef ref,
  SongModel song,
) {
  final playlists = ref.read(playlistsProvider).where((p) => !p.isPrivate).toList();
  if (playlists.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create a playlist first in the Library tab'),
        backgroundColor: Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  HapticFeedback.heavyImpact();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => MagneticPlaylistDrop(
      song: song,
      playlists: playlists,
      onAddToPlaylist: (playlistId) {
        ref.read(playlistsProvider.notifier).addToPlaylist(playlistId, song);
        final name = playlists.firstWhere((p) => p.id == playlistId).name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to "$name"'),
            backgroundColor: const Color(0xFF1A1A2E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onDismiss: () => entry.remove(),
    ),
  );

  Overlay.of(context).insert(entry);
}
