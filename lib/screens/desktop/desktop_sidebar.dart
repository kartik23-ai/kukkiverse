import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/liquid_glass.dart';
import '../../services/storage_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// Desktop Sidebar 5.0 — Restored & Deep Liquid Glass Navigation
/// 240px wide, translucent, light-catching, neon active pill, playlists
/// ═══════════════════════════════════════════════════════════════
class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({super.key, required this.activeTab, required this.onTabChanged});

  final int activeTab;
  final ValueChanged<int> onTabChanged;

  static const _navItems = [
    (Icons.home_rounded, 'Home'),
    (Icons.search_rounded, 'Search'),
    (Icons.library_music_rounded, 'Library'),
    (Icons.science_rounded, 'Labs'),
    (Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider).where((p) => !p.isPrivate).toList();
    final palette = ref.watch(dynamicPaletteProvider);

    return LiquidGlassSidebar(
      width: 240,
      accentColor: palette.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Logo ───
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFA2D48), Color(0xFF7B61FF), Color(0xFF00D4FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 20),
                    ],
                  ),
                  child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFA2D48), Color(0xFF7B61FF), Color(0xFF00D4FF)],
                  ).createShader(bounds),
                  child: Text(
                    'ROTTY',
                    style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      letterSpacing: 3, color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Nav items ───
          ...List.generate(_navItems.length, (i) {
            final selected = activeTab == i;
            return _NavItem(
              icon: _navItems[i].$1,
              label: _navItems[i].$2,
              selected: selected,
              accent: palette.primary,
              onTap: () => onTabChanged(i),
            );
          }),

          // ─── Divider ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.white.withValues(alpha: 0.12), Colors.transparent],
                ),
              ),
            ),
          ),

          // ─── Playlists header ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text(
              'YOUR PLAYLISTS',
              style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.4), letterSpacing: 2,
              ),
            ),
          ),

          // ─── Playlists list ───
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: playlists.length,
              itemBuilder: (context, i) => _PlaylistTile(
                id: playlists[i].id,
                name: playlists[i].name,
                count: playlists[i].songs.length,
                accent: palette.primary,
              ),
            ),
          ),

          // ─── Create playlist button ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: _CreatePlaylistButton(ref: ref, accent: palette.primary),
          ),

          // ─── User Profile Card ───
          _UserProfileCard(accent: palette.primary, onTabChanged: onTabChanged),
        ],
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard({required this.accent, required this.onTabChanged});
  final Color accent;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final isSupporter = StorageService().isSupporter;
    final name = StorageService().profileName.isEmpty ? 'Guest User' : StorageService().profileName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onTabChanged(4), // Settings is index 4
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: isSupporter ? [
                BoxShadow(
                  color: Colors.pinkAccent.withValues(alpha: 0.05),
                  blurRadius: 10,
                )
              ] : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSupporter
                      ? const LinearGradient(colors: [Colors.pinkAccent, Colors.purpleAccent])
                      : LinearGradient(colors: [accent, accent.withValues(alpha: 0.6)]),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSupporter) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: Colors.pinkAccent, size: 12),
                          ],
                        ],
                      ),
                      Text(
                        isSupporter ? 'Supporter 💖' : 'Free Account',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.2), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.accent, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: widget.selected
                  ? widget.accent.withValues(alpha: 0.15)
                  : _hovered
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.transparent,
              border: widget.selected
                  ? Border.all(color: widget.accent.withValues(alpha: 0.25))
                  : null,
              boxShadow: widget.selected
                  ? [BoxShadow(color: widget.accent.withValues(alpha: 0.15), blurRadius: 16)]
                  : const [],
            ),
            child: Row(
              children: [
                // Neon active pill indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 3, height: widget.selected ? 22 : 0,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: widget.accent,
                    boxShadow: widget.selected
                        ? [BoxShadow(color: widget.accent.withValues(alpha: 0.6), blurRadius: 8)]
                        : const [],
                  ),
                ),
                Icon(
                  widget.icon, size: 20,
                  color: widget.selected
                      ? widget.accent
                      : _hovered ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 14),
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                    color: widget.selected
                        ? Colors.white
                        : _hovered ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatefulWidget {
  const _PlaylistTile({required this.id, required this.name, required this.count, required this.accent});
  final String id;
  final String name;
  final int count;
  final Color accent;

  @override
  State<_PlaylistTile> createState() => _PlaylistTileState();
}

class _PlaylistTileState extends State<_PlaylistTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          context.push('/album/${widget.id}');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _hovered ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(Icons.queue_music_rounded, size: 16,
                  color: _hovered ? widget.accent.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.name,
                  style: GoogleFonts.inter(fontSize: 13,
                      color: _hovered ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.5)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${widget.count}', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.25))),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatePlaylistButton extends StatefulWidget {
  const _CreatePlaylistButton({required this.ref, required this.accent});
  final WidgetRef ref;
  final Color accent;

  @override
  State<_CreatePlaylistButton> createState() => _CreatePlaylistButtonState();
}

class _CreatePlaylistButtonState extends State<_CreatePlaylistButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showCreateDialog(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? widget.accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1),
            ),
            color: _hovered ? widget.accent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 18,
                  color: _hovered ? widget.accent : Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Text(
                'Create Playlist',
                style: GoogleFonts.inter(fontSize: 12,
                    color: _hovered ? widget.accent : Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Create Playlist', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: GoogleFonts.inter(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              widget.ref.read(playlistsProvider.notifier).create(v.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38))),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                widget.ref.read(playlistsProvider.notifier).create(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: Text('Create', style: GoogleFonts.inter(color: widget.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
