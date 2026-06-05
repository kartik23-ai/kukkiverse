import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/song_model.dart';
import '../../models/playlist_model.dart';
import '../../providers/feature_providers.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../services/firebase_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/play_song.dart';
import '../../widgets/party_disco_lights.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/elite_background.dart';

class PartySyncScreen extends ConsumerStatefulWidget {
  const PartySyncScreen({super.key});

  @override
  ConsumerState<PartySyncScreen> createState() => _PartySyncScreenState();
}

class _PartySyncScreenState extends ConsumerState<PartySyncScreen> {
  late final TextEditingController _joinCtrl;

  @override
  void initState() {
    super.initState();
    _joinCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _joinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final party = ref.watch(partyRoomProvider);
    final playing = ref.watch(isPlayingProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    // Handle kick alerts safely
    ref.listen<PartyRoomState>(partyRoomProvider, (previous, next) {
      if (next.kicked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'You have been removed from the party by the host.',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
        ref.read(partyRoomProvider.notifier).clearKicked();
      }
    });

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
                        ? _hostJoinView(context, palette.primary)
                        : _roomView(context, party, palette.primary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hostJoinView(BuildContext context, Color accent) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
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
                TextField(
                  controller: _joinCtrl,
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
                    final code = _joinCtrl.text.trim().toUpperCase();
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

  Widget _roomView(BuildContext context, PartyRoomState party, Color accent) {
    final isKeyboard = MediaQuery.of(context).viewInsets.bottom > 0;
    final showStats = !isKeyboard && !ref.watch(partySearchActiveProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Visibility(
          visible: showStats,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connected Room Stats Card
              LiquidGlass(
                borderRadius: 22,
                surfaceOpacity: 0.09,
                borderOpacity: 0.18,
                padding: const EdgeInsets.all(20),
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
                    const SizedBox(height: 10),
                    SelectableText(
                      party.code!,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(color: accent.withValues(alpha: 0.4), blurRadius: 15),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.copy_rounded, color: Colors.white70, size: 12),
                                const SizedBox(width: 6),
                                Text('Copy Code', style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Live member list
              StreamBuilder<List<FirebasePartyMember>>(
                stream: SupabaseService.instance.watchPartyMembers(party.code!),
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  if (members.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: LiquidGlass(
                      borderRadius: 18,
                      surfaceOpacity: 0.06,
                      borderOpacity: 0.12,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people_outline_rounded, color: Colors.greenAccent, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'PARTY MEMBERS (${members.length})',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.greenAccent,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: members.map((member) {
                                final isMemberHost = member.uid == party.hostId;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isMemberHost ? Colors.amber : Colors.greenAccent,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          member.name,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (isMemberHost) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '👑',
                                            style: GoogleFonts.inter(fontSize: 10),
                                          ),
                                        ],
                                        if (party.isHost && !isMemberHost) ...[
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () async {
                                              final messenger = ScaffoldMessenger.of(context);
                                              try {
                                                await ref.read(partyRoomProvider.notifier).kickMember(member.uid);
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    backgroundColor: AppColors.bgElevated,
                                                    content: Text('Kicked ${member.name} 🥾', style: const TextStyle(color: Colors.white)),
                                                  ),
                                                );
                                              } catch (e) {
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    backgroundColor: Colors.redAccent,
                                                    content: Text('Failed to kick member: ${e.toString().replaceAll('Exception: ', '')}', style: const TextStyle(color: Colors.white)),
                                                  ),
                                                );
                                              }
                                            },
                                            child: const Icon(
                                              Icons.close_rounded,
                                              color: Colors.redAccent,
                                              size: 13,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),


        // Inline song search bar
        _PartySearchAndAddSection(
          accent: accent,
          onAdd: (song) {
            ref.read(partyRoomProvider.notifier).addSong(song);
          },
        ),
        const SizedBox(height: 20),

        // Shared Queue Label & Playlist Add Action
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Shared Party Queue',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _showPlaylistsSelectorSheet(context, accent),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accent.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.playlist_add_rounded, color: accent, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Add Playlists',
                            style: GoogleFonts.inter(color: accent, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: accent.withValues(alpha: 0.15),
                    ),
                    child: Text(
                      '${party.queue.length} TRACKS',
                      style: GoogleFonts.inter(color: accent, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Queue List (Reorderable for Host, static for Guest)
        Expanded(
          child: party.queue.isEmpty
              ? Center(
                  child: LiquidGlass(
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Text(
                      'Search above or add from playlists to sync music instantly!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, height: 1.4),
                    ),
                  ),
                )
              : party.isHost
                  ? ReorderableListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: party.queue.length,
                      buildDefaultDragHandles: false,
                      onReorder: (oldIndex, newIndex) =>
                          ref.read(partyRoomProvider.notifier).reorderQueue(oldIndex, newIndex),
                      itemBuilder: (context, i) {
                        final s = party.queue[i];
                        final isNowPlaying = party.nowPlaying?.id == s.id;
                        return _buildQueueItem(context, s, i, isNowPlaying, accent, true);
                      },
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: party.queue.length,
                      itemBuilder: (context, i) {
                        final s = party.queue[i];
                        final isNowPlaying = party.nowPlaying?.id == s.id;
                        return _buildQueueItem(context, s, i, isNowPlaying, accent, false);
                      },
                    ),
        ),
        if (!isKeyboard)
          _PartySyncBottomPlayer(party: party, accent: accent),
      ],
    );
  }

  Widget _buildQueueItem(
    BuildContext context,
    SongModel s,
    int index,
    bool isNowPlaying,
    Color accent,
    bool isHost,
  ) {
    return Container(
      key: ValueKey('q_item_${s.id}_$index'),
      margin: const EdgeInsets.only(bottom: 8),
      child: LiquidGlassCard(
        accentColor: isNowPlaying ? accent : Colors.white12,
        borderRadius: 12,
        padding: const EdgeInsets.all(10),
        onTap: () {
          if (isHost) {
            final party = ref.read(partyRoomProvider);
            playSongWithContext(ref, s, playlist: party.queue);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Playback can only be changed by the host 👑'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        child: Row(
          children: [
            if (isHost) ...[
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_indicator_rounded, color: Colors.white24, size: 20),
              ),
              const SizedBox(width: 8),
            ],
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
            if (isHost)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                onPressed: () => ref.read(partyRoomProvider.notifier).removeSong(s),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              Icon(
                isNowPlaying ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                color: isNowPlaying ? accent : Colors.white38,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistsSelectorSheet(BuildContext context, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _PlaylistSelectorBottomSheet(accent: accent);
      },
    );
  }
}

class _PartySearchAndAddSection extends ConsumerStatefulWidget {
  const _PartySearchAndAddSection({required this.accent, required this.onAdd});
  final Color accent;
  final ValueChanged<SongModel> onAdd;

  @override
  ConsumerState<_PartySearchAndAddSection> createState() => _PartySearchAndAddSectionState();
}

class _PartySearchAndAddSectionState extends ConsumerState<_PartySearchAndAddSection> {
  final _searchCtrl = TextEditingController();
  List<SongModel> _results = [];
  bool _searching = false;
  bool _showResults = false;

  void _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _showResults = false;
      });
      ref.read(partySearchActiveProvider.notifier).state = false;
      return;
    }
    setState(() => _searching = true);
    try {
      final songs = await ApiService().searchSongs(query.trim(), limit: 8);
      setState(() {
        _results = songs;
        _showResults = true;
      });
      ref.read(partySearchActiveProvider.notifier).state = true;
    } catch (_) {
    } finally {
      setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboard = MediaQuery.of(context).viewInsets.bottom > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search songs to add to party queue...',
            hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
            prefixIcon: Icon(Icons.search_rounded, color: widget.accent, size: 18),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearch('');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide: BorderSide(color: widget.accent.withValues(alpha: 0.4), width: 1.5),
            ),
          ),
          onChanged: (val) {
            _onSearch(val);
          },
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
          ),
        if (_showResults && _results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: BoxConstraints(maxHeight: isKeyboard ? 140 : 250),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, idx) {
                final s = _results[idx];
                return ListTile(
                  dense: true,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(s.image, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded)),
                  ),
                  title: Text(s.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(s.artist, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded, color: widget.accent, size: 20),
                    onPressed: () {
                      widget.onAdd(s);
                      _searchCtrl.clear();
                      setState(() {
                        _results = [];
                        _showResults = false;
                      });
                      ref.read(partySearchActiveProvider.notifier).state = false;
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _PlaylistSelectorBottomSheet extends ConsumerStatefulWidget {
  const _PlaylistSelectorBottomSheet({required this.accent});
  final Color accent;

  @override
  ConsumerState<_PlaylistSelectorBottomSheet> createState() => _PlaylistSelectorBottomSheetState();
}

class _PlaylistSelectorBottomSheetState extends ConsumerState<_PlaylistSelectorBottomSheet> {
  PlaylistModel? _selectedPlaylist;

  @override
  Widget build(BuildContext context) {
    if (_selectedPlaylist != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  onPressed: () => setState(() => _selectedPlaylist = null),
                ),
                Expanded(
                  child: Text(
                    _selectedPlaylist!.name,
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedPlaylist!.songs.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(partyRoomProvider.notifier).addSongs(_selectedPlaylist!.songs);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added ${_selectedPlaylist!.songs.length} songs to shared queue'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.playlist_add_check_rounded, size: 18, color: Colors.greenAccent),
                    label: Text(
                      'Add All',
                      style: GoogleFonts.inter(color: Colors.greenAccent, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _selectedPlaylist!.songs.isEmpty
                  ? Center(child: Text('No songs in this playlist', style: GoogleFonts.inter(color: Colors.white30, fontSize: 12)))
                  : ListView.separated(
                      itemCount: _selectedPlaylist!.songs.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, idx) {
                        final s = _selectedPlaylist!.songs[idx];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(s.image, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded)),
                          ),
                          title: Text(s.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(s.artist, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: Icon(Icons.add_circle_outline_rounded, color: widget.accent, size: 20),
                            onPressed: () {
                              ref.read(partyRoomProvider.notifier).addSong(s);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "${s.title}" to shared queue'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    }

    final playlists = ref.watch(playlistsProvider).where((p) => !p.isPrivate).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select Playlist',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: playlists.isEmpty
                ? Center(child: Text('No playlists found', style: GoogleFonts.inter(color: Colors.white30, fontSize: 13)))
                : ListView.separated(
                    itemCount: playlists.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final p = playlists[idx];
                      return ListTile(
                        dense: true,
                        tileColor: Colors.white.withValues(alpha: 0.03),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: widget.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.queue_music_rounded, color: widget.accent),
                        ),
                        title: Text(p.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${p.songs.length} songs', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
                        onTap: () => setState(() => _selectedPlaylist = p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PartySyncBottomPlayer extends ConsumerWidget {
  const _PartySyncBottomPlayer({required this.party, required this.accent});
  final PartyRoomState party;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = party.nowPlaying;
    if (song == null) return const SizedBox.shrink();

    final playing = ref.watch(isPlayingProvider);
    final handler = ref.read(audioHandlerProvider);

    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 8),
      child: LiquidGlass(
        borderRadius: 20,
        surfaceOpacity: 0.12,
        borderOpacity: 0.22,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        glowColor: accent,
        glowIntensity: 0.15,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    song.image,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: Colors.white10,
                      child: const Icon(Icons.music_note_rounded, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (party.isHost) ...[
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 24),
                    onPressed: () {
                      handler.skipToPrevious();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: [
                        BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 10),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        if (playing) {
                          handler.pause();
                        } else {
                          handler.play();
                        }
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
                    onPressed: () {
                      handler.skipToNext();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_tethering_rounded, color: Colors.greenAccent, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'SYNCED',
                          style: GoogleFonts.inter(
                            color: Colors.greenAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Progress Bar
            StreamBuilder<Duration>(
              stream: handler.player.positionStream,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = handler.player.duration ?? song.duration;
                final pct = dur.inMilliseconds > 0
                    ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                    : 0.0;
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _fmt(pos),
                          style: GoogleFonts.inter(color: Colors.white30, fontSize: 10),
                        ),
                        Text(
                          _fmt(dur),
                          style: GoogleFonts.inter(color: Colors.white30, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
