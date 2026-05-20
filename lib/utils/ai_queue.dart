import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import '../providers/providers.dart';
import '../providers/premium_providers.dart';
import '../providers/feature_providers.dart';
import '../services/audio_handler.dart';

/// IDs that AI queue must skip — aggressive dedup to prevent repeat songs.
Set<String> buildAiExcludeSet(WidgetRef ref, RottyAudioHandler handler) {
  final exclude = <String>{};

  // Exclude everything in current queue
  for (final s in handler.songQueue) {
    exclude.add(s.id);
  }

  // Exclude entire playback history (not just recent)
  for (final s in handler.history) {
    exclude.add(s.id);
  }

  // Exclude recently played
  for (final s in ref.read(recentSongsProvider)) {
    exclude.add(s.id);
  }

  // Exclude disliked
  for (final id in ref.read(dislikedIdsProvider)) {
    exclude.add(id);
  }

  // Exclude full play history (up to 200 entries)
  for (final e in ref.read(playHistoryProvider).take(200)) {
    exclude.add(e.song.id);
  }

  return exclude;
}
