import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/modes/app_mode.dart';
import '../../core/sound/sound_space.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/time_theme.dart';
import '../../providers/providers.dart';
import '../../providers/premium_providers.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart';
import '../../utils/play_song.dart';
import '../../widgets/app_scaffold.dart';
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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        children: [
          Text('Settings', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 20),
          _buildUserProfileCard(context),
          const SizedBox(height: 24),
          if (FirebaseService.instance.isAdmin) ...[
            _header('Admin Tools'),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.cyanAccent),
              title: Text('Admin Control Panel', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text('Manage users, verified badges, broadcast alerts', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
              onTap: () => context.push('/admin'),
            ),
            const Divider(color: AppColors.glassBorder),
          ],
          _header('Account & Support'),
          ListTile(
            leading: const Icon(Icons.volunteer_activism_rounded, color: Colors.pinkAccent),
            title: Text('Support Kartik & Gift ₹99', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('Keep Rotty alive, fast & 100% ad-free forever', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (StorageService().isSupporter)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.pink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text('SUPPORTER 💖', style: GoogleFonts.inter(color: Colors.pinkAccent, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
              ],
            ),
            onTap: () => context.push('/support'), // Open direct to Support/Gift Developer screen
          ),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded, color: Colors.cyanAccent),
            title: Text('Edit Profile Name', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(
              StorageService().profileName.isEmpty ? 'Set your display name' : StorageService().profileName,
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            onTap: _showEditProfileDialog,
          ),
          ListTile(
            leading: const Icon(Icons.sync_rounded, color: Colors.greenAccent),
            title: Text('Cloud Sync Settings', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Builder(
              builder: (context) {
                final customId = StorageService().customSyncId;
                if (customId.isNotEmpty) {
                  return Text('Linked Sync ID: $customId', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12));
                }
                return Text('Local Device (Unlinked)', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12));
              },
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            onTap: _showCloudSyncDialog,
          ),
          const Divider(color: AppColors.glassBorder),
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
            title: Text('Smart Queue Autoplay', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Automatically refill queue with similar songs matching your active taste & session mood when queue ends.',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11),
            ),
            onChanged: (v) => ref.read(aiDjEnabledProvider.notifier).state = v,
          ),
          SwitchListTile(
            value: ref.watch(albumArtRipplesProvider),
            activeThumbColor: AppColors.accent,
            title: Text('Album Art Ripples', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Hardware-accelerated fluid canvas waves',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
            ),
            onChanged: (v) => ref.read(albumArtRipplesProvider.notifier).toggle(v),
          ),
          if (premium)
            ListTile(
              title: Text('Refresh AI queue now', style: GoogleFonts.inter(color: Colors.white)),
              subtitle: Text('Adds new songs after current track', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await refreshAiQueue(ref);
                messenger.showSnackBar(const SnackBar(content: Text('AI queue updated')));
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
          _header('About Rotty'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded, color: Colors.white),
            title: Text('About Rotty', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('Our story, legal safe-harbor disclaimer & open licenses', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            onTap: () => context.push('/about'), // Open direct to About Rotty screen
          ),

          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.accent),
            title: Text('Sign out', style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.w600)),
            onTap: () async {
              await FirebaseService.instance.signOut();
              await StorageService().clearAuthSession();
              if (context.mounted) context.go('/auth');
            },
          ),
        ],
    );

    if (widget.embedded) {
      return SafeArea(
        bottom: false,
        child: content,
      );
    }
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

  void _showEditProfileDialog() {
    final TextEditingController nameCtrl = TextEditingController(text: StorageService().profileName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Edit Profile Name',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aapka display name jo party sync aur profile badges me visible hoga.',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Display Name',
                hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              await StorageService().setProfileName(newName);
              try {
                if (FirebaseService.instance.isReady) {
                  await FirebaseService.instance.updateUserDisplayName(newName);
                }
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCloudSyncDialog() {
    final TextEditingController syncCtrl = TextEditingController(text: StorageService().customSyncId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.sync_rounded, color: Colors.greenAccent),
            const SizedBox(width: 10),
            Text(
              'Cloud Sync Settings',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dono devices (jaise phone aur laptop) ko link karne ke liye yahan same Sync ID (jaise email) enter karein. Isse aapke playlists aur favorites exact sync ho jayenge!',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Active Device UID: ${FirebaseService.instance.userId}',
              style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: syncCtrl,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter Sync ID / Email',
                hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.greenAccent, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await StorageService().setCustomSyncId('');
              try {
                if (FirebaseService.instance.isReady) {
                  await FirebaseService.instance.restoreCloudPlaylists();
                }
              } catch (_) {}
              ref.refresh(playlistsProvider);
              ref.refresh(favoritesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: Text('Unlink / Reset', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newId = syncCtrl.text.trim();
              if (newId.isEmpty) return;
              await StorageService().setCustomSyncId(newId);
              
              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Syncing with cloud playlists...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              
              try {
                if (FirebaseService.instance.isReady) {
                  await FirebaseService.instance.restoreCloudPlaylists();
                  await FirebaseService.instance.syncAllLocalPlaylistsToCloud();
                }
              } catch (_) {}
              
              ref.refresh(playlistsProvider);
              ref.refresh(favoritesProvider);
              
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: Text('Save & Sync', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard(BuildContext context) {
    final isSupporter = StorageService().isSupporter;
    final name = StorageService().profileName.isEmpty ? 'Guest User' : StorageService().profileName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: isSupporter ? [
          BoxShadow(
            color: Colors.pinkAccent.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ] : null,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isSupporter 
                ? const LinearGradient(colors: [Colors.pinkAccent, Colors.purpleAccent])
                : const LinearGradient(colors: [Colors.cyanAccent, Colors.blueAccent]),
              boxShadow: [
                BoxShadow(
                  color: (isSupporter ? Colors.pinkAccent : Colors.cyanAccent).withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSupporter) ...[
                      const SizedBox(width: 8),
                      // Neon Supporter badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.pink.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
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
                const SizedBox(height: 4),
                Text(
                  isSupporter ? 'Thank you for supporting Rotty!' : 'Free Music Listener',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white30, size: 20),
            onPressed: _showEditProfileDialog,
          ),
        ],
      ),
    );
  }
}

