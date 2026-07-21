import type { Song } from './api';

export interface Playlist {
  id: string;
  name: string;
  songs: Song[];
  createdAt: string;
}

const KEYS = {
  LIKED_SONGS: 'rotty_liked_songs',
  PLAYLISTS: 'rotty_playlists',
  RECENT_SONGS: 'rotty_recent_songs',
  THEME: 'rotty_theme_mode',
  VOLUME: 'rotty_playback_volume'
};

export const StorageService = {
  getLikedSongs(): Song[] {
    try {
      const data = localStorage.getItem(KEYS.LIKED_SONGS);
      return data ? JSON.parse(data) : [];
    } catch (_) {
      return [];
    }
  },

  toggleLikeSong(song: Song): boolean {
    const songs = this.getLikedSongs();
    const index = songs.findIndex((s) => s.id === song.id);
    let liked = false;

    if (index >= 0) {
      songs.splice(index, 1);
    } else {
      songs.unshift({ ...song, url: '' });
      liked = true;
    }

    localStorage.setItem(KEYS.LIKED_SONGS, JSON.stringify(songs));
    return liked;
  },

  isSongLiked(songId: string): boolean {
    const songs = this.getLikedSongs();
    return songs.some((s) => s.id === songId);
  },

  getPlaylists(): Playlist[] {
    try {
      const data = localStorage.getItem(KEYS.PLAYLISTS);
      return data ? JSON.parse(data) : [];
    } catch (_) {
      return [];
    }
  },

  createPlaylist(name: string): Playlist {
    const playlists = this.getPlaylists();
    const newPlaylist: Playlist = {
      id: Math.random().toString(36).substring(7),
      name: name.trim() || 'My Playlist',
      songs: [],
      createdAt: new Date().toISOString()
    };
    playlists.push(newPlaylist);
    localStorage.setItem(KEYS.PLAYLISTS, JSON.stringify(playlists));
    return newPlaylist;
  },

  deletePlaylist(playlistId: string) {
    let playlists = this.getPlaylists();
    playlists = playlists.filter((p) => p.id !== playlistId);
    localStorage.setItem(KEYS.PLAYLISTS, JSON.stringify(playlists));
  },

  saveSyncedPlaylist(playlist: { id: string; name: string; songs: Song[] }) {
    const playlists = this.getPlaylists();
    const existingIdx = playlists.findIndex((p) => p.id === playlist.id);
    const newPlaylist: Playlist = {
      id: playlist.id,
      name: playlist.name,
      songs: playlist.songs,
      createdAt: new Date().toISOString()
    };
    
    if (existingIdx !== -1) {
      playlists[existingIdx] = newPlaylist;
    } else {
      playlists.push(newPlaylist);
    }
    
    localStorage.setItem(KEYS.PLAYLISTS, JSON.stringify(playlists));
  },

  addSongToPlaylist(playlistId: string, song: Song) {
    const playlists = this.getPlaylists();
    const playlist = playlists.find((p) => p.id === playlistId);
    if (playlist) {
      if (!playlist.songs.some((s) => s.id === song.id)) {
        playlist.songs.push({ ...song, url: '' });
        localStorage.setItem(KEYS.PLAYLISTS, JSON.stringify(playlists));
      }
    }
  },

  removeSongFromPlaylist(playlistId: string, songId: string) {
    const playlists = this.getPlaylists();
    const playlist = playlists.find((p) => p.id === playlistId);
    if (playlist) {
      playlist.songs = playlist.songs.filter((s) => s.id !== songId);
      localStorage.setItem(KEYS.PLAYLISTS, JSON.stringify(playlists));
    }
  },

  getRecentSongs(): Song[] {
    try {
      const data = localStorage.getItem(KEYS.RECENT_SONGS);
      return data ? JSON.parse(data) : [];
    } catch (_) {
      return [];
    }
  },

  addRecentSong(song: Song) {
    let recent = this.getRecentSongs();
    recent = recent.filter((s) => s.id !== song.id); // Remove duplicate
    recent.unshift({ ...song, url: '' }); // Add to top (strip URL)
    if (recent.length > 50) recent.pop(); // Limit size
    localStorage.setItem(KEYS.RECENT_SONGS, JSON.stringify(recent));
  },

  removeRecentSong(songId: string) {
    let recent = this.getRecentSongs();
    recent = recent.filter((s) => s.id !== songId);
    localStorage.setItem(KEYS.RECENT_SONGS, JSON.stringify(recent));
  },

  getTheme(): 'normal' {
    return 'normal'; // Lock to Rotty Standard!
  },

  setTheme(theme: 'normal') {
    localStorage.setItem(KEYS.THEME, theme);
  },

  getVolume(): number {
    const v = localStorage.getItem(KEYS.VOLUME);
    return v !== null ? Number(v) : 0.8;
  },

  setVolume(volume: number) {
    localStorage.setItem(KEYS.VOLUME, String(volume));
  },

  getProfileName(): string {
    return localStorage.getItem('rotty_user_name') || '';
  },

  setProfileName(name: string) {
    localStorage.setItem('rotty_user_name', name.trim());
  },

  isSupporter(): boolean {
    return localStorage.getItem('rotty_is_supporter') === 'true';
  },

  setIsSupporter(val: boolean) {
    localStorage.setItem('rotty_is_supporter', String(val));
  },

  getStreakCount(): number {
    const count = localStorage.getItem('rotty_streak_count');
    return count ? Number(count) : 0;
  },

  hasListenedToday(): boolean {
    const lastDate = localStorage.getItem('rotty_streak_last_date');
    const today = new Date().toISOString().split('T')[0];
    return lastDate === today;
  },

  recordStreakDay() {
    const today = new Date();
    const todayKey = today.toISOString().split('T')[0];
    const lastDateKey = localStorage.getItem('rotty_streak_last_date');
    let count = this.getStreakCount();

    if (lastDateKey === todayKey) return;

    // Check if yesterday
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayKey = yesterday.toISOString().split('T')[0];

    if (lastDateKey === yesterdayKey) {
      count += 1;
    } else {
      count = 1;
    }

    localStorage.setItem('rotty_streak_last_date', todayKey);
    localStorage.setItem('rotty_streak_count', String(count));
  },

  clearUserSession() {
    localStorage.removeItem('rotty_user_uid');
    localStorage.removeItem('rotty_user_email');
    localStorage.removeItem('rotty_user_name');
    localStorage.removeItem(KEYS.LIKED_SONGS);
    localStorage.removeItem(KEYS.PLAYLISTS);
    localStorage.removeItem(KEYS.RECENT_SONGS);
    localStorage.removeItem('rotty_is_supporter');
  }
};
