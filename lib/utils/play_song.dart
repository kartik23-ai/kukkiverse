import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import '../providers/providers.dart';
import '../providers/feature_providers.dart';
import '../providers/premium_providers.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import 'ai_queue.dart';

Future<void> playSongWithContext(
  WidgetRef ref,
  SongModel song, {
  List<SongModel>? playlist,
  bool runAiDj = false,
}) async {
  final handler = ref.read(audioHandlerProvider);
  final repo = ref.read(musicRepositoryProvider);

  var track = await repo.resolveSong(song);
  if (!track.hasPlayableUrl) {
    throw StateError('Could not load audio for "${song.title}"');
  }

  var queue = playlist ?? [track];
  queue = queue.map((s) => s.id == track.id ? track : s).toList();
  final idx = queue.indexWhere((s) => s.id == track.id);

  await handler.playSong(track, playlist: queue, index: idx < 0 ? 0 : idx);

  ref.read(recentSongsProvider.notifier).add(track);
  ref.read(playHistoryProvider.notifier).record(track);
  await StorageService().recordListenStreak();
  ref.invalidate(listeningStreakProvider);
  ref.read(dynamicPaletteProvider.notifier).updateFromSong(track);
  unawaited(FirebaseService.instance.logPlay(track));

  final room = ref.read(partyRoomProvider);
  if (room.code != null) {
    await ref.read(partyRoomProvider.notifier).addSong(track);
  }

  if (runAiDj || ref.read(aiDjEnabledProvider)) {
    Future.microtask(() async {
      try {
        final exclude = buildAiExcludeSet(ref, handler);
        exclude.add(track.id);

        final smart = await ref.read(aiDjServiceProvider).buildSmartQueue(
          nowPlaying: track,
          recent: ref.read(recentSongsProvider),
          favorites: ref.read(favoritesProvider),
          excludeIds: exclude,
          limit: 18,
        );

        final blocked = ref.read(dislikedIdsProvider);
        final filtered = smart.where((s) => !blocked.contains(s.id)).toList();

        if (filtered.isNotEmpty) {
          final added = await handler.appendUpcoming(filtered);
          if (added > 0) {
            // ignore: avoid_print
            debugPrint('ROTTY AI: added $added new tracks to queue');
          }
        }
      } catch (e) {
        // ignore: avoid_print
        debugPrint('ROTTY AI queue error: $e');
      }
    });
  }
}

Future<void> refreshAiQueue(WidgetRef ref) async {
  final handler = ref.read(audioHandlerProvider);
  final current = handler.currentSong;
  if (current == null) return;

  final exclude = buildAiExcludeSet(ref, handler);
  final smart = await ref.read(aiDjServiceProvider).buildSmartQueue(
    nowPlaying: current,
    recent: ref.read(recentSongsProvider),
    favorites: ref.read(favoritesProvider),
    excludeIds: exclude,
    limit: 20,
  );
  final blocked = ref.read(dislikedIdsProvider);
  final filtered = smart.where((s) => !blocked.contains(s.id)).toList();
  if (filtered.isNotEmpty) {
    await handler.appendUpcoming(filtered);
  }
}
