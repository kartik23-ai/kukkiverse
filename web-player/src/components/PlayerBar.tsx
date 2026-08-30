import React, { useState } from 'react';
import { useAudio } from '../context/AudioContext';
import { StorageService } from '../services/storage';
import { SongOptionsMenu } from './SongOptionsMenu';
import { 
  Play, Pause, SkipForward, SkipBack, Shuffle, Repeat, 
  Volume2, VolumeX, Heart, Maximize2, Activity, Maximize, Minimize, Video
} from 'lucide-react';

interface PlayerBarProps {
  isPanelOpen: boolean;
  setIsPanelOpen: (open: boolean) => void;
}

// Helper to format seconds to mm:ss
const formatTime = (seconds: number) => {
  if (isNaN(seconds)) return '0:00';
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
};

export const PlayerBar: React.FC<PlayerBarProps> = ({ isPanelOpen, setIsPanelOpen }) => {
  const {
    currentSong,
    isPlaying,
    currentTime,
    duration,
    volume,
    isShuffle,
    isLoop,
    is8DActive,
    togglePlay,
    nextSong,
    prevSong,
    seek,
    setVolume,
    toggleShuffle,
    toggleLoop,
    youtubeVideoId,
    isVideoMode,
    isResolvingVideo,
    toggleVideoMode
  } = useAudio();
  const canUseVideo = Boolean(currentSong && (currentSong.source === 'youtube' || currentSong.youtubeVideoId || youtubeVideoId));

  const [isLiked, setIsLiked] = useState<boolean>(() => {
    return currentSong ? StorageService.isSongLiked(currentSong.id) : false;
  });

  // Fullscreen State Management
  const [isFullscreen, setIsFullscreen] = useState<boolean>(!!document.fullscreenElement);

  React.useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
    };
    document.addEventListener('fullscreenchange', handleFullscreenChange);
    return () => document.removeEventListener('fullscreenchange', handleFullscreenChange);
  }, []);

  const toggleFullscreen = () => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch((err) => {
        console.error(`Error attempting to enable fullscreen: ${err.message}`);
      });
    } else {
      document.exitFullscreen();
    }
  };

  // Track like state updates when song changes
  React.useEffect(() => {
    if (currentSong) {
      setIsLiked(StorageService.isSongLiked(currentSong.id));
    }
  }, [currentSong]);

  const handleLike = () => {
    if (!currentSong) return;
    const liked = StorageService.toggleLikeSong(currentSong);
    setIsLiked(liked);
  };

  const handleVolumeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setVolume(parseFloat(e.target.value));
  };

  const handleSeekChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    seek(parseFloat(e.target.value));
  };

  if (!currentSong) {
    return (
      <footer
        className="player-dock player-dock--empty liquid-glass"
        style={{
          height: '90px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '0 24px',
          borderRadius: '16px 16px 0 0',
          color: 'var(--text-tertiary)',
          fontSize: '14px',
          fontWeight: 500,
          zIndex: 20
        }}
      >
        Select a song to start listening
      </footer>
    );
  }

  return (
    <footer
      className="player-dock liquid-glass"
      style={{
        height: '90px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 24px',
        borderRadius: '16px 16px 0 0',
        zIndex: 20,
        flexShrink: 0,
        position: 'relative'
      }}
    >
      {/* Full-width Draggable Progress Slider at the Top Edge */}
      <div 
        style={{ 
          position: 'absolute', 
          top: 0, 
          left: 0, 
          right: 0, 
          height: '4px', 
          width: '100%',
          transform: 'translateY(-50%)',
          zIndex: 30
        }}
      >
        <input
          type="range"
          className="custom-slider"
          min={0}
          max={duration || 100}
          step={0.1}
          value={currentTime}
          onChange={handleSeekChange}
          style={{ 
            width: '100%', 
            margin: 0, 
            padding: 0, 
            height: '100%', 
            display: 'block',
            background: `linear-gradient(to right, var(--accent) 0%, var(--accent) ${(currentTime / (duration || 1)) * 100}%, rgba(255, 255, 255, 0.08) ${(currentTime / (duration || 1)) * 100}%, rgba(255, 255, 255, 0.08) 100%)`
          }}
        />
      </div>

      {/* 1. Left: Song metadata */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', width: '30%', minWidth: '180px' }}>
        <img
          src={currentSong.image || 'https://via.placeholder.com/150'}
          alt={currentSong.title}
          onClick={() => setIsPanelOpen(!isPanelOpen)}
          style={{
            width: '56px',
            height: '56px',
            borderRadius: '8px',
            objectFit: 'cover',
            cursor: 'pointer',
            boxShadow: '0 4px 12px rgba(0,0,0,0.3)',
            transition: 'transform 0.2s'
          }}
          onMouseEnter={(e) => (e.currentTarget.style.transform = 'scale(1.05)')}
          onMouseLeave={(e) => (e.currentTarget.style.transform = 'scale(1)')}
        />
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', overflow: 'hidden' }}>
          <span
            onClick={() => setIsPanelOpen(!isPanelOpen)}
            style={{
              fontSize: '14px',
              fontWeight: 600,
              color: 'var(--text-primary)',
              cursor: 'pointer',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis'
            }}
          >
            {currentSong.title}
          </span>
          <span
            style={{
              fontSize: '12px',
              color: 'var(--text-secondary)',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis'
            }}
          >
            {currentSong.artist}
          </span>
        </div>
        <button
          onClick={handleLike}
          style={{
            background: 'transparent',
            border: 'none',
            color: isLiked ? 'var(--accent)' : 'var(--text-tertiary)',
            cursor: 'pointer',
            display: 'flex',
            padding: '8px',
            marginLeft: '8px',
            transition: 'transform 0.15s, color 0.15s'
          }}
          onMouseEnter={(e) => (e.currentTarget.style.transform = 'scale(1.15)')}
          onMouseLeave={(e) => (e.currentTarget.style.transform = 'scale(1)')}
        >
          <Heart size={18} fill={isLiked ? 'var(--accent)' : 'transparent'} />
        </button>
        <SongOptionsMenu song={currentSong} align="left" />
      </div>

      {/* 2. Center: Audio controls */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', width: '40%', maxWidth: '600px' }}>
        {/* Buttons Row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          <button
            onClick={toggleShuffle}
            style={{
              background: 'transparent',
              border: 'none',
              color: isShuffle ? 'var(--accent)' : 'var(--text-secondary)',
              cursor: 'pointer',
              transition: 'color 0.2s'
            }}
          >
            <Shuffle size={16} />
          </button>
          
          <button
            onClick={prevSong}
            style={{
              background: 'transparent',
              border: 'none',
              color: 'var(--text-primary)',
              cursor: 'pointer'
            }}
          >
            <SkipBack size={18} fill="currentColor" />
          </button>

          <button
            onClick={togglePlay}
            style={{
              background: 'var(--text-primary)',
              border: 'none',
              color: 'var(--bg-deep)',
              width: '36px',
              height: '36px',
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
              boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
              transition: 'transform 0.1s'
            }}
            onMouseEnter={(e) => (e.currentTarget.style.transform = 'scale(1.08)')}
            onMouseLeave={(e) => (e.currentTarget.style.transform = 'scale(1)')}
          >
            {isPlaying ? <Pause size={18} fill="currentColor" /> : <Play size={18} fill="currentColor" style={{ marginLeft: '2px' }} />}
          </button>

          <button
            onClick={nextSong}
            style={{
              background: 'transparent',
              border: 'none',
              color: 'var(--text-primary)',
              cursor: 'pointer'
            }}
          >
            <SkipForward size={18} fill="currentColor" />
          </button>

          <button
            onClick={toggleLoop}
            style={{
              background: 'transparent',
              border: 'none',
              color: isLoop !== 'none' ? 'var(--accent)' : 'var(--text-secondary)',
              position: 'relative',
              cursor: 'pointer',
              transition: 'color 0.2s'
            }}
          >
            <Repeat size={16} />
            {isLoop === 'one' && (
              <span
                style={{
                  position: 'absolute',
                  top: '-4px',
                  right: '-6px',
                  fontSize: '8px',
                  fontWeight: 900,
                  color: 'var(--accent)'
                }}
              >
                1
              </span>
            )}
          </button>
        </div>
      </div>

      {/* 3. Right: Utility deck */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '16px', justifyContent: 'flex-end', width: '30%', minWidth: '220px' }}>
        {/* Playback time elapsed / duration */}
        <span style={{ fontSize: '11px', color: 'var(--text-tertiary)', fontVariantNumeric: 'tabular-nums', marginRight: '4px' }}>
          {formatTime(currentTime)} / {formatTime(duration)}
        </span>

        {is8DActive && (
          <div
            title="8D Audio Active"
            style={{
              display: 'flex',
              alignItems: 'center',
              color: 'var(--accent-alt)',
              animation: 'pulse 1.5s infinite',
              gap: '4px'
            }}
          >
            <Activity size={14} />
            <span style={{ fontSize: '10px', fontWeight: 700, letterSpacing: '0.5px' }}>8D</span>
          </div>
        )}

        <button
          type="button"
          onClick={toggleVideoMode}
          disabled={!canUseVideo || isResolvingVideo}
          aria-pressed={isVideoMode}
          aria-label={isVideoMode ? 'Hide music video' : 'Show music video'}
          title={isResolvingVideo ? 'Loading music video' : canUseVideo ? (isVideoMode ? 'Hide music video' : 'Watch music video') : 'Video is available for YouTube tracks'}
          style={{
            width: '32px',
            height: '32px',
            display: 'grid',
            placeItems: 'center',
            color: isVideoMode ? 'var(--accent)' : 'var(--text-secondary)',
            background: isVideoMode ? 'rgba(250,45,72,0.12)' : 'transparent',
            border: 0,
            borderRadius: '9px',
            cursor: canUseVideo ? 'pointer' : 'not-allowed',
            opacity: canUseVideo ? 1 : 0.35
          }}
        >
          <Video size={16} />
        </button>

        {/* Volume controls */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <button
            onClick={() => setVolume(volume > 0 ? 0 : 0.8)}
            style={{
              background: 'transparent',
              border: 'none',
              color: volume === 0 ? 'var(--text-tertiary)' : 'var(--text-secondary)',
              cursor: 'pointer'
            }}
          >
            {volume === 0 ? <VolumeX size={16} /> : <Volume2 size={16} />}
          </button>
          <input
            type="range"
            className="custom-slider"
            min={0}
            max={1}
            step={0.01}
            value={volume}
            onChange={handleVolumeChange}
            style={{ width: '80px' }}
          />
        </div>

        {/* Fullscreen Toggle */}
        <button
          onClick={toggleFullscreen}
          title={isFullscreen ? "Exit Fullscreen" : "Fullscreen"}
          style={{
            background: 'transparent',
            border: 'none',
            color: isFullscreen ? 'var(--accent)' : 'var(--text-secondary)',
            cursor: 'pointer',
            padding: '8px',
            transition: 'color 0.2s, transform 0.15s'
          }}
          onMouseEnter={(e) => (e.currentTarget.style.transform = 'scale(1.1)')}
          onMouseLeave={(e) => (e.currentTarget.style.transform = 'scale(1)')}
        >
          {isFullscreen ? <Minimize size={16} /> : <Maximize size={16} />}
        </button>

        {/* Panel Expand Toggle */}
        <button
          onClick={() => setIsPanelOpen(!isPanelOpen)}
          style={{
            background: 'transparent',
            border: 'none',
            color: isPanelOpen ? 'var(--accent)' : 'var(--text-secondary)',
            cursor: 'pointer',
            padding: '8px',
            transition: 'color 0.2s, transform 0.15s'
          }}
          onMouseEnter={(e) => (e.currentTarget.style.transform = 'scale(1.1)')}
          onMouseLeave={(e) => (e.currentTarget.style.transform = 'scale(1)')}
        >
          <Maximize2 size={16} />
        </button>
      </div>
    </footer>
  );
};
