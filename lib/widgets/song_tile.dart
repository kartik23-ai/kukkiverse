import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../models/song_model.dart';

class SongTile extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final bool showIndex;
  final int? index;
  final bool isPlaying;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onMore,
    this.showIndex = false,
    this.index,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.accent.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (showIndex && index != null) ...[
                SizedBox(
                  width: 28,
                  child: Text(
                    '${index! + 1}',
                    style: TextStyle(
                      color: isPlaying ? AppColors.accent : AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Artwork — with inner glass border + colored glow
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPlaying
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                    width: 1,
                  ),
                  boxShadow: isPlaying
                      ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 16, spreadRadius: -2)]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: song.image.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: song.image,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.bgElevated,
                            child: const Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 24),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.bgElevated,
                            child: const Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 24),
                          ),
                        )
                      : Container(
                          color: AppColors.bgElevated,
                          child: const Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 24),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: TextStyle(
                        color: isPlaying ? AppColors.accent : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${song.artist} • ${song.album}',
                      style: TextStyle(
                        color: isPlaying ? AppColors.accent.withAlpha(150) : AppColors.textTertiary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Duration
              if (song.durationSeconds > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    song.formattedDuration,
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ),
              // More options - always show for queue management
              IconButton(
                onPressed: onMore,
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                color: AppColors.textTertiary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
