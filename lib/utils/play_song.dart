import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/song_model.dart';
import '../providers/providers.dart';
import '../providers/feature_providers.dart';
import '../providers/premium_providers.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import 'ai_queue.dart';
import '../router/app_router.dart';

Future<void> playSongWithContext(
  WidgetRef ref,
  SongModel song, {
  List<SongModel>? playlist,
  bool runAiDj = false,
  bool isPlayAll = false,
}) async {
  final handler = ref.read(audioHandlerProvider);
  final repo = ref.read(musicRepositoryProvider);

  try {
    debugPrint('ROTTY PLAYBACK START: Resolving song "${song.title}" (${song.id})');
    var track = await repo.resolveSong(song);
    debugPrint('ROTTY PLAYBACK RESOLVE: Has playable URL = ${track.hasPlayableUrl}, URL = ${track.url}');
    if (!track.hasPlayableUrl) {
      throw StateError('Could not load audio for "${song.title}" (URL is empty)');
    }

    final aiDjEnabled = runAiDj || ref.read(aiDjEnabledProvider);
    var queue = (aiDjEnabled && !isPlayAll) ? [track] : (playlist ?? [track]);
    queue = queue.map((s) => s.id == track.id ? track : s).toList();
    final idx = queue.indexWhere((s) => s.id == track.id);

    debugPrint('ROTTY PLAYBACK HANDLER: Sending track to audio handler. Index: $idx, Queue length: ${queue.length}');
    await handler.playSong(track, playlist: queue, index: idx < 0 ? 0 : idx);

    ref.read(recentSongsProvider.notifier).add(track);
    ref.read(playHistoryProvider.notifier).record(track);
    await StorageService().recordListenStreak();
    ref.invalidate(listeningStreakProvider);
    ref.read(dynamicPaletteProvider.notifier).updateFromSong(track);
    unawaited(FirebaseService.instance.logPlay(track));

    final room = ref.read(partyRoomProvider);
    if (room.code != null) {
      if (room.isHost) {
        await ref.read(partyRoomProvider.notifier).setQueue(queue);
        await ref.read(partyRoomProvider.notifier).updatePlayback(track, true);
      } else {
        await ref.read(partyRoomProvider.notifier).addSong(track);
      }
    }
  } catch (e, stackTrace) {
    debugPrint('ROTTY PLAYBACK EXCEPTION IN PLAY_SONG: $e');
    debugPrint('ROTTY PLAYBACK STACKTRACE: $stackTrace');
    try {
      final context = appRouter.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16162A),
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to play "${song.title}": $e',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {}
  }
}

Future<void> refreshAiQueue(WidgetRef ref) async {
  try {
    final handler = ref.read(audioHandlerProvider);
    final current = handler.currentSong;
    if (current == null) return;

    final exclude = buildAiExcludeSet(ref, handler);
    final aiDjService = ref.read(aiDjServiceProvider);
    final recent = ref.read(recentSongsProvider);
    final favorites = ref.read(favoritesProvider);
    final blocked = ref.read(dislikedIdsProvider);

    final smart = await aiDjService.buildSmartQueue(
      nowPlaying: current,
      recent: recent,
      favorites: favorites,
      excludeIds: exclude,
      excludeSongs: [
        ...handler.songQueue,
        ...handler.history,
      ],
      limit: 20,
    );

    final filtered = smart.where((s) => !blocked.contains(s.id)).toList();
    if (filtered.isNotEmpty) {
      await handler.appendUpcoming(filtered);
    }
  } catch (e, stack) {
    debugPrint('Error in refreshAiQueue: $e\n$stack');
  }
}


Future<void> navigateToArtist(BuildContext context, WidgetRef ref, String artistName) async {
  final cleanName = artistName.split(RegExp(r'[,&]')).first.trim();
  if (cleanName.isEmpty) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: CircularProgressIndicator(color: Color(0xFFFA2D48)),
    ),
  );

  try {
    final repo = ref.read(musicRepositoryProvider);
    final results = await repo.searchArtists(cleanName);
    if (context.mounted) Navigator.pop(context); // Dismiss loading dialog

    if (results.isNotEmpty) {
      final artist = results.first;
      if (context.mounted) {
        context.push('/artist/${artist.id}', extra: {
          'name': artist.name,
          'image': artist.image,
        });
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Artist "$cleanName" not found'),
            backgroundColor: const Color(0xFF16162A),
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) Navigator.pop(context); // Dismiss loading dialog
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading artist: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
