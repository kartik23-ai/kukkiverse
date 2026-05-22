import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/modes/app_mode.dart';
import '../../core/sound/sound_space.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/time_theme.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/premium_providers.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart';
import '../../utils/play_song.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/rotty_glass.dart';
import '../../widgets/eq_mesh_visualizer.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _quality = '320kbps';

  @override
  void initState() {
    super.initState();
    _quality = StorageService().audioQuality;
  }

  @override
  Widget build(BuildContext context) {
    final aiOn = ref.watch(aiDjEnabledProvider);
    final mode = ref.watch(appModeProvider);
    final sound = ref.watch(soundSpaceProvider);
    final premium = ref.watch(rottyPremiumProvider);

    final content = ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text('Settings', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 20),
          _header('Ambient Mode'),
          Builder(builder: (context) {
            final tt = ref.watch(timeThemeProvider);
            return Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [tt.bgSurface, tt.bgDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: tt.glassEdge, width: 1),
                boxShadow: [
                  BoxShadow(color: tt.accentGlow.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: -4),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: tt.auroraColors),
                    ),
                    child: Icon(
                      switch (tt.phase) {
                        DayPhase.morning => Icons.wb_sunny_rounded,
                        DayPhase.noon => Icons.light_mode_rounded,
                        DayPhase.evening => Icons.wb_twilight_rounded,
                        DayPhase.night => Icons.nightlight_round,
                      },
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tt.label.toUpperCase(), style: GoogleFonts.inter(
                          color: tt.textPrimary, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1.2,
                        )),
                        const SizedBox(height: 2),
                        Text('Auto-synced to your local time', style: GoogleFonts.inter(
                          color: tt.textSecondary, fontSize: 11,
                        )),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tt.accentGlow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('LIVE', style: GoogleFonts.inter(
                      color: tt.accentGlow, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1,
                    )),
                  ),
                ],
              ),
            );
          }),
          _header('Experience Modes'),
          _modeCard(
            context, ref,
            mode: RottyAppMode.normal,
            currentMode: mode,
            icon: Icons.music_note_rounded,
            color: AppColors.accent,
            desc: 'Full ROTTY experience — all features enabled',
          ),
          const SizedBox(height: 10),
          _modeCard(
            context, ref,
            mode: RottyAppMode.drive,
            currentMode: mode,
            icon: Icons.speed_rounded,
            color: const Color(0xFFFF6B4A),
            desc: 'Landscape HUD • Gesture-only controls • Speedometer ring',
            route: '/drive',
          ),
          const SizedBox(height: 10),
          _modeCard(
            context, ref,
            mode: RottyAppMode.focus,
            currentMode: mode,
            icon: Icons.self_improvement_rounded,
            color: const Color(0xFFE0E0E0),
            desc: 'Monochrome brutalist UI • Pomodoro timer • No distractions',
            route: '/focus',
          ),
          const SizedBox(height: 10),
          _modeCard(
            context, ref,
            mode: RottyAppMode.sleep,
            currentMode: mode,
            icon: Icons.bedtime_rounded,
            color: const Color(0xFF7B61FF),
            desc: 'Pitch black dreamscape • Smart volume fade • Nebula cloud',
            route: '/sleep',
          ),
          const Divider(color: AppColors.glassBorder),
          _header('Sound Spaces'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: SoundSpace.values.map((s) {
                final selected = sound == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s.label, style: GoogleFonts.inter(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 12)),
                    selected: selected,
                    selectedColor: AppColors.accent,
                    onSelected: (_) => ref.read(soundSpaceProvider.notifier).set(s),
                  ),
                );
              }).toList(),
            ),
          ),
          // ─── 3D EQ Mesh Visualizer ───
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                color: Colors.black.withValues(alpha: 0.3),
              ),
              child: Builder(
                builder: (context) {
                  final eq = ref.watch(studioEqProvider);
                  return EqMeshVisualizer(
                    bass: eq.bass,
                    treble: eq.treble,
                    vocal: eq.vocal,
                    width: eq.width,
                    is8d: eq.orbit8d,
                    height: 160,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          RottyGlass(
            padding: const EdgeInsets.all(12),
            child: Text('Bass Boost & 8D apply live to playback via hardware EQ', style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11)),
          ),
          const Divider(color: AppColors.glassBorder),
          _header('Playback'),
          SwitchListTile(
            value: aiOn,
            activeThumbColor: AppColors.accent,
            title: Text('ROTTY AI DJ', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Smart queue with mood-aware picks',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
            ),
            onChanged: (v) => ref.read(aiDjEnabledProvider.notifier).state = v,
          ),
          if (premium)
            ListTile(
              title: Text('Refresh AI queue now', style: GoogleFonts.inter(color: Colors.white)),
              subtitle: Text('Adds new songs after current track', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
              onTap: () async {
                await refreshAiQueue(ref);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI queue updated')));
              },
            ),
          ListTile(
            title: Text('Audio quality', style: GoogleFonts.inter(color: Colors.white)),
            subtitle: Text(_quality, style: GoogleFonts.inter(color: AppColors.textSecondary)),
            onTap: _pickQuality,
          ),
          const Divider(color: AppColors.glassBorder),
          ListTile(
            leading: const Icon(Icons.science_rounded, color: AppColors.accent),
            title: Text('ROTTY Labs', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('Experimental playback tools & secret vault', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            onTap: () => context.push('/labs'),
          ),
          const Divider(color: AppColors.glassBorder),
          _header('Discover'),
          ListTile(
            title: Text('Weekly Wrapped', style: GoogleFonts.inter(color: Colors.white)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            onTap: () => context.push('/wrapped'),
          ),
          ListTile(
            title: Text('Party Sync', style: GoogleFonts.inter(color: Colors.white)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            onTap: () => context.push('/party'),
          ),
          ListTile(
            title: Text('Dual Deck DJ', style: GoogleFonts.inter(color: Colors.white)),
            onTap: () => context.push('/dj'),
          ),
          const Divider(color: AppColors.glassBorder),
          _header('Account'),
          ListTile(
            title: Text('Sign out', style: GoogleFonts.inter(color: AppColors.accent)),
            onTap: () async {
              await FirebaseService.instance.signOut();
              await StorageService().clearAuthSession();
              if (context.mounted) context.go('/auth');
            },
          ),
        ],
    );

    if (widget.embedded) return content;
    return AppScaffold(body: content);
  }



  Widget _header(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t.toUpperCase(), style: GoogleFonts.inter(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
      );

  Future<void> _pickQuality() async {
    final q = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['320kbps', '160kbps', '96kbps'].map((e) {
            return ListTile(
              title: Text(e, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, e),
            );
          }).toList(),
        ),
      ),
    );
    if (q != null) {
      await StorageService().setAudioQuality(q);
      ref.read(musicRepositoryProvider).updateAudioQuality(q);
      setState(() => _quality = q);
    }
  }

  Widget _modeCard(
    BuildContext context,
    WidgetRef ref, {
    required RottyAppMode mode,
    required RottyAppMode currentMode,
    required IconData icon,
    required Color color,
    required String desc,
    String? route,
  }) {
    final isActive = currentMode == mode;
    return GestureDetector(
      onTap: () {
        ref.read(appModeProvider.notifier).set(mode);
        // Navigate to mode screen if it has one
        if (route != null && mode != RottyAppMode.normal) {
          context.push(route);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isActive
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -4)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: color.withValues(alpha: isActive ? 0.5 : 0.15)),
              ),
              child: Icon(icon, color: isActive ? color : Colors.white54, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        mode.label.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: isActive ? color : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('ACTIVE', style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            if (route != null)
              Icon(Icons.chevron_right_rounded, color: isActive ? color : Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

}
