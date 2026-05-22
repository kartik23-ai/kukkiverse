import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/premium_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';

class LabsHubScreen extends ConsumerWidget {
  const LabsHubScreen({super.key});

  static const _items = [
    _LabItem('ROTTY Aura', 'Full-app live colors', Icons.palette_rounded, '/labs/aura', false),
    _LabItem('Studio Lab', 'EQ • 8D orbit • presets', Icons.tune_rounded, '/labs/studio', false),
    _LabItem('Lyrics Cinema', 'Cinematic lyrics + reel', Icons.movie_rounded, '/cinema', false),
    _LabItem('Time Machine', 'Year + mood stations', Icons.history_edu_rounded, '/labs/time-machine', false),
    _LabItem('Sleep Oracle', 'Fade + ambient layers', Icons.bedtime_rounded, '/labs/sleep', false),
    _LabItem('Infinite Blend', 'Long crossfade mix', Icons.blur_on_rounded, '/labs/blend', false),
    _LabItem('Party Sync', 'Connect phone & laptop', Icons.celebration_rounded, '/party', false),
    _LabItem('Vault', 'PIN private playlists', Icons.lock_rounded, '/labs/vault', false),
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
    final palette = ref.watch(dynamicPaletteProvider);

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                            onPressed: () => context.pop(),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) => LinearGradient(
                                        colors: [palette.primary, const Color(0xFF7B61FF), const Color(0xFF00D4FF)],
                                      ).createShader(bounds),
                                      child: Text('ROTTY Labs', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                                    ),
                                  ],
                                ),
                                Text('Experimental tools • clean & fast', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
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
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          value: aura,
                          activeColor: palette.primary,
                          activeThumbColor: Colors.white,
                          title: Text('Aura full app', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text('Theme follows album art everywhere', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                          onChanged: (v) => ref.read(auraFullAppProvider.notifier).set(v),
                        ),
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
                        childAspectRatio: 1.35,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final item = _items[i];
                          return _LabCard(
                            item: item,
                            premium: premium,
                            onTap: () {
                              // isPro check bypassed
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
          ),
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

class _LabCard extends ConsumerWidget {
  const _LabCard({required this.item, required this.premium, required this.onTap});
  final _LabItem item;
  final bool premium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(dynamicPaletteProvider);
    final accent = item.isPro ? palette.primary : const Color(0xFF00D4FF);
    final locked = item.isPro && !premium;

    return LiquidGlassCard(
      accentColor: accent,
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: accent.withValues(alpha: 0.15),
                ),
                child: Icon(item.icon, color: accent, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(item.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, height: 1.15)),
            ],
          ),
        ],
      ),
    );
  }
}
