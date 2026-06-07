import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audio_service/audio_service.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/liquid_glass.dart';

/// ═══════════════════════════════════════════════════════════════
/// Desktop Player Bar 4.0 — Liquid Glass Bottom Bar
/// Frosted translucent, glowing controls, draggable progress,
/// volume, queue, lyrics, fullscreen — all visible and clickable
/// ═══════════════════════════════════════════════════════════════
class DesktopPlayerBar extends ConsumerWidget {
  const DesktopPlayerBar({super.key, this.onToggleFullScreen, this.onToggleNowPlaying});
  final VoidCallback? onToggleFullScreen;
  final VoidCallback? onToggleNowPlaying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(nowPlayingProvider);
    final playing = ref.watch(isPlayingProvider);
    final handler = ref.read(audioHandlerProvider);
    final palette = ref.watch(dynamicPaletteProvider);
    final party = ref.watch(partyRoomProvider);

    if (song == null) {
      return const SizedBox.shrink();
    }

    final songColor = palette.primary;
    final tintColor = Color.alphaBlend(
      songColor.withValues(alpha: 0.04),
      Colors.white.withValues(alpha: 0.015),
    );

    return Container(
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: songColor.withValues(alpha: 0.02),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.04),
                  tintColor,
                  Colors.white.withValues(alpha: 0.015),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: const GlassRefractionPainter(borderRadius: 20),
                  ),
                ),
                Column(
                  children: [
                    // ─── Draggable seek bar ───
          _SeekBar(handler: handler, song: song, palette: palette, enabled: party.code == null || party.isHost),
          // ─── Main controls ───
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // LEFT: Art + Info
                  _SongInfo(song: song, palette: palette),
                  // Favorite
                  Consumer(
                    builder: (context, ref, _) {
                      final isFav = ref.watch(favoritesProvider.select((f) => f.any((s) => s.id == song.id)));
                      return _HoverIcon(
                        icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? palette.primary : Colors.white.withValues(alpha: 0.35),
                        hoverColor: palette.primary,
                        tooltip: isFav ? 'Unlike' : 'Like',
                        onTap: () => ref.read(favoritesProvider.notifier).toggle(song),
                      );
                    },
                  ),
                  // Download
                  Consumer(
                    builder: (context, ref, _) {
                      final downloadState = ref.watch(
                        downloadNotifierProvider.select((states) => states[song.id] ?? const DownloadState.none()),
                      );
                      
                      Color iconColor = Colors.white.withValues(alpha: 0.35);
                      IconData iconData = Icons.download_for_offline_outlined;
                      String tooltip = 'Download for offline';
                      VoidCallback onTap = () => ref.read(downloadServiceProvider).downloadSong(song);

                      if (downloadState.status == DownloadStatus.downloading) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              value: downloadState.progress,
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                              backgroundColor: Colors.white10,
                            ),
                          ),
                        );
                      } else if (downloadState.status == DownloadStatus.downloaded) {
                        iconColor = Colors.green;
                        iconData = Icons.download_done_rounded;
                        tooltip = 'Downloaded. Click to delete.';
                        onTap = () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.black87,
                              title: const Text('Delete Download', style: TextStyle(color: Colors.white)),
                              content: Text('Do you want to delete "${song.title}" from offline storage?', style: const TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.white30)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref.read(downloadServiceProvider).deleteSong(song.id);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        };
                      } else if (downloadState.status == DownloadStatus.failed) {
                        iconColor = Colors.redAccent;
                        iconData = Icons.error_outline_rounded;
                        tooltip = 'Download failed. Click to retry.';
                      }

                      return _HoverIcon(
                        icon: iconData,
                        color: iconColor,
                        hoverColor: palette.primary,
                        tooltip: tooltip,
                        onTap: onTap,
                      );
                    },
                  ),

                  const Spacer(),

                  // CENTER: Transport controls
                  if (party.code != null && !party.isHost) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.greenAccent.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_tethering_rounded, color: Colors.greenAccent, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'PARTY SYNCED WITH HOST 👑',
                            style: GoogleFonts.inter(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    StreamBuilder<PlaybackState>(
                      stream: handler.playbackState,
                      builder: (context, snapshot) {
                        final state = snapshot.data;
                        final shuffleOn = state?.shuffleMode == AudioServiceShuffleMode.all;
                        final repeatMode = state?.repeatMode ?? AudioServiceRepeatMode.none;

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HoverIcon(
                              icon: Icons.shuffle_rounded,
                              color: shuffleOn ? palette.primary : Colors.white.withValues(alpha: 0.35),
                              hoverColor: palette.primary,
                              tooltip: 'Shuffle',
                              onTap: () => handler.setShuffleMode(shuffleOn ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all),
                            ),
                            const SizedBox(width: 14),
                            _HoverIcon(icon: Icons.skip_previous_rounded, color: Colors.white.withValues(alpha: 0.7), hoverColor: Colors.white, tooltip: 'Previous', size: 28, onTap: () => handler.skipToPrevious()),
                            const SizedBox(width: 10),
                            _PlayButton(playing: playing, palette: palette, onTap: () => playing ? handler.pause() : handler.play()),
                            const SizedBox(width: 10),
                            _HoverIcon(icon: Icons.skip_next_rounded, color: Colors.white.withValues(alpha: 0.7), hoverColor: Colors.white, tooltip: 'Next', size: 28, onTap: () => handler.skipToNext()),
                            const SizedBox(width: 14),
                            _HoverIcon(
                              icon: repeatMode == AudioServiceRepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                              color: repeatMode != AudioServiceRepeatMode.none ? palette.primary : Colors.white.withValues(alpha: 0.35),
                              hoverColor: palette.primary,
                              tooltip: 'Repeat',
                              onTap: () async {
                                await handler.setRepeatMode(
                                  repeatMode == AudioServiceRepeatMode.none
                                      ? AudioServiceRepeatMode.all
                                      : (repeatMode == AudioServiceRepeatMode.all
                                          ? AudioServiceRepeatMode.one
                                          : AudioServiceRepeatMode.none),
                                );
                              },
                            ),
                          ],
                        );
                      }
                    ),
                  ],

                  const Spacer(),

                  // RIGHT: Time + Queue + Fullscreen + Volume
                  StreamBuilder<Duration>(
                    stream: handler.player.positionStream,
                    builder: (context, snap) {
                      final pos = snap.data ?? Duration.zero;
                      final dur = handler.player.duration ?? song.duration;
                      return Text(
                        '${_fmt(pos)} / ${_fmt(dur)}',
                        style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.white.withValues(alpha: 0.35),
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _HoverIcon(icon: Icons.queue_music_rounded, color: Colors.white.withValues(alpha: 0.35), hoverColor: palette.primary, tooltip: 'Now Playing', onTap: onToggleNowPlaying ?? () {}),
                  _HoverIcon(icon: Icons.open_in_full_rounded, color: Colors.white.withValues(alpha: 0.35), hoverColor: palette.primary, tooltip: 'Full Screen', onTap: onToggleFullScreen ?? () {}),
                  const SizedBox(width: 8),
                  _VolumeControl(handler: handler, palette: palette),
                ],
              ),
            ),
          ),
                  ],
                ),
              ],
            ),
          ),
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

/// ─── Seek Bar ───
class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.handler, required this.song, required this.palette, this.enabled = true});
  final dynamic handler, song, palette;
  final bool enabled;
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  bool _hovered = false;
  bool _dragging = false;
  double? _dragRatio;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = widget.enabled),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          return GestureDetector(
            onHorizontalDragStart: widget.enabled ? (d) {
              setState(() => _dragging = true);
              _doSeek(d.localPosition.dx, barWidth);
            } : null,
            onHorizontalDragUpdate: widget.enabled ? (d) => _doSeek(d.localPosition.dx, barWidth) : null,
            onHorizontalDragEnd: widget.enabled ? (_) {
              if (_dragRatio != null) {
                final dur = widget.handler.player.duration ?? widget.song.duration;
                widget.handler.player.seek(Duration(milliseconds: (dur.inMilliseconds * _dragRatio!).round()));
              }
              setState(() {
                _dragging = false;
                _dragRatio = null;
              });
            } : null,
            onTapDown: widget.enabled ? (d) {
              final r = (d.localPosition.dx / barWidth).clamp(0.0, 1.0);
              final dur = widget.handler.player.duration ?? widget.song.duration;
              widget.handler.player.seek(Duration(milliseconds: (dur.inMilliseconds * r).round()));
            } : null,
            child: StreamBuilder<Duration>(
              stream: widget.handler.player.positionStream,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = widget.handler.player.duration ?? widget.song.duration;
                final p = _dragRatio ?? (dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0);

                return SizedBox(
                  height: _hovered || _dragging ? 6 : 4,
                  child: Stack(
                    children: [
                      Container(color: Colors.white.withValues(alpha: 0.06)),
                      AnimatedContainer(
                        duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
                        width: barWidth * p,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [widget.palette.primary, widget.palette.secondary, widget.palette.primary]),
                          boxShadow: [BoxShadow(color: (widget.palette.primary as Color).withValues(alpha: 0.6), blurRadius: 10)],
                        ),
                      ),
                      if (_hovered || _dragging)
                        Positioned(
                          left: (barWidth * p - 6).clamp(0.0, barWidth - 12),
                          top: -3,
                          child: Container(
                            width: 12, height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [BoxShadow(color: (widget.palette.primary as Color).withValues(alpha: 0.7), blurRadius: 10)],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _doSeek(double dx, double barWidth) {
    setState(() => _dragRatio = (dx / barWidth).clamp(0.0, 1.0));
  }
}

/// ─── Song Info ───
class _SongInfo extends StatelessWidget {
  const _SongInfo({required this.song, required this.palette});
  final dynamic song, palette;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [BoxShadow(color: (palette.primary as Color).withValues(alpha: 0.2), blurRadius: 16)],
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(7), child: CachedNetworkImage(imageUrl: song.image, width: 56, height: 56, fit: BoxFit.cover, memCacheWidth: 112)),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(song.title, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(song.artist, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// ─── Glowing Play/Pause ───
class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.playing, required this.palette, required this.onTap});
  final bool playing;
  final dynamic palette;
  final VoidCallback onTap;
  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.playing ? 'Pause' : 'Play',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50, height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [widget.palette.primary, widget.palette.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: (widget.palette.primary as Color).withValues(alpha: _h ? 0.65 : 0.4), blurRadius: _h ? 28 : 18, spreadRadius: _h ? 4 : 2)],
            ),
            child: Icon(widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

/// ─── Volume ───
class _VolumeControl extends StatefulWidget {
  const _VolumeControl({required this.handler, required this.palette});
  final dynamic handler, palette;
  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: StreamBuilder<double>(
        stream: widget.handler.player.volumeStream,
        builder: (context, snap) {
          final vol = snap.data ?? 1.0;
          final icon = vol <= 0 ? Icons.volume_off_rounded : vol < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HoverIcon(icon: icon, color: Colors.white.withValues(alpha: 0.35), hoverColor: Colors.white.withValues(alpha: 0.65), tooltip: vol > 0 ? 'Mute' : 'Unmute', size: 18, onTap: () => widget.handler.player.setVolume(vol > 0 ? 0.0 : 1.0)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _h ? 100 : 60,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: (widget.palette.primary as Color).withValues(alpha: 0.7),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(value: vol, onChanged: (v) => widget.handler.player.setVolume(v)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ─── Hover Icon with Tooltip ───
class _HoverIcon extends StatefulWidget {
  const _HoverIcon({required this.icon, required this.color, required this.hoverColor, required this.onTap, this.size = 20, this.tooltip = ''});
  final IconData icon;
  final Color color, hoverColor;
  final VoidCallback onTap;
  final double size;
  final String tooltip;
  @override
  State<_HoverIcon> createState() => _HoverIconState();
}

class _HoverIconState extends State<_HoverIcon> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(6),
            child: Icon(widget.icon, size: widget.size, color: _h ? widget.hoverColor : widget.color),
          ),
        ),
      ),
    );
  }
}

class GlassRefractionPainter extends CustomPainter {
  final double borderRadius;

  const GlassRefractionPainter({required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Draw a dark outer refraction border (gives the lens thickness shadow)
    final darkEdgePaint = Paint()
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.black.withValues(alpha: 0.15),
          Colors.black.withValues(alpha: 0.45),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, darkEdgePaint);

    // 2. Draw the main light-catching outer highlight (the sharp glass edge)
    final borderPaint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.75), // Very bright top-left
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.45), // Subtly bright bottom-right reflection
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, borderPaint);

    // 3. Draw a very thin inner glowing ring (simulating the inner refraction reflection)
    final innerHighlightPaint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.15),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(1.5),
        Radius.circular(borderRadius - 1.5),
      ),
      innerHighlightPaint,
    );

    // 4. Shiny diagonal highlight across the glass surface
    final sheenPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: const Alignment(-0.8, -1.0),
        end: const Alignment(0.8, 1.0),
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.01),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.4, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant GlassRefractionPainter oldDelegate) => false;
}
