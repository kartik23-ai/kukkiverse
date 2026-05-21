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
import '../../widgets/liquid_glass.dart';
import '../../widgets/elite_background.dart';

class PartySyncScreen extends ConsumerWidget {
  const PartySyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final party = ref.watch(partyRoomProvider);
    final playing = ref.watch(isPlayingProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Party Sync',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 20),
          ),
          actions: [
            if (party.code != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  onPressed: () => ref.read(partyRoomProvider.notifier).leaveRoom(),
                  icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
                  label: Text(
                    'Leave',
                    style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            PartyDiscoLights(active: playing || party.code != null, accent: palette.primary),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: party.code == null
                        ? _hostJoinView(context, ref, palette.primary)
                        : _roomView(context, ref, party, palette.primary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hostJoinView(BuildContext context, WidgetRef ref, Color accent) {
    final joinCtrl = TextEditingController();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          // Heading Info
          Text(
            'CONNECT YOUR DEVICES',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sync queues in real-time between your phone and laptop.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 32),

          // Host Section Card
          LiquidGlass(
            borderRadius: 20,
            surfaceOpacity: 0.08,
            borderOpacity: 0.15,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.celebration_rounded, color: accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Host a Room',
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          Text(
                            'Generate a code and stream together',
                            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                LiquidGlassButton(
                  accentColor: accent,
                  isActive: true,
                  onTap: () async {
                    final code = await ref.read(partyRoomProvider.notifier).createRoom();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.bgElevated,
                          content: Text('Party session started • Code $code', style: const TextStyle(color: Colors.white)),
                        ),
                      );
                    }
                  },
                  child: Center(
                    child: Text(
                      'START HOSTING',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white, letterSpacing: 1.0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Join Section Card
          LiquidGlass(
            borderRadius: 20,
            surfaceOpacity: 0.08,
            borderOpacity: 0.15,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sensors_rounded, color: Colors.cyan, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join Room',
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          Text(
                            'Enter your host\'s code to link controls',
                            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Premium Styled Input Box
                TextField(
                  controller: joinCtrl,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'ENTER CODE (e.g. ROTTY-12345)',
                    hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.03),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.cyan.withValues(alpha: 0.4), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LiquidGlassButton(
                  accentColor: Colors.cyan,
                  onTap: () async {
                    final code = joinCtrl.text.trim().toUpperCase();
                    if (code.isEmpty) return;
                    try {
                      await ref.read(partyRoomProvider.notifier).joinRoom(code);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.bgElevated,
                            content: Text('Connected to party room $code', style: const TextStyle(color: Colors.white)),
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.redAccent,
                            content: Text('Room not found — double check the code', style: TextStyle(color: Colors.white)),
                          ),
                        );
                      }
                    }
                  },
                  child: Center(
                    child: Text(
                      'CONNECT SESSION',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white, letterSpacing: 1.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomView(BuildContext context, WidgetRef ref, PartyRoomState party, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Connected Room Stats Card
        LiquidGlass(
          borderRadius: 22,
          surfaceOpacity: 0.09,
          borderOpacity: 0.18,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_tethering_rounded, color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'CONNECTED & SYNCED',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.greenAccent,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                party.code!,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(color: accent.withValues(alpha: 0.4), blurRadius: 15),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter this code on other devices to control playback and sync the queue together in real time.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: party.code!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.bgElevated,
                          content: Text('Room code copied to clipboard', style: TextStyle(color: Colors.white)),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Text('Copy Code', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Shared Queue Label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shared Party Queue',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: accent.withValues(alpha: 0.15),
                ),
                child: Text(
                  '${party.queue.length} TRACKS',
                  style: GoogleFonts.inter(color: accent, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Queue List
        Expanded(
          child: party.queue.isEmpty
              ? Center(
                  child: LiquidGlass(
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Text(
                      'Play any song in the app — it will stream here for both devices instantly!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, height: 1.4),
                    ),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: party.queue.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = party.queue[i];
                    final isNowPlaying = party.nowPlaying?.id == s.id;
                    return LiquidGlassCard(
                      accentColor: isNowPlaying ? accent : Colors.white12,
                      borderRadius: 12,
                      padding: const EdgeInsets.all(10),
                      onTap: () => playSongWithContext(ref, s, playlist: party.queue),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              s.image,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 44,
                                height: 44,
                                color: Colors.white10,
                                child: const Icon(Icons.music_note_rounded, color: Colors.white54),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.title,
                                  style: GoogleFonts.inter(
                                    color: isNowPlaying ? accent : Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.artist,
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isNowPlaying) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'LIVE SYNC',
                                style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            isNowPlaying ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                            color: isNowPlaying ? accent : Colors.white38,
                            size: 20,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
