import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/haptics/music_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../models/song_model.dart';
import '../../providers/providers.dart';
import '../../widgets/rotty_glass.dart';

class DualDeckScreen extends ConsumerStatefulWidget {
  const DualDeckScreen({super.key});

  @override
  ConsumerState<DualDeckScreen> createState() => _DualDeckScreenState();
}

class _DualDeckScreenState extends ConsumerState<DualDeckScreen> {
  final _deckA = AudioPlayer();
  final _deckB = AudioPlayer();
  SongModel? _a;
  SongModel? _b;
  double _crossfade = 0.5;
  bool _previewA = false;
  bool _previewB = false;

  @override
  void dispose() {
    _deckA.dispose();
    _deckB.dispose();
    super.dispose();
  }

  Future<void> _loadDeck(AudioPlayer player, SongModel song, bool preview) async {
    final repo = ref.read(musicRepositoryProvider);
    final resolved = await repo.resolveSong(song);
    if (!resolved.hasPlayableUrl) return;
    await player.setAudioSource(
      AudioSource.uri(
        Uri.parse(resolved.url),
        headers: Platform.isWindows ? null : const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
          'Referer': 'https://www.jiosaavn.com/',
        },
      ),
    );
    if (preview) await player.play();
  }

  void _applyCrossfade() {
    _deckA.setVolume(1 - _crossfade);
    _deckB.setVolume(_crossfade);
    MusicHaptics.crossfade();
  }

  Future<void> _toggleDeck(AudioPlayer player, bool isA) async {
    if (isA) {
      setState(() => _previewA = !_previewA);
      if (_a == null) return;
      if (_previewA) {
        await player.play();
      } else {
        await player.pause();
      }
    } else {
      setState(() => _previewB = !_previewB);
      if (_b == null) return;
      if (_previewB) {
        await player.play();
      } else {
        await player.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentSongsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Dual Deck DJ', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('House party mode — preview & crossfade', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _deckCard('Deck A', _a, _previewA, () => _toggleDeck(_deckA, true))),
              const SizedBox(width: 12),
              Expanded(child: _deckCard('Deck B', _b, _previewB, () => _toggleDeck(_deckB, false))),
            ],
          ),
          const SizedBox(height: 24),
          RottyGlass(
            child: Column(
              children: [
                Text('Crossfade', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                Slider(
                  value: _crossfade,
                  activeColor: AppColors.accent,
                  onChanged: (v) {
                    setState(() => _crossfade = v);
                    _applyCrossfade();
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('A', style: GoogleFonts.inter(color: AppColors.textTertiary)),
                    Text('B', style: GoogleFonts.inter(color: AppColors.textTertiary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Pick tracks', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          ...recent.take(8).map((s) => ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: s.image, width: 48, height: 48, fit: BoxFit.cover),
                ),
                title: Text(s.title, style: GoogleFonts.inter(color: Colors.white)),
                subtitle: Text(s.artist, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(child: const Text('A'), onPressed: () async {
                      setState(() => _a = s);
                      await _loadDeck(_deckA, s, _previewA);
                      _applyCrossfade();
                    }),
                    TextButton(child: const Text('B'), onPressed: () async {
                      setState(() => _b = s);
                      await _loadDeck(_deckB, s, _previewB);
                      _applyCrossfade();
                    }),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _deckCard(String label, SongModel? song, bool preview, VoidCallback toggle) {
    return RottyGlass(
      child: Column(
        children: [
          Text(label, style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (song != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(imageUrl: song.image, height: 100, width: double.infinity, fit: BoxFit.cover),
            )
          else
            Container(height: 100, color: AppColors.bgCard, child: const Icon(Icons.album_rounded, color: Colors.white24, size: 40)),
          const SizedBox(height: 8),
          Text(song?.title ?? 'Empty', maxLines: 1, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
          IconButton(
            icon: Icon(preview ? Icons.pause_circle_filled : Icons.play_circle_filled, color: AppColors.accent, size: 40),
            onPressed: toggle,
          ),
        ],
      ),
    );
  }
}
