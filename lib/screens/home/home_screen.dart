import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/mode_theme.dart';
import '../../core/modes/app_mode.dart';
import '../../providers/providers.dart';
import '../../models/song_model.dart';
import '../../widgets/app_scaffold.dart';
import '../../utils/greeting.dart';
import '../../utils/play_song.dart';
import '../../widgets/flashback_tile.dart';
import '../../widgets/streak_chip.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/song_options_sheet.dart';
import '../../providers/premium_providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/neon_skeleton.dart';
import '../../widgets/crystal_shatter_skeleton.dart';
import '../../widgets/magnetic_playlist_drop.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeDataProvider);
    final recent = ref.watch(recentSongsProvider);
    final aiOn = ref.watch(aiDjEnabledProvider);
    final premium = ref.watch(rottyPremiumProvider);
    final mode = ref.watch(appModeProvider);
    final mt = ModeTheme(mode);

    return AppScaffold(
      bottomPadding: 8,
      body: home.when(
        data: (sections) {
          if (sections.isEmpty) return _emptyState(ref, mt);
          return CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _header(context, ref, premium, mt, mode)),
              // Focus mode: timer at top
              if (mode == RottyAppMode.focus)
                SliverToBoxAdapter(child: _focusTimer(context, ref, mt)),
              if (mt.showQuickActions)
                SliverToBoxAdapter(child: _searchBar(context, ref, mt)),
              if (mt.showQuickActions)
                SliverToBoxAdapter(child: _quickActions(context, ref, mt)),
              if (mt.showExtras)
                SliverToBoxAdapter(child: _aiRow(context, ref, aiOn, premium, mt)),
              if (mt.showDecorations) const SliverToBoxAdapter(child: StreakChip()),
              if (mt.showDecorations) const SliverToBoxAdapter(child: FlashbackTile()),
              if (mt.showExtras)
                SliverToBoxAdapter(child: _labsEntry(context, mt)),
              if (recent.isNotEmpty)
                _sectionSliver(context, ref, 'Continue Listening', recent.take(10).toList(), mt),
              ...sections.entries.map((e) => _sectionSliver(context, ref, e.key, e.value, mt)),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
        loading: () => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(context, ref, premium, mt, mode)),
            SliverToBoxAdapter(child: _shimmer(mt)),
          ],
        ),
        error: (_, __) => _emptyState(ref, mt, error: true),
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, bool premium, ModeTheme mt, RottyAppMode mode) {
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
              gradient: mt.accentGradient,
              boxShadow: [
                BoxShadow(color: mt.accent.withValues(alpha: 0.3), blurRadius: 12),
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
                    Text(getTimeGreeting(), style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 13)),
                    if (mt.showDecorations) ...[
                      const SizedBox(width: 8),
                      PremiumBadge(small: true, unlocked: premium),
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
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(item.$3),
              child: Container(
                width: 88,
                decoration: BoxDecoration(
                  color: mt.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(color: item.$4.withValues(alpha: 0.1), blurRadius: 12, spreadRadius: -4),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.$2, color: item.$4, size: 26),
                    const SizedBox(height: 6),
                    Text(item.$1, style: GoogleFonts.inter(color: mt.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
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
                  Text(premium ? 'Smart queue from your vibe' : 'Unlock PRO for AI DJ',
                      style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Switch.adaptive(
              value: premium && aiOn,
              activeColor: mt.accent,
              onChanged: premium ? (v) => ref.read(aiDjEnabledProvider.notifier).state = v : (_) => context.push('/premium'),
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

  Widget _sectionSliver(BuildContext context, WidgetRef ref, String title, List<SongModel> songs, ModeTheme mt) {
    return SliverToBoxAdapter(
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
              itemBuilder: (context, i) => _SongCard(song: songs[i], playlist: songs, mt: mt),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(WidgetRef ref, ModeTheme mt, {bool error = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(error ? Icons.wifi_off_rounded : Icons.music_off_rounded, size: 48, color: mt.textSecondary),
            const SizedBox(height: 16),
            Text(error ? 'Could not load music' : 'No songs found', style: GoogleFonts.inter(color: mt.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Check internet and try again', style: GoogleFonts.inter(color: mt.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => ref.invalidate(homeDataProvider),
              style: FilledButton.styleFrom(backgroundColor: mt.accent),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmer(ModeTheme mt) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: const [
          CrystalShatterSkeleton(height: 180),
          SizedBox(height: 16),
          CrystalShatterSkeleton(height: 120),
        ],
      ),
    );
  }
}

class _SongCard extends ConsumerWidget {
  const _SongCard({required this.song, required this.playlist, required this.mt});
  final SongModel song;
  final List<SongModel> playlist;
  final ModeTheme mt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        onLongPress: () => showMagneticPlaylistDrop(context, ref, song),
        child: SizedBox(
          width: 148,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'album_art_${song.id}',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    // 1px inner glass edge-light
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                    // Colored glow shadow
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
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Glassmorphic title container
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
