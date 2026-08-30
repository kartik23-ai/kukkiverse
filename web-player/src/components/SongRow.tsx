import React from 'react';
import { useAudio } from '../context/AudioContext';
import type { Song } from '../services/api';
import { SongOptionsMenu } from './SongOptionsMenu';

interface SongRowProps {
  song: Song;
  index: number;
  customQueue?: Song[];
}

const formatDuration = (secs: number) => {
  if (isNaN(secs) || secs === 0) return '--:--';
  const mins = Math.floor(secs / 60);
  const remainingSecs = Math.floor(secs % 60);
  return `${mins}:${remainingSecs < 10 ? '0' : ''}${remainingSecs}`;
};

export const SongRow: React.FC<SongRowProps> = ({ song, index, customQueue }) => {
  const { currentSong, isPlaying, playSong } = useAudio();
  const isCurrent = currentSong?.id === song.id;

  const handlePlay = () => {
    playSong(song, customQueue);
  };

  return (
    <div
      onClick={handlePlay}
      onKeyDown={(event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          handlePlay();
        }
      }}
      role="button"
      tabIndex={0}
      aria-label={`Play ${song.title} by ${song.artist}`}
      className="song-row liquid-glass-interactive"
      style={{
        display: 'flex',
        alignItems: 'center',
        padding: '10px 16px',
        borderRadius: '10px',
        gap: '16px',
        border: '1px solid rgba(255, 255, 255, 0.02)',
        backgroundColor: isCurrent ? 'rgba(255, 255, 255, 0.04)' : 'transparent',
        transition: 'all 0.2s ease',
        cursor: 'pointer',
        position: 'relative',
        outline: 'none'
      }}
    >
      {/* Index or Play icon */}
      <div
        style={{
          width: '24px',
          display: 'flex',
          justifyContent: 'center',
          color: isCurrent ? 'var(--accent)' : 'var(--text-tertiary)',
          fontSize: '14px',
          fontWeight: 600
        }}
      >
        {isCurrent && isPlaying ? (
          <div className="sound-wave">
            <div className="sound-wave-bar" />
            <div className="sound-wave-bar" />
            <div className="sound-wave-bar" />
          </div>
        ) : (
          index + 1
        )}
      </div>

      {/* Thumbnail */}
      <img
        src={song.image || 'https://via.placeholder.com/150'}
        alt={song.title}
        loading="lazy"
        decoding="async"
        style={{
          width: '40px',
          height: '40px',
          borderRadius: '6px',
          objectFit: 'cover',
          boxShadow: '0 2px 6px rgba(0,0,0,0.2)'
        }}
      />

      {/* Title & Artist */}
      <div style={{ display: 'flex', flexDirection: 'column', flex: 1, overflow: 'hidden', gap: '2px' }}>
        <span
          style={{
            fontSize: '14px',
            fontWeight: 600,
            color: isCurrent ? 'var(--accent)' : 'var(--text-primary)',
            textOverflow: 'ellipsis',
            overflow: 'hidden',
            whiteSpace: 'nowrap'
          }}
        >
          {song.title}
        </span>
        <span
          style={{
            fontSize: '12px',
            color: 'var(--text-secondary)',
            textOverflow: 'ellipsis',
            overflow: 'hidden',
            whiteSpace: 'nowrap'
          }}
        >
          {song.artist}
        </span>
      </div>

      <div className="song-album-column" style={{ fontSize: '13px', color: 'var(--text-secondary)', flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
        {song.album}
      </div>

      <span className="source-pill" aria-label="Source YouTube">YT</span>

      {/* Duration */}
      <div style={{ fontSize: '13px', color: 'var(--text-tertiary)', fontWeight: 500, minWidth: '40px', textAlign: 'right', flexShrink: 0 }}>
        {formatDuration(song.duration)}
      </div>

      {/* Options Menu */}
      <SongOptionsMenu song={song} />
    </div>
  );
};
