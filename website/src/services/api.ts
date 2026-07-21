export interface Song {
  id: string;
  title: string;
  artist: string;
  album: string;
  image: string;
  url: string;
  duration: number; // in seconds
  language?: string;
  source?: 'saavn' | 'youtube';
}

const isLocal = typeof window !== 'undefined' && 
  (window.location.hostname === 'localhost' || 
   window.location.hostname === '127.0.0.1' || 
   window.location.hostname.startsWith('192.168.'));

// Production Hugging Face Backend URL
const BACKEND_URL = 'https://rottymusic-rotty-music-backend.hf.space/api';
const API_BASE = isLocal ? '/api' : (import.meta.env.VITE_API_URL || BACKEND_URL);

export function getApiUrl(endpoint: string): string {
  if (endpoint.startsWith('http')) return endpoint;
  const clean = endpoint.startsWith('/') ? endpoint.slice(1) : endpoint;
  const finalEndpoint = clean.startsWith('api/') ? clean.slice(4) : clean;
  return `${API_BASE}/${finalEndpoint}`;
}

// AES-256-CBC Decryption helper using native Web Crypto API
export async function decryptPayload(payload: string): Promise<string> {
  if (!payload) return '';
  try {
    const parts = payload.split(':');
    if (parts.length !== 2) return '';
    
    const base64ToBytes = (base64Str: string) => {
      const binary = atob(base64Str);
      const len = binary.length;
      const bytes = new Uint8Array(len);
      for (let i = 0; i < len; i++) {
        bytes[i] = binary.charCodeAt(i);
      }
      return bytes;
    };
    
    const ivBytes = base64ToBytes(parts[0]);
    const cipherBytes = base64ToBytes(parts[1]);
    
    let secretKey = import.meta.env.VITE_ROTTY_SECRET_KEY || 'R0ttyGh0st2026xKr7mP9qW4vZ8nB3j';
    secretKey = secretKey.slice(0, 32).padEnd(32, '0');
    const keyBytes = new TextEncoder().encode(secretKey);
    
    const cryptoKey = await window.crypto.subtle.importKey(
      'raw',
      keyBytes,
      { name: 'AES-CBC' },
      false,
      ['decrypt']
    );
    
    const decrypted = await window.crypto.subtle.decrypt(
      { name: 'AES-CBC', iv: ivBytes },
      cryptoKey,
      cipherBytes
    );
    
    return new TextDecoder().decode(decrypted);
  } catch (e) {
    console.error('[GhostProxy] Decryption error:', e);
    return '';
  }
}

function cleanText(str: string = ''): string {
  return str
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&#039;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}

// Direct Official JioSaavn Client-Side Fallback
async function searchSaavnDirect(query: string): Promise<Song[]> {
  try {
    const url = `https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&cc=in&includeMetaTags=1&query=${encodeURIComponent(query)}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(4000) });
    if (res.ok) {
      const data = await res.json();
      const songs = data?.songs?.data || [];
      return songs.map((s: any) => {
        const highResImg = (s.image || '')
          .replace('50x50.jpg', '500x500.jpg')
          .replace('150x150.jpg', '500x500.jpg');
        return {
          id: s.id,
          title: cleanText(s.title),
          artist: cleanText(s.more_info?.primary_artists || s.description || 'JioSaavn Artist'),
          album: cleanText(s.album || 'Single'),
          image: highResImg || `https://c.saavncdn.com/${s.id}.jpg`,
          url: s.more_info?.vlink || '',
          duration: 210,
          language: s.more_info?.language || 'hindi',
          source: 'saavn'
        };
      });
    }
  } catch (e) {
    console.warn('Saavn direct search failed:', e);
  }
  return [];
}

async function getSaavnDetailsDirect(id: string): Promise<Song | null> {
  try {
    const url = `https://www.jiosaavn.com/api.php?__call=song.getDetails&cc=in&_marker=0&_format=json&pids=${id}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(4000) });
    if (res.ok) {
      const data = await res.json();
      const s = data[id];
      if (s) {
        const audioStream = s.media_preview_url || s.vlink;
        const highResImg = (s.image || '')
          .replace('150x150.jpg', '500x500.jpg')
          .replace('50x50.jpg', '500x500.jpg');
        return {
          id: s.id,
          title: cleanText(s.song),
          artist: cleanText(s.primary_artists || s.singers || 'JioSaavn Artist'),
          album: cleanText(s.album || 'Single'),
          image: highResImg,
          url: audioStream || '',
          duration: parseInt(s.duration || '210', 10),
          language: s.language,
          source: 'saavn'
        };
      }
    }
  } catch (e) {
    console.warn('Saavn direct details failed:', e);
  }
  return null;
}

export const MusicApi = {
  async searchSongs(query: string, limit = 20): Promise<Song[]> {
    if (!query || query.trim() === '') return [];
    try {
      const res = await fetch(getApiUrl('/api/search'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: query.trim(), limit }),
        signal: AbortSignal.timeout(3500)
      });
      if (res.ok) {
        const json = await res.json();
        if (json.d) {
          const decrypted = await decryptPayload(json.d);
          if (decrypted) {
            const list = JSON.parse(decrypted);
            if (Array.isArray(list) && list.length > 0) return list;
          }
        }
      }
    } catch (e) {
      console.warn('[GhostProxy] Search proxy failed, attempting direct Saavn query:', e);
    }
    // Direct Fallback
    return searchSaavnDirect(query);
  },

  async getHomeSections(): Promise<Record<string, Song[]>> {
    try {
      const res = await fetch(getApiUrl('/api/home'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
        signal: AbortSignal.timeout(3500)
      });
      if (res.ok) {
        const json = await res.json();
        if (json.d) {
          const decrypted = await decryptPayload(json.d);
          if (decrypted) {
            const sections = JSON.parse(decrypted);
            if (sections && Object.keys(sections).length > 0) return sections;
          }
        }
      }
    } catch (e) {
      console.warn('[GhostProxy] Home proxy failed, generating fallback sections:', e);
    }

    const [trending, romantic, punjabi] = await Promise.all([
      searchSaavnDirect('trending hindi 2026'),
      searchSaavnDirect('arijit singh love songs'),
      searchSaavnDirect('punjabi top hits')
    ]);

    return {
      'Trending Now 🇮🇳': trending,
      'Romantic Melodies ❤️': romantic,
      'Punjabi Hits 🔥': punjabi
    };
  },

  async getSongDetails(id: string): Promise<Song | null> {
    try {
      const res = await fetch(getApiUrl('/api/details'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
        signal: AbortSignal.timeout(3500)
      });
      if (res.ok) {
        const json = await res.json();
        if (json.d) {
          const decrypted = await decryptPayload(json.d);
          if (decrypted) {
            const song = JSON.parse(decrypted);
            if (song && song.id) return song;
          }
        }
      }
    } catch (e) {
      console.warn('[GhostProxy] Details proxy failed, fetching direct details:', e);
    }
    return getSaavnDetailsDirect(id);
  },

  async resolveSong(song: Song): Promise<Song> {
    if (!song.url || song.url.trim() === '') {
      const details = await this.getSongDetails(song.id);
      if (details && details.url) {
        return {
          ...song,
          url: details.url,
          duration: details.duration || song.duration
        };
      }
    }
    return song;
  },

  async getRecommendations(songId: string, seedSong?: Song, limit = 15): Promise<Song[]> {
    if (!songId) return [];
    try {
      const res = await fetch(getApiUrl('/api/recommendations'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: songId, limit }),
        signal: AbortSignal.timeout(3500)
      });
      if (res.ok) {
        const json = await res.json();
        if (json.d) {
          const decrypted = await decryptPayload(json.d);
          if (decrypted) {
            const list = JSON.parse(decrypted);
            if (Array.isArray(list) && list.length > 0) return list;
          }
        }
      }
    } catch (_) {}

    if (seedSong) {
      const query = seedSong.artist.split(',')[0].trim() || seedSong.title;
      return searchSaavnDirect(query);
    }
    return [];
  },

  async getLyrics(song: Song): Promise<string | null> {
    if (!song.title) return null;
    try {
      const res = await fetch(getApiUrl('/api/lyrics'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: song.title, artist: song.artist }),
        signal: AbortSignal.timeout(3500)
      });
      if (res.ok) {
        const json = await res.json();
        if (json.d) {
          const decrypted = await decryptPayload(json.d);
          return decrypted || null;
        }
      }
    } catch (_) {}
    return null;
  }
};
