import React, { useState, useEffect, useRef } from 'react';
import { StorageService } from '../services/storage';
import type { Playlist } from '../services/storage';
import { useAudio } from '../context/AudioContext';
import { SongRow } from '../components/SongRow';
import type { Song } from '../services/api';
import { Heart, Plus, FolderHeart, ListMusic, Trash2, Play } from 'lucide-react';
import { SpotifyService } from '../services/spotify';

export const Library: React.FC = () => {
  const { playSong } = useAudio();
  const [likedSongs, setLikedSongs] = useState<Song[]>([]);
  const [playlists, setPlaylists] = useState<Playlist[]>([]);
  const [activePlaylistId, setActivePlaylistId] = useState<string | 'liked' | null>(null);
  const [newPlaylistName, setNewPlaylistName] = useState<string>('');
  const containerRef = useRef<HTMLDivElement>(null);
  const [isCompact, setIsCompact] = useState<boolean>(false);

  // Spotify sync states
  const [showSyncModal, setShowSyncModal] = useState<boolean>(false);
  const [spotifyUrl, setSpotifyUrl] = useState<string>('');
  const [syncing, setSyncing] = useState<boolean>(false);

  // Measure container width to dynamically switch to compact layout
  useEffect(() => {
    if (!containerRef.current) return;
    const observer = new ResizeObserver((entries) => {
      for (let entry of entries) {
        setIsCompact(entry.contentRect.width <= 950);
      }
    });
    observer.observe(containerRef.current);
    return () => observer.disconnect();
  }, []);

  // Reload data
  const loadData = () => {
    setLikedSongs(StorageService.getLikedSongs());
    setPlaylists(StorageService.getPlaylists());
  };

  useEffect(() => {
    loadData();
    const handleUpdate = () => {
      loadData();
    };
    window.addEventListener('library-update', handleUpdate);
    return () => window.removeEventListener('library-update', handleUpdate);
  }, [activePlaylistId]);

  const handleCreatePlaylist = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newPlaylistName.trim()) return;
    StorageService.createPlaylist(newPlaylistName);
    setNewPlaylistName('');
    loadData();
  };

  const handleSyncSpotify = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!spotifyUrl.trim()) return;
    setSyncing(true);
    try {
      const playlist = await SpotifyService.syncPlaylist(spotifyUrl.trim());
      StorageService.saveSyncedPlaylist(playlist);
      setSpotifyUrl('');
      setShowSyncModal(false);
      loadData();
      setActivePlaylistId(playlist.id);
      alert(`Successfully synced playlist "${playlist.name}" with ${playlist.songs.length} tracks!`);
    } catch (err: any) {
      alert(err.message || 'Sync failed.');
    } finally {
      setSyncing(false);
    }
  };

  const handleDeletePlaylist = (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    StorageService.deletePlaylist(id);
    if (activePlaylistId === id) setActivePlaylistId(null);
    loadData();
  };

  // Get active items list to display
  const getActiveSongs = (): Song[] => {
    if (activePlaylistId === 'liked') return likedSongs;
    if (activePlaylistId) {
      const pl = playlists.find((p) => p.id === activePlaylistId);
      return pl ? pl.songs : [];
    }
    return [];
  };

  const activeSongs = getActiveSongs();
  const activeTitle = activePlaylistId === 'liked' 
    ? 'Liked Songs' 
    : playlists.find((p) => p.id === activePlaylistId)?.name || 'Playlist';

  return (
    <div 
      ref={containerRef}
      className="view-shell library-container library-view"
      style={{ 
        padding: isCompact ? '20px' : '32px', 
        display: 'flex', 
        flexDirection: isCompact ? 'column' : 'row', 
        gap: isCompact ? '24px' : '32px', 
        overflowY: 'auto', 
        height: '100%', 
        width: '100%', 
        maxWidth: '100%', 
        boxSizing: 'border-box' 
      }}
    >
      {/* 1. Left: Playlists list & Creator */}
      <div className="library-rail" style={{ width: isCompact ? '100%' : '280px', display: 'flex', flexDirection: 'column', gap: '24px', flexShrink: 0 }}>
        <h2 style={{ fontSize: '20px', fontWeight: 800 }}>Library</h2>

        {/* Create playlist input form */}
        <form onSubmit={handleCreatePlaylist} style={{ display: 'flex', gap: '8px' }}>
          <input
            type="text"
            placeholder="New Playlist Name..."
            value={newPlaylistName}
            onChange={(e) => setNewPlaylistName(e.target.value)}
            style={{ flex: 1, padding: '10px 14px', borderRadius: '8px', fontSize: '13px' }}
          />
          <button
            type="submit"
            style={{
              background: 'var(--accent)',
              border: 'none',
              borderRadius: '8px',
              width: '36px',
              height: '36px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'var(--bg-deep)',
              cursor: 'pointer'
            }}
          >
            <Plus size={18} />
          </button>
        </form>

        {/* Sync Spotify Playlist Button */}
        <button
          onClick={() => setShowSyncModal(true)}
          className="liquid-glass-interactive"
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '8px',
            width: '100%',
            padding: '10px 16px',
            backgroundColor: 'rgba(29, 185, 84, 0.08)',
            border: '1.5px solid rgba(29, 185, 84, 0.25)',
            borderRadius: '8px',
            color: '#1DB954',
            fontSize: '13px',
            fontWeight: 700,
            cursor: 'pointer',
            boxShadow: '0 4px 12px rgba(29, 185, 84, 0.05)'
          }}
        >
          <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M12 2C6.477 2 2 6.477 2 12s4.477 10 10 10 10-4.477 10-10S17.523 2 12 2zm4.586 14.424c-.18.295-.565.387-.86.207-2.377-1.454-5.37-1.783-8.892-.982-.336.076-.67-.135-.746-.472-.076-.336.135-.67.472-.746 3.856-.88 7.15-.505 9.814 1.13.295.18.387.565.207.86zm1.224-2.723c-.226.367-.707.487-1.074.26-2.72-1.672-6.87-2.157-10.075-1.182-.413.125-.852-.106-.978-.52-.125-.413.106-.852.52-.978 3.666-1.112 8.232-.57 11.347 1.347.367.226.487.707.26 1.074zm.106-2.827C14.692 8.956 9.36 8.78 6.275 9.717c-.473.143-.974-.128-1.117-.6-.143-.473.128-.974.6-1.117 3.555-1.08 9.444-.88 13.167 1.33.426.253.565.805.312 1.23-.253.426-.805.565-1.23.312z"/></svg>
          <span>Sync Spotify Playlist</span>
        </button>

        {/* Library sidebar links */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          {/* Liked songs button */}
          <div
            onClick={() => setActivePlaylistId('liked')}
            className="liquid-glass-interactive"
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '14px 16px',
              borderRadius: '10px',
              background: activePlaylistId === 'liked' ? 'rgba(255, 255, 255, 0.05)' : 'rgba(255, 255, 255, 0.01)',
              border: '1px solid rgba(255, 255, 255, 0.04)',
              cursor: 'pointer'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <Heart size={16} fill="var(--accent)" style={{ color: 'var(--accent)' }} />
              <span style={{ fontSize: '14px', fontWeight: 600 }}>Liked Songs</span>
            </div>
            <span style={{ fontSize: '11px', color: 'var(--text-tertiary)', fontWeight: 700 }}>
              {likedSongs.length}
            </span>
          </div>

          {/* User playlists listing */}
          {playlists.map((playlist) => {
            const isActive = activePlaylistId === playlist.id;
            return (
              <div
                key={playlist.id}
                onClick={() => setActivePlaylistId(playlist.id)}
                className="liquid-glass-interactive"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '14px 16px',
                  borderRadius: '10px',
                  background: isActive ? 'rgba(255, 255, 255, 0.05)' : 'rgba(255, 255, 255, 0.01)',
                  border: '1px solid rgba(255, 255, 255, 0.04)',
                  cursor: 'pointer'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', overflow: 'hidden' }}>
                  <ListMusic size={16} style={{ color: isActive ? 'var(--accent)' : 'var(--text-secondary)', flexShrink: 0 }} />
                  <span style={{ fontSize: '14px', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {playlist.name}
                  </span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexShrink: 0 }}>
                  <span style={{ fontSize: '11px', color: 'var(--text-tertiary)', fontWeight: 700 }}>
                    {playlist.songs.length}
                  </span>
                  <button
                    onClick={(e) => handleDeletePlaylist(playlist.id, e)}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      color: 'var(--text-tertiary)',
                      cursor: 'pointer',
                      display: 'flex',
                      padding: '4px'
                    }}
                    onMouseEnter={(e) => (e.currentTarget.style.color = '#fa2d48')}
                    onMouseLeave={(e) => (e.currentTarget.style.color = 'var(--text-tertiary)')}
                  >
                    <Trash2 size={13} />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* 2. Right: Songs detail screen in selected playlist */}
      <div className="library-content" style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: '20px' }}>
        {activePlaylistId ? (
          <>
            {/* Playlist Header card */}
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '24px',
                borderRadius: '12px',
                background: 'rgba(255, 255, 255, 0.02)',
                border: '1px solid rgba(255, 255, 255, 0.04)',
                gap: '16px'
              }}
            >
              <div style={{ minWidth: 0, flex: 1, marginRight: '8px' }}>
                <h1 style={{ 
                  fontSize: isCompact ? '22px' : '28px', 
                  fontWeight: 800, 
                  margin: 0, 
                  overflow: 'hidden', 
                  textOverflow: 'ellipsis', 
                  whiteSpace: 'nowrap' 
                }}>
                  {activeTitle}
                </h1>
                <p style={{ fontSize: '13px', color: 'var(--text-tertiary)', marginTop: '4px' }}>
                  {activeSongs.length} songs total
                </p>
              </div>

              {activeSongs.length > 0 && (
                <button
                  onClick={() => playSong(activeSongs[0], activeSongs)}
                  style={{
                    background: 'var(--text-primary)',
                    border: 'none',
                    color: 'var(--bg-deep)',
                    padding: '12px 24px',
                    borderRadius: '24px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    fontWeight: 700,
                    cursor: 'pointer',
                    fontSize: '13px',
                    boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
                    flexShrink: 0
                  }}
                >
                  <Play size={16} fill="currentColor" />
                  <span>Play All</span>
                </button>
              )}
            </div>

            {/* List panel */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              {activeSongs.length > 0 ? (
                activeSongs.map((song, index) => (
                  <SongRow
                    key={`${song.id}-${index}`}
                    song={song}
                    index={index}
                    customQueue={activeSongs}
                  />
                ))
              ) : (
                <div style={{ padding: '60px 0', textAlign: 'center', color: 'var(--text-tertiary)', fontSize: '14px' }}>
                  No songs in this collection yet. Search and like/add songs to view them here.
                </div>
              )}
            </div>
          </>
        ) : (
          <div
            style={{
              flex: 1,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '12px',
              color: 'var(--text-tertiary)'
            }}
          >
            <FolderHeart size={32} />
            <span style={{ fontSize: '14px' }}>Select a collection to view files</span>
          </div>
        )}
      </div>

      {/* SPOTIFY SYNC MODAL */}
      {showSyncModal && (
        <div 
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            width: '100vw',
            height: '100vh',
            backgroundColor: 'rgba(5, 5, 8, 0.85)',
            backdropFilter: 'blur(10px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: '16px'
          }}
        >
          <form 
            onSubmit={handleSyncSpotify}
            className="liquid-glass"
            style={{
              padding: '32px',
              borderRadius: '24px',
              border: '1px solid rgba(29, 185, 84, 0.25)',
              width: '90%',
              maxWidth: '460px',
              display: 'flex',
              flexDirection: 'column',
              boxShadow: '0 12px 40px rgba(29, 185, 84, 0.1)',
              gap: '16px',
              animation: 'scale-up 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <div style={{
                width: '40px',
                height: '40px',
                borderRadius: '50%',
                backgroundColor: 'rgba(29, 185, 84, 0.1)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#1DB954'
              }}>
                <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor"><path d="M12 2C6.477 2 2 6.477 2 12s4.477 10 10 10 10-4.477 10-10S17.523 2 12 2zm4.586 14.424c-.18.295-.565.387-.86.207-2.377-1.454-5.37-1.783-8.892-.982-.336.076-.67-.135-.746-.472-.076-.336.135-.67.472-.746 3.856-.88 7.15-.505 9.814 1.13.295.18.387.565.207.86zm1.224-2.723c-.226.367-.707.487-1.074.26-2.72-1.672-6.87-2.157-10.075-1.182-.413.125-.852-.106-.978-.52-.125-.413.106-.852.52-.978 3.666-1.112 8.232-.57 11.347 1.347.367.226.487.707.26 1.074zm.106-2.827C14.692 8.956 9.36 8.78 6.275 9.717c-.473.143-.974-.128-1.117-.6-.143-.473.128-.974.6-1.117 3.555-1.08 9.444-.88 13.167 1.33.426.253.565.805.312 1.23-.253.426-.805.565-1.23.312z"/></svg>
              </div>
              <h3 style={{ fontSize: '18px', fontWeight: 800, color: '#fff', margin: 0 }}>Sync Spotify Playlist</h3>
            </div>

            <p style={{ fontSize: '12.5px', color: 'var(--text-secondary)', lineHeight: '1.6', margin: 0 }}>
              Paste a public Spotify playlist URL below. We will fetch all its tracks and import them directly into your Rotty Music library!
            </p>

            {syncing ? (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px', padding: '20px 0' }}>
                <div style={{ width: '36px', height: '36px', border: '3px solid #1DB954', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
                <span style={{ fontSize: '13px', color: 'var(--text-secondary)', fontWeight: 600 }}>Syncing tracks in background, please wait...</span>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '4px' }}>
                <input
                  type="text"
                  placeholder="https://open.spotify.com/playlist/..."
                  value={spotifyUrl}
                  onChange={(e) => setSpotifyUrl(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    backgroundColor: 'rgba(255, 255, 255, 0.04)',
                    border: '1px solid rgba(255, 255, 255, 0.08)',
                    borderRadius: '10px',
                    color: '#fff',
                    fontSize: '13px',
                    outline: 'none',
                    fontWeight: 600,
                    transition: 'border-color 0.2s'
                  }}
                  onFocus={(e) => e.target.style.borderColor = '#1DB954'}
                  onBlur={(e) => e.target.style.borderColor = 'rgba(255, 255, 255, 0.08)'}
                  autoFocus
                />
              </div>
            )}

            {!syncing && (
              <div style={{ display: 'flex', gap: '10px', marginTop: '12px' }}>
                <button
                  type="button"
                  onClick={() => setShowSyncModal(false)}
                  className="liquid-glass-interactive"
                  style={{
                    flex: 1,
                    height: '42px',
                    backgroundColor: 'rgba(255, 255, 255, 0.03)',
                    border: '1px solid rgba(255, 255, 255, 0.05)',
                    borderRadius: '10px',
                    color: 'var(--text-secondary)',
                    fontWeight: 700,
                    fontSize: '13px',
                    cursor: 'pointer'
                  }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="liquid-glass-interactive"
                  style={{
                    flex: 1,
                    height: '42px',
                    backgroundColor: '#1DB954',
                    border: 'none',
                    borderRadius: '10px',
                    color: '#fff',
                    fontWeight: 800,
                    fontSize: '13px',
                    cursor: 'pointer',
                    boxShadow: '0 4px 12px rgba(29, 185, 84, 0.3)'
                  }}
                >
                  Sync Now
                </button>
              </div>
            )}
          </form>
        </div>
      )}
    </div>
  );
};
