import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../models/song_model.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/song_options_sheet.dart';
import '../../widgets/song_tile.dart';
import '../../utils/play_song.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _input = TextEditingController();
  final _speech = stt.SpeechToText();
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _input.dispose();
    super.dispose();
  }

  void _submit(String q) {
    if (q.trim().isEmpty) return;
    ref.read(searchInputProvider.notifier).submit(q.trim());
    ref.read(searchHistoryProvider.notifier).add(q.trim());
    FocusScope.of(context).unfocus();
  }

  Future<void> _voiceSearch() async {
    bool available = _speech.isAvailable;
    if (!available) {
      try {
        available = await _speech.initialize().timeout(const Duration(seconds: 4));
      } catch (_) {
        available = false;
      }
    }
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice search not available or permission denied')),
        );
      }
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        _input.text = r.recognizedWords;
        if (r.finalResult) {
          _submit(r.recognizedWords);
          setState(() => _listening = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(debouncedSearchQueryProvider);
    final history = ref.watch(searchHistoryProvider);

    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text('Search', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Songs, albums, artists',
                        hintStyle: GoogleFonts.inter(color: AppColors.textTertiary),
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
                      ),
                      onSubmitted: _submit,
                      onChanged: (v) => ref.read(searchInputProvider.notifier).update(v),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_listening ? Icons.mic_rounded : Icons.mic_none_rounded, color: _listening ? AppColors.accent : AppColors.textTertiary),
                    onPressed: _voiceSearch,
                  ),
                ],
              ),
            ),
          ),
          if (query.isEmpty)
            Expanded(child: _discover(history))
          else ...[
            TabBar(
              controller: _tabs,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textTertiary,
              tabs: const [Tab(text: 'Songs'), Tab(text: 'Albums'), Tab(text: 'Artists')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _SongsTab(query: query),
                  _AlbumsTab(query: query),
                  _ArtistsTab(query: query),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _discover(List<String> history) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 160),
      children: [
        Text('Try "arijit sad song" or tap mic', style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 13)),
        const SizedBox(height: 16),
        if (history.isNotEmpty) ...[
          Row(
            children: [
              Text('Recent', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(searchHistoryProvider.notifier).clear(),
                child: Text('Clear', style: GoogleFonts.inter(color: AppColors.accent, fontSize: 12)),
              ),
            ],
          ),
          ...history.map((q) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded, color: AppColors.textTertiary),
                title: Text(q, style: GoogleFonts.inter(color: Colors.white)),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 18),
                  onPressed: () => ref.read(searchHistoryProvider.notifier).remove(q),
                ),
                onTap: () {
                  _input.text = q;
                  _submit(q);
                },
              )),
        ],
        Text('Trending', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ApiConstants.trendingSearches.map((q) {
            return ActionChip(
              label: Text(q, style: GoogleFonts.inter(color: Colors.white)),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              onPressed: () {
                _input.text = q;
                _submit(q);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SongsTab extends ConsumerWidget {
  const _SongsTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchSongsProvider(query));
    return results.when(
      data: (songs) => _songList(context, ref, songs),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, __) => const Center(child: Text('Error', style: TextStyle(color: Colors.white54))),
    );
  }
}

class _YouTubeTab extends ConsumerWidget {
  const _YouTubeTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchYouTubeSongsProvider(query));
    return results.when(
      data: (songs) => _songList(context, ref, songs),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, __) => const Center(child: Text('Error searching YouTube', style: TextStyle(color: Colors.white54))),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchAlbumsProvider(query));
    return results.when(
      data: (albums) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
        itemCount: albums.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final a = albums[i];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: a.image,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                memCacheWidth: 104,
                memCacheHeight: 104,
              ),
            ),
            title: Text(a.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('${a.year} • ${a.language}', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
            onTap: () => context.push('/album/${a.id}', extra: {'title': a.name, 'image': a.image}),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchArtistsProvider(query));
    return results.when(
      data: (artists) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
        itemCount: artists.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final a = artists[i];
          return ListTile(
            leading: CircleAvatar(backgroundImage: a.image.isNotEmpty ? NetworkImage(a.image) : null),
            title: Text(a.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            onTap: () => context.push('/artist/${a.id}', extra: {'name': a.name, 'image': a.image}),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

Widget _songList(BuildContext context, WidgetRef ref, List<SongModel> songs) {
  if (songs.isEmpty) {
    return Center(child: Text('No songs', style: GoogleFonts.inter(color: AppColors.textTertiary)));
  }
  final currentSong = ref.watch(nowPlayingProvider);
  return ListView.separated(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 160),
    itemCount: songs.length,
    separatorBuilder: (_, __) => const Divider(color: AppColors.glassBorder, height: 1),
    itemBuilder: (context, i) {
      final s = songs[i];
      return RepaintBoundary(
        child: SongTile(
          song: s,
          isPlaying: currentSong?.id == s.id,
          onTap: () async {
            await playSongWithContext(ref, s);
            if (context.mounted) context.push('/player');
          },
          onMore: () => showSongOptionsSheet(context, ref, s),
        ),
      );
    },
  );
}
