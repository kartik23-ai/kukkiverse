import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/premium_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/premium_badge.dart';

class LabsHubScreen extends ConsumerWidget {
  const LabsHubScreen({super.key});

  static const _items = [
    _LabItem('ROTTY Aura', 'Full-app live colors', Icons.palette_rounded, '/labs/aura', true),
    _LabItem('Studio Lab', 'EQ • 8D orbit • presets', Icons.tune_rounded, '/labs/studio', true),
    _LabItem('Lyrics Cinema', 'Cinematic lyrics + reel', Icons.movie_rounded, '/cinema', true),
    _LabItem('Time Machine', 'Year + mood stations', Icons.history_edu_rounded, '/labs/time-machine', true),
    _LabItem('Sleep Oracle', 'Fade + ambient layers', Icons.bedtime_rounded, '/labs/sleep', true),
    _LabItem('Infinite Blend', 'Long crossfade mix', Icons.blur_on_rounded, '/labs/blend', true),
    _LabItem('Vault', 'PIN private playlists', Icons.lock_rounded, '/labs/vault', true),
    _LabItem('Mood Shake', 'Shake → surprise song', Icons.vibration_rounded, '/labs/shake', false),
    _LabItem('Vibe Match', 'Same energy queue', Icons.graphic_eq_rounded, '/labs/vibe', false),
    _LabItem('Reverse Discover', 'Teach from skips', Icons.thumb_down_off_alt_rounded, '/labs/reverse', false),
    _LabItem('Focus Lock', 'Pomodoro + music', Icons.timer_rounded, '/labs/focus', false),
    _LabItem('Night Drive', 'Big controls UI', Icons.directions_car_rounded, '/drive', false),
    _LabItem('Concert Mode', 'Visualizer + lyrics', Icons.surround_sound_rounded, '/concert', false),
    _LabItem('Dual Deck', 'Two-deck mix', Icons.album_rounded, '/dj', false),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(rottyPremiumProvider);
    final aura = ref.watch(auraFullAppProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('ROTTY Labs', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                              const SizedBox(width: 8),
                              PremiumBadge(unlocked: premium),
                            ],
                          ),
                          Text('Premium tools • clean & fast', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: aura,
                  activeColor: AppColors.accent,
                  title: Text('Aura full app', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Theme follows album art everywhere', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
                  onChanged: premium
                      ? (v) => ref.read(auraFullAppProvider.notifier).set(v)
                      : (_) => context.push('/premium'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.28,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = _items[i];
                    return _LabCard(
                      item: item,
                      premium: premium,
                      onTap: () {
                        if (item.isPro && !premium) {
                          context.push('/premium');
                          return;
                        }
                        if (item.route == '/labs/aura') {
                          final next = !ref.read(auraFullAppProvider);
                          ref.read(auraFullAppProvider.notifier).set(next);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(next ? 'Aura ON — UI follows album art' : 'Aura OFF')),
                          );
                          return;
                        }
                        if (item.route == '/cinema') {
                          final id = ref.read(nowPlayingProvider)?.id;
                          if (id != null) {
                            context.push('/cinema/$id');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Play a song first for Lyrics Cinema')),
                            );
                          }
                          return;
                        }
                        context.push(item.route);
                      },
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabItem {
  const _LabItem(this.title, this.sub, this.icon, this.route, this.isPro);
  final String title;
  final String sub;
  final IconData icon;
  final String route;
  final bool isPro;
}

class _LabCard extends StatelessWidget {
  const _LabCard({required this.item, required this.premium, required this.onTap});
  final _LabItem item;
  final bool premium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(item.icon, color: AppColors.accent, size: 22),
                  const Spacer(),
                  if (item.isPro) PremiumBadge(small: true, unlocked: premium),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(item.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 10, height: 1.15)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
