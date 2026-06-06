export interface Song {
  id: string;
  title: string;
  artist: string;
  album: string;
  image: string;
  url: string;
  duration: number; // in seconds
  language?: string;
}

const isLocal = typeof window !== 'undefined' && 
  (window.location.hostname === 'localhost' || 
   window.location.hostname === '127.0.0.1' || 
   window.location.hostname.startsWith('192.168.'));

// Dynamic base URL fallback: uses local proxy in development, absolute Railway url in production
const API_BASE = isLocal ? '/api' : (import.meta.env.VITE_API_URL || 'https://kukkiverse-production.up.railway.app/api');

export function getApiUrl(endpoint: string): string {
  if (endpoint.startsWith('http')) return endpoint;
  const clean = endpoint.startsWith('/') ? endpoint.slice(1) : endpoint;
  const finalEndpoint = clean.startsWith('api/') ? clean.slice(4) : clean;
  return `${API_BASE}/${finalEndpoint}`;
}

// AES-256-CBC Decryption helper using the browser's native Web Crypto API
export async function decryptPayload(payload: string): Promise<string> {
  if (!payload) return '';
  try {
    const parts = payload.split(':');
    if (parts.length !== 2) return '';
    
    // Helper to decode base64 to Uint8Array
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
    
    // Import raw key data into SubtleCrypto key
    const cryptoKey = await window.crypto.subtle.importKey(
      'raw',
      keyBytes,
      { name: 'AES-CBC' },
      false,
      ['decrypt']
    );
    
    // Decrypt the ciphertext
    const decrypted = await window.crypto.subtle.decrypt(
      {
        name: 'AES-CBC',
        iv: ivBytes
      },
      cryptoKey,
      cipherBytes
    );
    
    return new TextDecoder().decode(decrypted);
  } catch (e) {
    console.error('[GhostProxy] Decryption error:', e);
    return '';
  }
}

// Obfuscate song CDN streaming URL to proxy it through localhost/dev server
function obfuscateMediaUrl(url: string): string {
  if (!url) return '';
  
  const isLocal = typeof window !== 'undefined' && 
    (window.location.hostname === 'localhost' || 
     window.location.hostname === '127.0.0.1' || 
     window.location.hostname.startsWith('192.168.'));
     
  if (isLocal) {
    return url
      .replace('https://aac.saavncdn.com/', '/api-media/')
      .replace('http://aac.saavncdn.com/', '/api-media/');
  }
  return url;
}

export const MusicApi = {
  async searchSongs(query: string, limit = 20): Promise<Song[]> {
    if (!query || query.trim() === '') return [];
    try {
      const res = await fetch(getApiUrl('/api/search'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: query.trim(), limit })
      });
      if (!res.ok) throw new Error('Proxy search request failed');
      const json = await res.json();
      if (!json.d) return [];
      
      const decrypted = await decryptPayload(json.d);
      if (!decrypted) return [];
      
      const list = JSON.parse(decrypted);
      return Array.isArray(list) ? list.map((item: any) => ({
        ...item,
        url: obfuscateMediaUrl(item.url)
      })) : [];
    } catch (e) {
      console.error('[GhostProxy] Error searching songs:', e);
      return [];
    }
  },

  async getHomeSections(): Promise<Record<string, Song[]>> {
    try {
      const res = await fetch(getApiUrl('/api/home'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
      });
      if (!res.ok) throw new Error('Proxy home request failed');
      const json = await res.json();
      if (!json.d) return {};
      
      const decrypted = await decryptPayload(json.d);
      if (!decrypted) return {};
      
      const sections = JSON.parse(decrypted);
      const parsed: Record<string, Song[]> = {};
      
      for (const [title, list] of Object.entries(sections)) {
        if (Array.isArray(list)) {
          parsed[title] = list.map((item: any) => ({
            ...item,
            url: obfuscateMediaUrl(item.url)
          }));
        }
      }
      return parsed;
    } catch (e) {
      console.error('[GhostProxy] Error fetching home sections:', e);
      return {};
    }
  },

  async getSongDetails(id: string): Promise<Song | null> {
    try {
      const res = await fetch(getApiUrl('/api/details'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id })
      });
      if (!res.ok) throw new Error('Proxy details request failed');
      const json = await res.json();
      if (!json.d) return null;
      
      const decrypted = await decryptPayload(json.d);
      if (!decrypted) return null;
      
      const song = JSON.parse(decrypted);
      if (song && song.id) {
        return {
          ...song,
          url: obfuscateMediaUrl(song.url)
        };
      }
      return null;
    } catch (e) {
      console.error('[GhostProxy] Error fetching song details:', e);
      return null;
    }
  },

  async resolveSong(song: Song): Promise<Song> {
    // 1. If it's a Spotify track, resolve by searching Saavn catalog
    if (song.id.startsWith('spotify_track_')) {
      const query = `${song.title} ${song.artist}`;
      try {
        console.log(`[GhostProxy] Resolving Spotify track: "${query}"`);
        const results = await this.searchSongs(query, 1);
        if (results.length > 0) {
          const matched = results[0];
          const details = await this.getSongDetails(matched.id);
          if (details && details.url) {
            console.log(`[GhostProxy] Resolved "${query}" to secure URL`);
            return {
              ...song,
              url: obfuscateMediaUrl(details.url),
              duration: details.duration || song.duration,
            };
          }
        }
      } catch (e) {
        console.error('[GhostProxy] Error resolving Spotify song:', e);
      }
    }
    
    // 2. If it is a normal Saavn song but lacks a URL (stale/saved song)
    if (!song.url) {
      try {
        console.log(`[GhostProxy] Resolving Saavn song details directly: ${song.title} (${song.id})`);
        const details = await this.getSongDetails(song.id);
        if (details && details.url) {
          return {
            ...song,
            url: obfuscateMediaUrl(details.url),
            duration: details.duration || song.duration
          };
        }
      } catch (e) {
        console.error('[GhostProxy] Error resolving Saavn details:', e);
      }
    }
    
    return {
      ...song,
      url: obfuscateMediaUrl(song.url)
    };
  },

  async getRecommendations(songId: string, seedSong?: Song, limit = 15): Promise<Song[]> {
    if (!songId) return [];
    
    try {
      const res = await fetch(getApiUrl('/api/recommendations'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: songId, limit })
      });
      if (res.ok) {
        const json = await res.json();
        if (json.d) {
          const decrypted = await decryptPayload(json.d);
          if (decrypted) {
            const list = JSON.parse(decrypted);
            if (Array.isArray(list)) {
              return list.map((item: any) => ({
                ...item,
                url: obfuscateMediaUrl(item.url)
              }));
            }
          }
        }
      }
    } catch (_) {}
    
    // Fallback: search for songs by primary artist
    if (seedSong) {
      const artist = seedSong.artist.split(',')[0].trim();
      const query = artist || seedSong.title;
      return this.searchSongs(query, limit);
    }
    return [];
  },

  async getLyrics(song: Song): Promise<string | null> {
    if (!song.title) return null;
    try {
      const res = await fetch(getApiUrl('/api/lyrics'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: song.title,
          artist: song.artist,
          duration: song.duration
        })
      });
      if (!res.ok) throw new Error('Proxy lyrics request failed');
      const json = await res.json();
      if (!json.d) return null;
      
      const decrypted = await decryptPayload(json.d);
      return decrypted || null;
    } catch (e) {
      console.error('[GhostProxy] Error fetching lyrics:', e);
      return null;
    }
  }
};
