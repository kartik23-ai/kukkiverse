import React, { useState, useEffect, useRef } from 'react';
import { useAudio } from '../context/AudioContext';
import type { Song } from '../services/api';
import { StorageService } from '../services/storage';
import { 
  MoreVertical, Heart, ListPlus, FolderPlus, 
  ArrowRight, Trash2, ListMusic
} from 'lucide-react';

interface SongOptionsMenuProps {
  song: Song;
  trigger?: React.ReactNode;
  align?: 'left' | 'right';
  onRemoveFromRecents?: () => void;
}

export const SongOptionsMenu: React.FC<SongOptionsMenuProps> = ({ 
  song, 
  trigger, 
  align = 'right',
  onRemoveFromRecents 
}) => {
  const { addToQueue, playNext } = useAudio();
  const [menuOpen, setMenuOpen] = useState<boolean>(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const [openUpward, setOpenUpward] = useState<boolean>(false);

  // Parent row z-index elevation and viewport space detection
  useEffect(() => {
    if (!menuRef.current) return;
    const parentRow = menuRef.current.closest('.liquid-glass-interactive') as HTMLElement;
    
    if (menuOpen) {
      // 1. Elevate parent z-index to stay on top of subsequent sibling elements
      if (parentRow) {
        parentRow.style.zIndex = '100';
      }
      
      // 2. Measure viewport space below trigger to decide if we should open upward
      const rect = menuRef.current.getBoundingClientRect();
      const spaceBelow = window.innerHeight - rect.bottom;
      setOpenUpward(spaceBelow < 320); // If less than 320px remains, flip menu upward!
    } else {
      // Reset parent z-index
      if (parentRow) {
        parentRow.style.zIndex = '';
      }
    }
  }, [menuOpen]);

  // Outside click auto-close logic
  useEffect(() => {
    if (!menuOpen) return;
    const handleOutsideClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
    };
    document.addEventListener('mousedown', handleOutsideClick);
    return () => document.removeEventListener('mousedown', handleOutsideClick);
  }, [menuOpen]);

  const handleAddToQueue = (e: React.MouseEvent) => {
    e.stopPropagation();
    addToQueue(song);
    setMenuOpen(false);
  };

  const handlePlayNext = (e: React.MouseEvent) => {
    e.stopPropagation();
    playNext(song);
    setMenuOpen(false);
  };

  const handleToggleLike = (e: React.MouseEvent) => {
    e.stopPropagation();
    StorageService.toggleLikeSong(song);
    window.dispatchEvent(new Event('library-update'));
    setMenuOpen(false);
  };

  const handleAddToPlaylist = (playlistId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    StorageService.addSongToPlaylist(playlistId, song);
    window.dispatchEvent(new Event('library-update'));
    setMenuOpen(false);
  };

  const handleRemoveRecents = (e: React.MouseEvent) => {
    e.stopPropagation();
    StorageService.removeRecentSong(song.id);
    window.dispatchEvent(new Event('library-update'));
    if (onRemoveFromRecents) {
      onRemoveFromRecents();
    }
    setMenuOpen(false);
  };

  const isLiked = StorageService.isSongLiked(song.id);
  const playlists = StorageService.getPlaylists();
  const recentSongs = StorageService.getRecentSongs();
  const isRecent = recentSongs.some((s) => s.id === song.id);

  return (
    <div style={{ position: 'relative', display: 'inline-block', flexShrink: 0 }} ref={menuRef}>
      {trigger ? (
        <div onClick={(e) => { e.stopPropagation(); setMenuOpen(!menuOpen); }}>
          {trigger}
        </div>
      ) : (
        <button
          onClick={(e) => {
            e.stopPropagation();
            setMenuOpen(!menuOpen);
          }}
          style={{
            background: 'transparent',
            border: 'none',
            color: 'var(--text-tertiary)',
            cursor: 'pointer',
            padding: '8px',
            borderRadius: '50%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            transition: 'all 0.2s'
          }}
          onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.05)')}
          onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
        >
          <MoreVertical size={16} />
        </button>
      )}

      {menuOpen && (
        <div
          className="liquid-glass"
          style={{
            position: 'absolute',
            [align]: 0,
            ...(openUpward ? {
              bottom: '100%',
              marginBottom: '8px'
            } : {
              top: '100%',
              marginTop: '4px'
            }),
            width: '190px',
            borderRadius: '12px',
            border: '1px solid rgba(255, 255, 255, 0.08)',
            padding: '6px 0',
            zIndex: 900,
            display: 'flex',
            flexDirection: 'column',
            boxShadow: '0 8px 32px rgba(0, 0, 0, 0.55)',
            maxHeight: '380px',
            overflowY: 'auto'
          }}
          onClick={(e) => e.stopPropagation()}
        >
          {/* Add to Queue */}
          <button
            onClick={handleAddToQueue}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              padding: '10px 14px',
              background: 'transparent',
              border: 'none',
              color: 'var(--text-primary)',
              fontSize: '12px',
              fontWeight: 500,
              cursor: 'pointer',
              textAlign: 'left',
              width: '100%',
              transition: 'background 0.2s'
            }}
            onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.05)')}
            onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
          >
            <ListPlus size={14} style={{ color: '#7B61FF' }} />
            <span>Add to Queue</span>
          </button>

          {/* Play Next */}
          <button
            onClick={handlePlayNext}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              padding: '10px 14px',
              background: 'transparent',
              border: 'none',
              color: 'var(--text-primary)',
              fontSize: '12px',
              fontWeight: 500,
              cursor: 'pointer',
              textAlign: 'left',
              width: '100%',
              transition: 'background 0.2s'
            }}
            onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.05)')}
            onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
          >
            <ArrowRight size={14} style={{ color: 'var(--accent)' }} />
            <span>Play Next</span>
          </button>

          {/* Like / Unlike */}
          <button
            onClick={handleToggleLike}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              padding: '10px 14px',
              background: 'transparent',
              border: 'none',
              color: 'var(--text-primary)',
              fontSize: '12px',
              fontWeight: 500,
              cursor: 'pointer',
              textAlign: 'left',
              width: '100%',
              transition: 'background 0.2s'
            }}
            onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.05)')}
            onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
          >
            <Heart 
              size={14} 
              fill={isLiked ? 'var(--accent)' : 'transparent'} 
              style={{ color: isLiked ? 'var(--accent)' : '#FF2D95' }} 
            />
            <span>{isLiked ? 'Remove Liked' : 'Like Song'}</span>
          </button>

          {/* Remove from Recents */}
          {isRecent && (
            <button
              onClick={handleRemoveRecents}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                padding: '10px 14px',
                background: 'transparent',
                border: 'none',
                color: 'var(--text-primary)',
                fontSize: '12px',
                fontWeight: 500,
                cursor: 'pointer',
                textAlign: 'left',
                width: '100%',
                transition: 'background 0.2s'
              }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.05)')}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
            >
              <Trash2 size={14} style={{ color: 'rgba(255,255,255,0.6)' }} />
              <span>Remove from History</span>
            </button>
          )}

          {/* Add to Playlist Heading / Section */}
          <div style={{ borderTop: '1px solid rgba(255, 255, 255, 0.05)', margin: '6px 0' }}></div>
          
          <div style={{ 
            padding: '4px 14px', 
            fontSize: '9px', 
            color: 'var(--text-tertiary)', 
            textTransform: 'uppercase', 
            letterSpacing: '0.8px', 
            fontWeight: 700,
            display: 'flex',
            alignItems: 'center',
            gap: '6px'
          }}>
            <ListMusic size={11} />
            <span>Add to Playlist</span>
          </div>

          {playlists.length === 0 ? (
            <div style={{ padding: '6px 14px', fontSize: '11px', color: 'var(--text-tertiary)', fontStyle: 'italic' }}>
              No playlists
            </div>
          ) : (
            playlists.map((pl) => (
              <button
                key={pl.id}
                onClick={(e) => handleAddToPlaylist(pl.id, e)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  padding: '8px 14px 8px 24px',
                  background: 'transparent',
                  border: 'none',
                  color: 'var(--text-secondary)',
                  fontSize: '12px',
                  cursor: 'pointer',
                  textAlign: 'left',
                  width: '100%',
                  textOverflow: 'ellipsis',
                  overflow: 'hidden',
                  whiteSpace: 'nowrap',
                  transition: 'background 0.2s'
                }}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.05)')}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
              >
                <FolderPlus size={12} style={{ color: '#00D4FF', flexShrink: 0 }} />
                <span style={{ textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>{pl.name}</span>
              </button>
            ))
          )}
        </div>
      )}
    </div>
  );
};
