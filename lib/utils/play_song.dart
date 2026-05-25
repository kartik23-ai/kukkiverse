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
    if (room.isHost) {
      await ref.read(partyRoomProvider.notifier).setQueue(queue);
      await ref.read(partyRoomProvider.notifier).updatePlayback(track, true);
    } else {
      await ref.read(partyRoomProvider.notifier).addSong(track);
    }
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
