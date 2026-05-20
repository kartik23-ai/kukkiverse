import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/rotty_glass.dart';

/// ═══════════════════════════════════════════════════════════════
/// Desktop Sidebar — Glassmorphic left navigation panel
/// Spotify-style: Logo, Nav items, Playlists
/// ═══════════════════════════════════════════════════════════════
class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({super.key, required this.activeTab, required this.onTabChanged});

  final int activeTab;
  final ValueChanged<int> onTabChanged;

  static const _navItems = [
    (Icons.home_rounded, 'Home'),
    (Icons.search_rounded, 'Search'),
    (Icons.library_music_rounded, 'Library'),
    (Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0F).withValues(alpha: 0.95),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: AppColors.accentGradient,
                    boxShadow: [
                      BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'ROTTY',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Nav items
          ...List.generate(_navItems.length, (i) {
            final selected = activeTab == i;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => onTabChanged(i),
                  borderRadius: BorderRadius.circular(10),
                  hoverColor: Colors.white.withValues(alpha: 0.05),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: selected
                          ? palette.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _navItems[i].$1,
                          size: 20,
                          color: selected ? palette.primary : Colors.white54,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          _navItems[i].$2,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                            color: selected ? Colors.white : Colors.white60,
                          ),
                        ),
                        if (selected) ...[
                          const Spacer(),
                          Container(
                            width: 4, height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: palette.primary,
                              boxShadow: [BoxShadow(color: palette.primary.withValues(alpha: 0.5), blurRadius: 6)],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          ),

          // Playlists header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text(
              'YOUR PLAYLISTS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white30,
                letterSpacing: 2,
              ),
            ),
          ),

          // Playlists list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: playlists.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: Colors.white.withValues(alpha: 0.04),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.queue_music_rounded, size: 16, color: Colors.white30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              playlists[i].name,
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${playlists[i].songs.length}',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white24),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Create playlist button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => _showCreatePlaylist(context, ref),
                borderRadius: BorderRadius.circular(10),
                hoverColor: Colors.white.withValues(alpha: 0.05),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded, size: 18, color: Colors.white38),
                      const SizedBox(width: 8),
                      Text(
                        'Create Playlist',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylist(BuildContext context, WidgetRef ref) {
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
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              ref.read(playlistsProvider.notifier).create(v.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref.read(playlistsProvider.notifier).create(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: Text('Create', style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
