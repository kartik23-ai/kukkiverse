import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../playlist/playlist_screen.dart';
import '../settings/settings_screen.dart';
import 'desktop_sidebar.dart';
import 'desktop_player_bar.dart';
import 'desktop_home.dart';
import 'desktop_search.dart';
import 'desktop_now_playing.dart';

/// ═══════════════════════════════════════════════════════════════
/// Desktop Shell — Main scaffold for Windows/wide screens
/// Layout: [Sidebar 230px] [Content flex] [Now Playing 300px]
/// Bottom: [Player Bar 82px]
/// ═══════════════════════════════════════════════════════════════
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _tab = 0;
  bool _showNowPlaying = true;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Keyboard shortcuts
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final handler = ref.read(audioHandlerProvider);

    // Space = play/pause
    if (event.logicalKey == LogicalKeyboardKey.space) {
      handler.player.playing ? handler.pause() : handler.play();
      return KeyEventResult.handled;
    }
    // Right arrow = seek forward 5s
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final pos = handler.player.position;
      handler.player.seek(pos + const Duration(seconds: 5));
      return KeyEventResult.handled;
    }
    // Left arrow = seek back 5s
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final pos = handler.player.position;
      handler.player.seek(pos - const Duration(seconds: 5));
      return KeyEventResult.handled;
    }
    // Ctrl+Right = next track
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      handler.skipToNext();
      return KeyEventResult.handled;
    }
    // Ctrl+Left = prev track
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      handler.skipToPrevious();
      return KeyEventResult.handled;
    }
    // N = toggle now playing panel
    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      setState(() => _showNowPlaying = !_showNowPlaying);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            // Main area
            Expanded(
              child: Row(
                children: [
                  // Left sidebar
                  DesktopSidebar(
                    activeTab: _tab,
                    onTabChanged: (i) => setState(() => _tab = i),
                  ),

                  // Center content
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF0F0F18),
                            AppColors.bg,
                          ],
                          stops: const [0.0, 0.3],
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: switch (_tab) {
                          0 => const DesktopHome(key: ValueKey('d_home')),
                          1 => const DesktopSearch(key: ValueKey('d_search')),
                          2 => const PlaylistScreen(key: ValueKey('d_lib')),
                          _ => const SettingsScreen(key: ValueKey('d_set'), embedded: true),
                        },
                      ),
                    ),
                  ),

                  // Right panel (now playing)
                  if (_showNowPlaying)
                    const DesktopNowPlaying(),
                ],
              ),
            ),

            // Bottom play bar
            const DesktopPlayerBar(),
          ],
        ),
      ),
    );
  }
}
