import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../models/song_model.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../utils/play_song.dart';
import '../../widgets/album_stage_3d.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/song_options_sheet.dart';
import '../../models/playlist_model.dart';
import '../../providers/premium_providers.dart';
import '../../services/storage_service.dart';
import '../../services/ai_image_service.dart';
import '../../widgets/rotty_glow_r_skeleton.dart';
import '../../widgets/elite_background.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({
    super.key,
    required this.albumId,
    required this.title,
    this.songs,
    this.image,
  });

  final String albumId;
  final String title;
  final List<SongModel>? songs;
  final String? image;

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  bool _playAllWave = false;

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider);
    final playlist = playlists.cast<PlaylistModel?>().firstWhere((p) => p?.id == widget.albumId, orElse: () => null);
    final isPrivate = playlist?.isPrivate ?? false;
    final vaultUnlocked = ref.watch(vaultUnlockedProvider);

    if (isPrivate && !vaultUnlocked) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: _VaultInlineUnlock(
                    playlistName: playlist?.name ?? 'Secure Playlist',
                    onUnlocked: () {
                      ref.read(vaultUnlockedProvider.notifier).state = true;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final cached = widget.songs;
    final asyncSongs = ref.watch(albumSongsProvider(widget.albumId));
    final list = cached ?? asyncSongs.valueOrNull ?? [];
    final String img;
    if (widget.albumId == 'daily_mix') {
      img = widget.image ?? AiImageService.getCoverUrl(
        prompt: 'cyberpunk daily music playlist cover art, futuristic glowing lines, premium dark neon soundwave concept',
        seed: 'daily_mix_${DateTime.now().day}',
      );
    } else if (widget.albumId == 'weekly_top') {
      img = widget.image ?? AiImageService.getCoverUrl(
        prompt: 'weekly hitlist music chart album art, glowing synth vinyl disc, detailed neon party lights design',
        seed: 'weekly_hitlist_${DateTime.now().year}_${DateTime.now().month}',
      );
    } else {
      img = widget.image ?? (list.isNotEmpty ? list.first.image : '');
    }

    final isWindows = Theme.of(context).platform == TargetPlatform.windows;

    final scaffold = Scaffold(
      backgroundColor: isWindows ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: isWindows ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (img.isNotEmpty)
                    Hero(
                      tag: 'album_bg_hero_${widget.albumId}',
                      child: CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.black45),
                        errorWidget: (context, url, error) => Container(color: Colors.black54),
                      ),
                    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(1.1, 1.1), end: const Offset(1, 1)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          isWindows
                              ? Colors.black.withValues(alpha: 0.75)
                              : AppColors.bg.withValues(alpha: 0.98),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 56),
                        if (img.isNotEmpty)
                          AlbumStage3D(imageUrl: img, heroTag: 'album_hero_${widget.albumId}', size: 160),
                        const SizedBox(height: 16),
                        Text(widget.title, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .slideY(begin: 0.2, end: 0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text('${list.length} songs', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  const Spacer(),
                  if (list.isNotEmpty)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                      onPressed: () async {
                        setState(() => _playAllWave = true);
                        for (var i = 0; i < list.length && i < 5; i++) {
                          await Future.delayed(const Duration(milliseconds: 120));
                        }
                        await playSongWithContext(ref, list.first, playlist: list, isPlayAll: true);
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(_playAllWave ? 'Starting…' : 'Play All'),
                    ),
                ],
              ),
            ),
          ),
          if (cached == null && asyncSongs.isLoading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, idx) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: RottyGlowRSkeleton.list(height: 72),
                  ),
                  childCount: 5,
                ),
              ),
            )
          else if (list.isEmpty)
            SliverFillRemaining(child: Center(child: Text('No songs found', style: GoogleFonts.inter(color: AppColors.textTertiary))))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final song = list[i];
                  final currentSong = ref.watch(nowPlayingProvider);
                  return SongTile(
                    song: song,
                    showIndex: true,
                    index: i,
                    isPlaying: currentSong?.id == song.id,
                    onTap: () async {
                      await playSongWithContext(ref, song, playlist: list);
                    },
                    onMore: () => showSongOptionsSheet(context, ref, song),
                  )
                      .animate()
                      .fadeIn(delay: (50 * i).ms)
                      .slideX(begin: 0.05, end: 0);
                },
                childCount: list.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );

    if (isWindows) {
      return RottyDynamicAuroraBackground(
        intensity: 0.8,
        child: scaffold,
      );
    }
    return scaffold;
  }
}

class _VaultInlineUnlock extends StatefulWidget {
  final String playlistName;
  final VoidCallback onUnlocked;

  const _VaultInlineUnlock({
    required this.playlistName,
    required this.onUnlocked,
  });

  @override
  State<_VaultInlineUnlock> createState() => _VaultInlineUnlockState();
}

class _VaultInlineUnlockState extends State<_VaultInlineUnlock> {
  final _pinCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _verify() {
    final pin = _pinCtrl.text;
    if (pin.length != 4) {
      setState(() => _error = 'PIN must be exactly 4 digits');
      return;
    }
    final stored = StorageService().vaultPin;
    if (stored != null && stored.isNotEmpty && stored == pin) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'Incorrect PIN. Access Denied.');
      _pinCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1.5),
            ),
            child: const Icon(Icons.lock_rounded, size: 28, color: Colors.amber),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'PLAYLIST LOCKED',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.amber,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '"${widget.playlistName}" is secured inside your private vault.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your 4-digit vault PIN to unlock and view the contents.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 8),
          textAlign: TextAlign.center,
          onSubmitted: (_) => _verify(),
          decoration: InputDecoration(
            hintText: '••••',
            hintStyle: GoogleFonts.inter(color: Colors.white24, letterSpacing: 4),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.03),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.amber, width: 1.5)),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _verify,
          child: Text(
            'UNLOCK PLAYLIST',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.0),
          ),
        ),
      ],
    );
  }
}
