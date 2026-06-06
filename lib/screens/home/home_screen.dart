import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/mode_theme.dart';
import '../../core/modes/app_mode.dart';
import '../../providers/providers.dart';
import '../../models/song_model.dart';
import '../../widgets/app_scaffold.dart';
import '../../utils/greeting.dart';
import '../../utils/play_song.dart';
import '../../widgets/flashback_tile.dart';
import '../../widgets/streak_chip.dart';
import '../../widgets/song_options_sheet.dart';
import '../../widgets/song_tile.dart';
import '../../providers/premium_providers.dart';
import '../../widgets/crystal_shatter_skeleton.dart';
import '../../services/storage_service.dart';
import '../../widgets/rotty_glow_r_skeleton.dart';
import '../../services/ai_image_service.dart';
import 'dart:math' as math;


final homeCategoryProvider = StateProvider<String>((ref) => 'All');

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeDataProvider);
    final recent = ref.watch(recentSongsProvider);
    final suggestedSongsAsync = ref.watch(suggestedSongsProvider);
    final suggestedSongs = suggestedSongsAsync.valueOrNull ?? <SongModel>[];
    final aiOn = ref.watch(aiDjEnabledProvider);
    final premium = ref.watch(rottyPremiumProvider);
    final mode = ref.watch(appModeProvider);
    final mt = ModeTheme(mode);
    final activeCat = ref.watch(homeCategoryProvider);

    final homeArtistsAsync = ref.watch(homeArtistsProvider);
    final homeArtists = homeArtistsAsync.valueOrNull ?? [];

    final topArtists = homeArtists.isNotEmpty
        ? homeArtists.take(6).toList()
        : const [
            (name: 'Arijit Singh', img: 'https://c.saavncdn.com/artists/Arijit_Singh_004_20241118063717_150x150.jpg'),
            (name: 'Pritam', img: 'https://c.saavncdn.com/artists/Pritam_Chakraborty-20170711073326_150x150.jpg'),
            (name: 'A.R. Rahman', img: 'https://c.saavncdn.com/artists/AR_Rahman_002_20210120084455_150x150.jpg'),
            (name: 'Shreya Ghoshal', img: 'https://c.saavncdn.com/artists/Shreya_Ghoshal_007_20241101074144_150x150.jpg'),
            (name: 'Jubin Nautiyal', img: 'https://c.saavncdn.com/artists/Jubin_Nautiyal_003_20231130204020_150x150.jpg'),
            (name: 'Anuv Jain', img: 'https://c.saavncdn.com/artists/Anuv_Jain_500x500.jpg'),
          ];

    Future<void> onRefresh() async {
      ref.read(forceRefreshHomeProvider.notifier).state = true;
      ref.invalidate(homeDataProvider);
      ref.invalidate(recentSongsProvider);
      ref.invalidate(suggestedSongsProvider);
      ref.invalidate(homeArtistsProvider);
      if (activeCat != 'All') {
        ref.invalidate(albumSongsProvider('genre_$activeCat'));
      }
      if (premium) {
        ref.invalidate(aiTasteRadioProvider);
      }
      try {
        await ref.read(homeDataProvider.future);
      } catch (_) {}
    }

    return AppScaffold(
      bottomPadding: 0,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: onRefresh,
            builder: (context, refreshState, pulledExtent, refreshTriggerPullDistance, refreshIndicatorExtent) {
              final progress = (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
              final isRefreshing = refreshState == RefreshIndicatorMode.refresh;
              
              return Container(
                padding: const EdgeInsets.only(top: 8),
                alignment: Alignment.center,
                child: RottyRefresherSpinner(
                  progress: progress,
                  isRefreshing: isRefreshing,
                  accentColor: mt.accent,
                ),
              );
            },
          ),
          SliverToBoxAdapter(child: RepaintBoundary(child: _header(context, ref, premium, mt, mode))),
          SliverToBoxAdapter(child: RepaintBoundary(child: _categoryTabs(context, ref, mt))),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

            if (mode == RottyAppMode.focus)
              SliverToBoxAdapter(child: RepaintBoundary(child: _focusTimer(context, ref, mt))),
            if (mt.showQuickActions)
              SliverToBoxAdapter(child: RepaintBoundary(child: _searchBar(context, ref, mt))),
            if (mt.showQuickActions)
              SliverToBoxAdapter(child: RepaintBoundary(child: _quickActions(context, ref, mt))),

            if (mt.showExtras)
              SliverToBoxAdapter(child: RepaintBoundary(child: _aiRow(context, ref, aiOn, premium, mt))),
            if (mt.showDecorations) const SliverToBoxAdapter(child: RepaintBoundary(child: StreakChip())),
            if (mt.showDecorations) const SliverToBoxAdapter(child: RepaintBoundary(child: FlashbackTile())),
            if (mt.showExtras)
              SliverToBoxAdapter(child: RepaintBoundary(child: _labsEntry(context, mt))),
            
            if (activeCat != 'All') ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    '$activeCat Stations',
                    style: GoogleFonts.inter(
                      fontSize: 20 * mt.fontScale,
                      fontWeight: FontWeight.w700,
                      color: mt.textPrimary,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ref.watch(albumSongsProvider('genre_$activeCat')).when(
                data: (songs) {
                  if (songs.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No songs found in this category.',
                          style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 13),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, idx) {
                          final song = songs[idx];
                           return _SongCard(song: song, playlist: songs, mt: mt, section: activeCat);
                        },
                        childCount: songs.length,
                      ),
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) => RottyGlowRSkeleton.card(width: 148, height: 206),
                      childCount: 4,
                    ),
                  ),
                ),
                error: (_, __) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Failed to load category.',
                      style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ] else ...[
              if (recent.isNotEmpty)
                SliverToBoxAdapter(child: _sectionBox(context, ref, 'Continue Listening', recent.take(10).toList(), mt)),

              if (suggestedSongs.isNotEmpty)
                SliverToBoxAdapter(child: _sectionBox(context, ref, 'Recommended for You', suggestedSongs, mt)),

              _artistsSliver(context, ref, 'Top Artists', topArtists, mt),

              if (mt.showExtras)
                SliverToBoxAdapter(child: RepaintBoundary(child: _aiRadioSection(context, ref, mt))),

              _playlistHubSliver(context, ref, mt),

              SliverToBoxAdapter(child: IndianTopHitsBox(mt: mt)),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              home.when(
                data: (sections) {
                  final filtered = sections.entries.where((e) {
                    final key = e.key.toLowerCase();
                    return key != 'new releases' && key != 'top hits' && key != 'weekly top songs';
                  }).toList();
                  if (filtered.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = filtered[index];
                        return _sectionBox(context, ref, entry.key, entry.value, mt);
                      },
                      childCount: filtered.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
              
              SliverToBoxAdapter(child: NewReleasesBox(mt: mt)),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              // Popular Albums Section at the absolute bottom of the Home screen
              SliverToBoxAdapter(child: PopularAlbumsSection(mt: mt)),
            ],

            const SliverToBoxAdapter(child: BrandedFooter()),
            const SliverToBoxAdapter(child: SizedBox(height: 180)),
          ],
        ),
      );
  }

  Widget _categoryTabs(BuildContext context, WidgetRef ref, ModeTheme mt) {
    final categories = ['All', 'Chill', 'Devotional', 'Party', 'Sad', 'Punjabi', 'English'];
    final activeCat = ref.watch(homeCategoryProvider);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          return Consumer(
            builder: (context, ref, child) {
              final active = activeCat == cat;
              final isCatLoading = active && cat != 'All' && ref.watch(albumSongsProvider('genre_$cat')).isLoading;
              return GestureDetector(
                onTap: () => ref.read(homeCategoryProvider.notifier).state = cat,
                child: _LoadingChip(
                  isLoading: isCatLoading,
                  color: mt.accent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? mt.accent : mt.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? mt.accent : Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: mt.accent.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        cat,
                        style: GoogleFonts.inter(
                          color: active ? Colors.white : mt.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, bool premium, ModeTheme mt, RottyAppMode mode) {
    final isSupporter = StorageService().isSupporter;
    final displayName = StorageService().profileName.isEmpty ? '' : ', ${StorageService().profileName}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          AnimatedContainer(
            duration: ModeTheme.transitionDuration,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isSupporter
                  ? const LinearGradient(colors: [Colors.pinkAccent, Colors.purpleAccent])
                  : mt.accentGradient,
              boxShadow: [
                BoxShadow(
                  color: (isSupporter ? Colors.pinkAccent : mt.accent).withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(
              mode == RottyAppMode.focus ? Icons.self_improvement_rounded
                  : mode == RottyAppMode.sleep ? Icons.bedtime_rounded
                  : Icons.music_note_rounded,
              color: Colors.white, size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${getTimeGreeting()}$displayName',
                        style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSupporter) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.pink.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pinkAccent.withValues(alpha: 0.15),
                              blurRadius: 6,
                            )
                          ],
                        ),
                        child: Text(
                          'SUPPORTER 💖',
                          style: GoogleFonts.inter(
                            color: Colors.pinkAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  mode == RottyAppMode.focus ? 'Focus Time'
                      : mode == RottyAppMode.sleep ? 'Wind Down'
                      : 'Listen Now',
                  style: GoogleFonts.inter(
                    fontSize: 28 * mt.fontScale,
                    fontWeight: FontWeight.w800,
                    color: mt.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _focusTimer(BuildContext context, WidgetRef ref, ModeTheme mt) {
    final minutes = ref.watch(focusTimerMinutesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: AnimatedContainer(
        duration: ModeTheme.transitionDuration,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: mt.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: mt.accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.timer_rounded, color: mt.accent, size: 32),
            const SizedBox(height: 8),
            Text('Focus Timer', style: GoogleFonts.inter(color: mt.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Stay in the zone', style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [15, 25, 45, 60].map((m) {
                final selected = minutes == m;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('${m}m', style: GoogleFonts.inter(
                      color: selected ? Colors.white : mt.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    )),
                    selected: selected,
                    selectedColor: mt.accent,
                    backgroundColor: mt.surface,
                    onSelected: (_) => ref.read(focusTimerMinutesProvider.notifier).state = m,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(BuildContext context, WidgetRef ref, ModeTheme mt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: GestureDetector(
        onTap: () => ref.read(mainTabIndexProvider.notifier).state = 1,
        child: AnimatedContainer(
          duration: ModeTheme.transitionDuration,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: mt.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: mt.accent.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: mt.textSecondary, size: 22),
              const SizedBox(width: 12),
              Text('Songs, albums, artists', style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context, WidgetRef ref, ModeTheme mt) {
    final items = [
      ('Scenes', Icons.nightlight_round, '/scenes', const Color(0xFF7B61FF)),
      ('Concert', Icons.surround_sound_rounded, '/concert', const Color(0xFFFF6482)),
      ('Labs', Icons.science_rounded, '/labs', const Color(0xFF00D4FF)),
      ('Wrapped', Icons.insights_rounded, '/wrapped', const Color(0xFFF97316)),
      ('Drive', Icons.directions_car_filled_rounded, '/drive', const Color(0xFF6366F1)),
    ];
    return SizedBox(
      height: 88,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          final color = item.$4;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(item.$3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 82,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.28),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.0),
                      ),
                      child: Icon(item.$2, color: color, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.$1,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _aiRow(BuildContext context, WidgetRef ref, bool aiOn, bool premium, ModeTheme mt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: AnimatedContainer(
        duration: ModeTheme.transitionDuration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: mt.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: mt.accent.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: mt.accentGradient),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI DJ', style: GoogleFonts.inter(color: mt.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Smart queue from your vibe',
                      style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Switch.adaptive(
              value: aiOn,
              activeColor: mt.accent,
              onChanged: (v) => ref.read(aiDjEnabledProvider.notifier).state = v,
            ),
          ],
        ),
      ),
    );
  }

  Widget _labsEntry(BuildContext context, ModeTheme mt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Material(
        color: mt.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/labs'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF00D4FF)]),
                  ),
                  child: const Icon(Icons.science_rounded, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ROTTY Labs', style: GoogleFonts.inter(color: mt.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Aura • Cinema • Shake • Drive +', style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: mt.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionBox(BuildContext context, WidgetRef ref, String title, List<SongModel> songs, ModeTheme mt) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(title, style: GoogleFonts.inter(fontSize: 20 * mt.fontScale, fontWeight: FontWeight.w700, color: mt.textPrimary)),
          ),
          SizedBox(
            height: 206,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: songs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) => _SongCard(song: songs[i], playlist: songs, mt: mt, section: title),
            ),
          ),
        ],
      ),
    );
  }



  Widget _artistsSliver(BuildContext context, WidgetRef ref, String title, List<({String name, String img})> artists, ModeTheme mt) {
    return SliverToBoxAdapter(
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(title, style: GoogleFonts.inter(fontSize: 20 * mt.fontScale, fontWeight: FontWeight.w700, color: mt.textPrimary)),
            ),
            SizedBox(
              height: 120,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: artists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final artist = artists[i];
                  return GestureDetector(
                    onTap: () {
                      context.push('/artist/${artist.name}', extra: {
                        'name': artist.name,
                        'image': artist.img,
                      });
                    },
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: CachedNetworkImage(
                            imageUrl: artist.img,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            memCacheWidth: 152,
                            placeholder: (context, url) => Container(
                              width: 76,
                              height: 76,
                              color: Colors.white10,
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Colors.purple.withValues(alpha: 0.6), Colors.blue.withValues(alpha: 0.6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  artist.name.isNotEmpty ? artist.name[0] : '?',
                                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          artist.name,
                          style: GoogleFonts.inter(color: mt.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playlistHubSliver(BuildContext context, WidgetRef ref, ModeTheme mt) {
    return SliverToBoxAdapter(
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text('Playlist Hub', style: GoogleFonts.inter(fontSize: 20 * mt.fontScale, fontWeight: FontWeight.w700, color: mt.textPrimary)),
            ),
            SizedBox(
              height: 160,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  // Daily Mix Glassmorphic Card
                  GestureDetector(
                    onTap: () async {
                      final favorites = ref.read(favoritesProvider);
                      final recent = ref.read(storageServiceProvider).getRecentSongs();
                      final List<SongModel> dailyQueue = [];
                      dailyQueue.addAll(favorites.take(10));
                      dailyQueue.addAll(recent.take(10));
                      if (dailyQueue.isEmpty) {
                        final trending = await ref.read(apiServiceProvider).searchSongs('trending hindi lofi', limit: 15);
                        dailyQueue.addAll(trending);
                      }
                      if (context.mounted) {
                        final coverImg = AiImageService.getCoverUrl(
                          prompt: 'cyberpunk daily music playlist cover art, futuristic glowing lines, premium dark neon soundwave concept',
                          seed: 'daily_mix_${DateTime.now().day}',
                        );
                        context.push(
                          '/album/daily_mix',
                          extra: {
                            'title': 'Daily Mix',
                            'songs': dailyQueue,
                            'image': coverImg,
                          },
                        );
                      }
                    },
                    child: Container(
                      width: 260,
                      margin: const EdgeInsets.only(right: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFFA2D48).withValues(alpha: 0.15),
                            const Color(0xFF00FFFF).withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFA2D48).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('DAILY MIX', style: GoogleFonts.inter(color: const Color(0xFFFA2D48), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ),
                          const Spacer(),
                          Text('Your Daily Frequency', style: GoogleFonts.inter(color: mt.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Curated automatically from your favorites & recent listening taste.', style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 11, height: 1.3), maxLines: 2),
                        ],
                      ),
                    ),
                  ),
                  // Weekly Top Songs Card
                  GestureDetector(
                    onTap: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        final api = ref.read(apiServiceProvider);
                        final songs = await api.searchSongs('weekly top hindi hits', limit: 15);
                        if (context.mounted) {
                          Navigator.of(context).pop(); // Close loader
                          final coverImg = AiImageService.getCoverUrl(
                            prompt: 'weekly hitlist music chart album art, glowing synth vinyl disc, detailed neon party lights design',
                            seed: 'weekly_hitlist_${DateTime.now().year}_${DateTime.now().month}',
                          );
                          context.push(
                            '/album/weekly_top',
                            extra: {
                              'title': 'Weekly Hitlist',
                              'songs': songs,
                              'image': coverImg,
                            },
                          );
                        }
                      } catch (_) {
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF00FFFF).withValues(alpha: 0.12),
                            const Color(0xFF7F00FF).withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FFFF).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('WEEKLY TOP', style: GoogleFonts.inter(color: const Color(0xFF00FFFF), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ),
                          const Spacer(),
                          Text('Weekly Hitlist', style: GoogleFonts.inter(color: mt.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Fresh chartbusters updated globally for this week.', style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 11, height: 1.3), maxLines: 2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiRadioSection(BuildContext context, WidgetRef ref, ModeTheme mt) {
    final history = ref.watch(playHistoryProvider);
    final radio = ref.watch(aiTasteRadioProvider);

    if (!radio.isUnlocked) {
      final count = history.length;
      final pct = (count / 10).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: mt.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded, color: Colors.white38),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Taste Radio 🧠',
                      style: GoogleFonts.inter(
                        color: mt.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Unlock after listening to 10 tracks.',
                      style: GoogleFonts.inter(
                        color: mt.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(mt.accent.withValues(alpha: 0.6)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$count / 10 songs played',
                      style: GoogleFonts.inter(
                        color: mt.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (radio.isLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Taste Radio 🧠',
              style: GoogleFonts.inter(
                color: mt.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            RottyGlowRSkeleton.card(width: double.infinity, height: 160),
          ],
        ),
      );
    }

    if (radio.songs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: mt.accent.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: mt.accent.withValues(alpha: 0.06),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: mt.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, color: mt.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Radio Ready ✨',
                          style: GoogleFonts.inter(
                            color: mt.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Synthesize your listening DNA using LLM.',
                          style: GoogleFonts.inter(
                            color: mt.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mt.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    ref.read(aiTasteRadioProvider.notifier).generateRadio();
                  },
                  icon: const Icon(Icons.psychology_rounded, size: 18),
                  label: Text(
                    'SYNTHESIZE MY RADIO',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: mt.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        'AI RADIO',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    radio.title,
                    style: GoogleFonts.inter(
                      fontSize: 18 * mt.fontScale,
                      fontWeight: FontWeight.w800,
                      color: mt.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (radio.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                radio.description,
                style: GoogleFonts.inter(
                  color: mt.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          SizedBox(
            height: 206,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: radio.songs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) => _SongCard(
                song: radio.songs[i],
                playlist: radio.songs,
                mt: mt,
                section: 'ai_radio',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SongCard extends ConsumerWidget {
  const _SongCard({required this.song, required this.playlist, required this.mt, this.section = ''});
  final SongModel song;
  final List<SongModel> playlist;
  final ModeTheme mt;
  final String section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(nowPlayingProvider);
    final isCurrentlyPlaying = currentSong?.id == song.id;

    final imageWidget = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        boxShadow: mt.showDecorations
            ? [
                BoxShadow(color: mt.accent.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -2),
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: CachedNetworkImage(
          imageUrl: song.image,
          width: 148, height: 140,
          fit: BoxFit.cover,
          memCacheWidth: 296,
          fadeInDuration: Duration.zero,
          placeholder: (_, __) => Container(color: mt.surface, width: 148, height: 140),
          errorWidget: (_, __, ___) => Container(
            color: mt.surface,
            width: 148,
            height: 140,
            child: const Icon(Icons.music_note_rounded, color: Colors.white24),
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () async {
          try {
            await playSongWithContext(ref, song, playlist: playlist, runAiDj: ref.read(aiDjEnabledProvider));
            if (context.mounted) context.push('/player');
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not play ${song.title}. Try another song.')),
              );
            }
          }
        },
        onLongPress: () => showSongOptionsSheet(context, ref, song),
        child: SizedBox(
          width: 148,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              isCurrentlyPlaying
                  ? imageWidget
                  : Hero(
                      tag: 'album_art_${song.id}_$section',
                      child: imageWidget,
                    ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, style: GoogleFonts.inter(color: mt.textPrimary, fontSize: 13, fontWeight: FontWeight.w600, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(song.artist, style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 11, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _genresRow(BuildContext context, WidgetRef ref, ModeTheme mt) {
  const genres = [
    ('Love', LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)])),
    ('Devotional', LinearGradient(colors: [Color(0xFFF12711), Color(0xFFF5AF19)])),
    ('Party', LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)])),
    ('Workout', LinearGradient(colors: [Color(0xFFFC4A1A), Color(0xFFF7B733)])),
    ('Chill', LinearGradient(colors: [Color(0xFF00B4DB), Color(0xFF0083B0)])),
    ('Sad', LinearGradient(colors: [Color(0xFF3A6073), Color(0xFF3A6073)])),
    ('Punjabi', LinearGradient(colors: [Color(0xFF7F00FF), Color(0xFFE100FF)])),
    ('English', LinearGradient(colors: [Color(0xFFED213A), Color(0xFF93291E)])),
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Explore Genres & Moods',
          style: GoogleFonts.inter(
            fontSize: 18 * mt.fontScale,
            fontWeight: FontWeight.w800,
            color: mt.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 48,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: genres.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final item = genres[i];
            return GestureDetector(
              onTap: () {
                context.push('/album/genre_${item.$1}', extra: {
                  'title': '${item.$1} Station',
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: mt.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: item.$2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.$1,
                      style: GoogleFonts.inter(
                        color: mt.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 14),
    ],
  );
}


class PopularAlbumsSection extends ConsumerStatefulWidget {
  const PopularAlbumsSection({super.key, required this.mt});
  final ModeTheme mt;

  @override
  ConsumerState<PopularAlbumsSection> createState() => _PopularAlbumsSectionState();
}

class _PopularAlbumsSectionState extends ConsumerState<PopularAlbumsSection> {
  final List<Map<String, String>> _albums = [
    {
      'id': 'name_Kabir Singh',
      'name': 'Kabir Singh',
      'img': 'https://image.pollinations.ai/prompt/Kabir%20Singh%20soundtrack%20cover?width=250&height=250',
    },
    {
      'id': 'name_Aashiqui 2',
      'name': 'Aashiqui 2',
      'img': 'https://image.pollinations.ai/prompt/Aashiqui%202%20soundtrack%20cover?width=250&height=250',
    },
    {
      'id': 'name_Rockstar',
      'name': 'Rockstar',
      'img': 'https://image.pollinations.ai/prompt/Rockstar%20soundtrack%20cover?width=250&height=250',
    },
    {
      'id': 'name_Yeh Jawaani Hai Deewani',
      'name': 'Yeh Jawaani Hai Deewani',
      'img': 'https://image.pollinations.ai/prompt/Yeh%20Jawaani%20Hai%20Deewani%20soundtrack%20cover?width=250&height=250',
    },
    {
      'id': 'name_Tamasha',
      'name': 'Tamasha',
      'img': 'https://image.pollinations.ai/prompt/Tamasha%20soundtrack%20cover?width=250&height=250',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadRealAlbumDetails();
  }

  Future<void> _loadRealAlbumDetails() async {
    final api = ref.read(apiServiceProvider);
    for (int i = 0; i < _albums.length; i++) {
      final name = _albums[i]['name']!;
      try {
        final results = await api.searchAlbums(name, limit: 1);
        if (results.isNotEmpty) {
          final realId = results.first.id;
          final realImg = results.first.image;
          if (mounted) {
            setState(() {
              _albums[i] = {
                'id': realId,
                'name': name,
                'img': realImg,
              };
            });
          }
        }
      } catch (e) {
        debugPrint('HomeScreen: Popular album "$name" load failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mt = widget.mt;
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text(
              'Popular Albums',
              style: GoogleFonts.inter(
                fontSize: (20 * mt.fontScale).toDouble(),
                fontWeight: FontWeight.w700,
                color: mt.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 196,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _albums.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final a = _albums[i];
                final img = a['img']!;
                return GestureDetector(
                  onTap: () => context.push('/album/${a['id']}', extra: {'title': a['name'], 'image': img}),
                  child: SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: CachedNetworkImage(
                              imageUrl: img,
                              width: 140,
                              height: 132,
                              fit: BoxFit.cover,
                              memCacheWidth: 280,
                              placeholder: (_, __) => Container(color: mt.surface, width: 140, height: 132),
                              errorWidget: (_, __, ___) => Container(color: mt.surface, width: 140, height: 132, child: const Icon(Icons.album_rounded, color: Colors.white24)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a['name']!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: mt.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingChip extends StatefulWidget {
  const _LoadingChip({required this.child, required this.color, required this.isLoading});
  final Widget child;
  final Color color;
  final bool isLoading;

  @override
  State<_LoadingChip> createState() => _LoadingChipState();
}

class _LoadingChipState extends State<_LoadingChip> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.15 + _ctrl.value * 0.45),
                blurRadius: 4 + _ctrl.value * 10,
                spreadRadius: _ctrl.value * 1.5,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

class NewReleasesBox extends ConsumerStatefulWidget {
  const NewReleasesBox({super.key, required this.mt});
  final ModeTheme mt;

  @override
  ConsumerState<NewReleasesBox> createState() => _NewReleasesBoxState();
}

class _NewReleasesBoxState extends ConsumerState<NewReleasesBox> {
  bool _isBollywood = true;

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(_isBollywood ? bollywoodNewReleasesProvider : hollywoodNewReleasesProvider);
    final mt = widget.mt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF7B61FF).withValues(alpha: 0.12),
              const Color(0xFFFF6482).withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Releases',
                    style: GoogleFonts.inter(
                      fontSize: (20 * mt.fontScale).toDouble(),
                      fontWeight: FontWeight.w700,
                      color: mt.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPill('Bollywood', _isBollywood, () {
                          if (!_isBollywood) setState(() => _isBollywood = true);
                        }),
                        _buildPill('Hollywood', !_isBollywood, () {
                          if (_isBollywood) setState(() => _isBollywood = false);
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 206,
              child: songsAsync.when(
                data: (songs) {
                  if (songs.isEmpty) {
                    return Center(
                      child: Text(
                        'No songs found.',
                        style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 13),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: songs.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) {
                      if (i == songs.length) {
                        return Container(
                          width: 140,
                          margin: const EdgeInsets.only(left: 4, right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.sentiment_very_satisfied_rounded, color: Colors.white38, size: 36),
                              const SizedBox(height: 12),
                              Text(
                                'Bas kar bhai ab!',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Aage kuch nahi hai',
                                style: GoogleFonts.inter(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }
                      return _SongCard(
                        song: songs[i],
                        playlist: songs,
                        mt: mt,
                        section: _isBollywood ? 'new_releases_bollywood' : 'new_releases_hollywood',
                      );
                    },
                  );
                },
                loading: () => ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, __) => RottyGlowRSkeleton.card(width: 148, height: 206),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Failed to load releases.',
                    style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? widget.mt.accent.withValues(alpha: 0.85) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: active ? Colors.white : widget.mt.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class IndianTopHitsBox extends ConsumerStatefulWidget {
  const IndianTopHitsBox({super.key, required this.mt});
  final ModeTheme mt;

  @override
  ConsumerState<IndianTopHitsBox> createState() => _IndianTopHitsBoxState();
}

class _IndianTopHitsBoxState extends ConsumerState<IndianTopHitsBox> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(indianTopHitsProvider);
    final currentSong = ref.watch(nowPlayingProvider);
    final mt = widget.mt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00D4FF).withValues(alpha: 0.10),
              const Color(0xFF6366F1).withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Indian Top Hits',
                    style: GoogleFonts.outfit(
                      fontSize: (22 * mt.fontScale).toDouble(),
                      fontWeight: FontWeight.w800,
                      color: mt.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '${_currentPage + 1} of 4',
                    style: GoogleFonts.inter(
                      color: mt.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            songsAsync.when(
              data: (songs) {
                if (songs.isEmpty) {
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'No songs found.',
                        style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 13),
                      ),
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 310,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity == null) return;
                          final velocity = details.primaryVelocity!;
                          if (velocity < -150) {
                            if (_currentPage < 3) {
                              _pageController.animateToPage(
                                _currentPage + 1,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          } else if (velocity > 150) {
                            if (_currentPage > 0) {
                              _pageController.animateToPage(
                                _currentPage - 1,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          }
                        },
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (page) => setState(() => _currentPage = page),
                          itemCount: (songs.length / 5).ceil().clamp(0, 4),
                          itemBuilder: (context, pageIndex) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (colIndex) {
                                final songIndex = pageIndex * 5 + colIndex;
                                if (songIndex >= songs.length) return const SizedBox.shrink();
                                final song = songs[songIndex];
                                return _TopHitSongTile(
                                  index: songIndex,
                                  song: song,
                                  isPlaying: currentSong?.id == song.id,
                                  onTap: () async {
                                    await playSongWithContext(ref, song, playlist: songs);
                                    if (context.mounted) context.push('/player');
                                  },
                                  onMore: () => showSongOptionsSheet(context, ref, song),
                                  mt: mt,
                                );
                              }),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final active = _currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? mt.accent : Colors.white24,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 310,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (err, _) => SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'Failed to load charts.',
                    style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandedFooter extends StatelessWidget {
  const BrandedFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: GestureDetector(
          onTap: () async {
            final url = Uri.parse('https://www.instagram.com/kartik.__2357/');
            try {
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            } catch (e) {
              debugPrint('Could not launch Instagram: $e');
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                ),
                children: const [
                  TextSpan(text: 'Made by '),
                  TextSpan(
                    text: 'Kartik',
                    style: TextStyle(
                      color: Color(0xFFFA2D48),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopHitSongTile extends StatelessWidget {
  final int index;
  final SongModel song;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final ModeTheme mt;

  const _TopHitSongTile({
    required this.index,
    required this.song,
    required this.isPlaying,
    required this.onTap,
    required this.onMore,
    required this.mt,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              // Highlighted Rank number
              SizedBox(
                width: 32,
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.outfit(
                    color: isPlaying ? mt.accent : Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              // Poster image
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPlaying ? mt.accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: song.image.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: song.image,
                          fit: BoxFit.cover,
                          memCacheWidth: 96,
                          memCacheHeight: 96,
                          placeholder: (_, __) => Container(color: Colors.white10),
                          errorWidget: (_, __, ___) => const Icon(Icons.music_note_rounded, color: Colors.white38),
                        )
                      : const Icon(Icons.music_note_rounded, color: Colors.white38),
                ),
              ),
              const SizedBox(width: 12),
              // Title and artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.title,
                      style: GoogleFonts.inter(
                        color: isPlaying ? mt.accent : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Play/pause button
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                  color: isPlaying ? mt.accent : Colors.white.withValues(alpha: 0.75),
                  size: 24,
                ),
                onPressed: onTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 4),
              // Three dots
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
                onPressed: onMore,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RottyRefresherSpinner extends StatefulWidget {
  final double progress;
  final bool isRefreshing;
  final Color accentColor;

  const RottyRefresherSpinner({
    super.key,
    required this.progress,
    required this.isRefreshing,
    required this.accentColor,
  });

  @override
  State<RottyRefresherSpinner> createState() => _RottyRefresherSpinnerState();
}

class _RottyRefresherSpinnerState extends State<RottyRefresherSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isRefreshing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(RottyRefresherSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isRefreshing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = widget.isRefreshing
            ? _controller.value * 2 * 3.14159
            : widget.progress * 2 * 3.14159;
        
        return Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: widget.accentColor.withValues(alpha: widget.isRefreshing ? 0.8 : 0.3),
                width: 1.5,
              ),
              boxShadow: [
                if (widget.isRefreshing)
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Transform.rotate(
              angle: angle,
              child: Icon(
                Icons.music_note_rounded,
                color: widget.accentColor,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }
}


