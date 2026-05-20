import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/feature_providers.dart';
import '../../providers/providers.dart';
import '../../utils/play_song.dart';
import '../../widgets/party_disco_lights.dart';
import '../../widgets/rotty_glass.dart';

class PartySyncScreen extends ConsumerWidget {
  const PartySyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final party = ref.watch(partyRoomProvider);
    final playing = ref.watch(isPlayingProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PartyDiscoLights(active: playing || party.code != null, accent: palette.primary),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => context.pop()),
                      Expanded(
                        child: Text('Party Sync', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
                      ),
                      if (party.code != null)
                        TextButton(
                          onPressed: () => ref.read(partyRoomProvider.notifier).leaveRoom(),
                          child: Text('Leave', style: GoogleFonts.inter(color: AppColors.accent)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Cloud queue • Share code • Live disco lights',
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: party.code == null ? _hostJoin(context, ref) : _roomView(context, ref, party),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hostJoin(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () async {
            final code = await ref.read(partyRoomProvider.notifier).createRoom();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Party live • Code $code')));
            }
          },
          icon: const Icon(Icons.celebration_rounded),
          label: const Text('Host Party'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size.fromHeight(54)),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: () => _joinDialog(context, ref),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Join with code'),
        ),
      ],
    );
  }

  Widget _roomView(BuildContext context, WidgetRef ref, PartyRoomState party) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RottyGlass(
          tint: AppColors.accent,
          child: Column(
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 88, color: AppColors.accent),
              const SizedBox(height: 8),
              SelectableText(
                party.code!,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Text('Friends enter this code to sync queue', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: party.code!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                },
                child: const Text('Copy code'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Shared queue (${party.queue.length})', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 8),
        Expanded(
          child: party.queue.isEmpty
              ? Center(child: Text('Play songs — they appear here for everyone', style: GoogleFonts.inter(color: AppColors.textTertiary)))
              : ListView.separated(
                  itemCount: party.queue.length,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.glassBorder, height: 1),
                  itemBuilder: (_, i) {
                    final s = party.queue[i];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(s.image, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note)),
                      ),
                      title: Text(s.title, style: GoogleFonts.inter(color: Colors.white)),
                      subtitle: Text(s.artist, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow_rounded, color: AppColors.accent),
                        onPressed: () => playSongWithContext(ref, s, playlist: party.queue),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _joinDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('Join party', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'ROTTY-12345', hintStyle: TextStyle(color: Colors.white38)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase()), child: const Text('Join')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      await ref.read(partyRoomProvider.notifier).joinRoom(code);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined $code')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room not found — check code')));
      }
    }
  }
}
