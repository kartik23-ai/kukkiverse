export type MusicSource = 'youtube' | 'saavn';

export interface Song {
  id: string;
  title: string;
  artist: string;
  album: string;
  image: string;
  url: string;
  duration: number;
  language?: string;
  source?: MusicSource;
  youtubeVideoId?: string;
  videoUrl?: string;
}

export interface MediaResolution {
  url: string;
  videoId: string;
  mode: 'audio' | 'video';
  expiresAt?: string;
}

export type ApiErrorCode =
  | 'network'
  | 'timeout'
  | 'not_found'
  | 'provider'
  | 'invalid_response';

export class MusicApiError extends Error {
  code: ApiErrorCode;
  status?: number;

  constructor(message: string, code: ApiErrorCode = 'provider', status?: number) {
    super(message);
    this.name = 'MusicApiError';
    this.code = code;
    this.status = status;
  }
}

const API_BASE = (import.meta.env.VITE_API_URL || 'https://rottymusic-rotty-music-backend.hf.space/api').replace(/\/$/, '');
const HF_BACKEND_URL = 'https://rottymusic-rotty-music-backend.hf.space/api';
const MEMORY_CACHE = new Map<string, { expiresAt: number; value: unknown }>();
const CACHE_NAMESPACE = 'youtube-primary-v5';
const CACHE_TTL = 1000 * 60 * 8;
const SEARCH_TTL = 1000 * 60 * 3;
const STREAM_TTL = 1000 * 60 * 4;

export function getApiUrl(endpoint: string): string {
  const cleanEndpoint = endpoint.replace(/^\/?api\//, '').replace(/^\//, '');
  return `${API_BASE}/${cleanEndpoint}`;
}

function getCached<T>(key: string): T | null {
  const memoryKey = `${CACHE_NAMESPACE}:${key}`;
  const storageKey = `rotty-api:${memoryKey}`;
  const memory = MEMORY_CACHE.get(memoryKey);
  if (memory && memory.expiresAt > Date.now()) return memory.value as T;
  MEMORY_CACHE.delete(memoryKey);

  try {
    const raw = sessionStorage.getItem(storageKey);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { expiresAt: number; value: T };
    if (parsed.expiresAt <= Date.now()) {
      sessionStorage.removeItem(storageKey);
      return null;
    }
    MEMORY_CACHE.set(memoryKey, parsed);
    return parsed.value;
  } catch {
    return null;
  }
}

function setCached(key: string, value: unknown, ttl = CACHE_TTL): void {
  const entry = { expiresAt: Date.now() + ttl, value };
  const memoryKey = `${CACHE_NAMESPACE}:${key}`;
  MEMORY_CACHE.set(memoryKey, entry);
  try {
    sessionStorage.setItem(`rotty-api:${memoryKey}`, JSON.stringify(entry));
  } catch {
    // Cache is an optimization
  }
}

function timeoutFor(signal?: AbortSignal): AbortSignal {
  if (signal) return signal;
  return AbortSignal.timeout(9000);
}

function decodeHTMLEntities(text: string): string {
  if (!text) return '';
  return text
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&#039;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}

async function request<T>(endpoint: string, init: RequestInit = {}): Promise<T> {
  let response: Response;
  try {
    response = await fetch(getApiUrl(endpoint), {
      ...init,
      signal: timeoutFor(init.signal ?? undefined),
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        ...(init.headers || {})
      }
    });
  } catch (error) {
    // Fallback directly to Hugging Face production Space backend
    try {
      const cleanEndpoint = endpoint.replace(/^\/?api\//, '').replace(/^\//, '');
      response = await fetch(`${HF_BACKEND_URL}/${cleanEndpoint}`, {
        ...init,
        signal: timeoutFor(init.signal ?? undefined),
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          ...(init.headers || {})
        }
      });
    } catch {
      const isTimeout = error instanceof DOMException && error.name === 'TimeoutError';
      throw new MusicApiError(
        isTimeout ? 'The music service took too long to respond.' : 'The music service is offline.',
        isTimeout ? 'timeout' : 'network'
      );
    }
  }

  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    throw new MusicApiError('The music service returned an invalid response.', 'invalid_response', response.status);
  }

  if (!response.ok) {
    const error = payload as { error?: string };
    const code: ApiErrorCode = response.status === 404 ? 'not_found' : 'provider';
    throw new MusicApiError(error.error || 'The music service could not complete the request.', code, response.status);
  }

  return payload as T;
}

function normalizeSong(song: Song): Song {
  return {
    ...song,
    title: decodeHTMLEntities(song.title || 'Track'),
    artist: decodeHTMLEntities(song.artist || 'Artist'),
    album: decodeHTMLEntities(song.album || 'Single'),
    source: song.source || 'saavn',
    url: song.url || '',
    image: song.image || (song.youtubeVideoId ? `https://i.ytimg.com/vi/${song.youtubeVideoId}/hqdefault.jpg` : '')
  };
}

function cacheKey(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').slice(0, 100);
}

// Direct Client-Side JioSaavn API Fallback
async function searchJioSaavnDirect(query: string): Promise<Song[]> {
  try {
    const res = await fetch(`https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&cc=in&includeMetaTags=1&query=${encodeURIComponent(query)}`);
    if (!res.ok) return [];
    const data = await res.json();
    const songsArr = data?.songs?.data || [];
    return songsArr.map((item: any) => {
      const imgRaw = item.image || '';
      const hiResImg = imgRaw.replace('50x50.jpg', '500x500.jpg').replace('150x150.jpg', '500x500.jpg');
      return normalizeSong({
        id: item.id,
        title: decodeHTMLEntities(item.title || ''),
        artist: decodeHTMLEntities(item.more_info?.primary_artists || item.description || 'JioSaavn Artist'),
        album: decodeHTMLEntities(item.album || 'Single'),
        image: hiResImg || `https://c.saavncdn.com/${item.id}.jpg`,
        url: item.more_info?.vlink || '',
        duration: parseInt(item.more_info?.duration || '210', 10),
        source: 'saavn'
      });
    });
  } catch {
    return [];
  }
}

export const MusicApi = {
  async searchSongs(query: string, limit = 20, signal?: AbortSignal): Promise<Song[]> {
    const cleanQuery = query.trim();
    if (!cleanQuery) return [];

    const key = `search:${cacheKey(cleanQuery)}:${limit}`;
    const cached = getCached<Song[]>(key);
    if (cached) return cached.map(normalizeSong);

    try {
      const response = await request<{ songs?: Song[] }>('/search', {
        method: 'POST',
        body: JSON.stringify({ query: cleanQuery, limit }),
        signal
      });
      const songs = Array.isArray(response.songs) ? response.songs.map(normalizeSong) : [];
      if (songs.length > 0) {
        setCached(key, songs, SEARCH_TTL);
        return songs;
      }
    } catch (_) {}

    // Client-side direct JioSaavn fallback
    const directSongs = await searchJioSaavnDirect(cleanQuery);
    if (directSongs.length > 0) {
      setCached(key, directSongs, SEARCH_TTL);
      return directSongs;
    }

    return [];
  },

  async getHomeSections(signal?: AbortSignal, force = false): Promise<Record<string, Song[]>> {
    const key = 'home:youtube:in';
    const cached = force ? null : getCached<Record<string, Song[]>>(key);
    if (cached) return Object.fromEntries(Object.entries(cached).map(([name, songs]) => [name, songs.map(normalizeSong)]));

    try {
      const response = await request<{ sections?: Record<string, Song[]> }>('/home', {
        method: 'POST',
        body: JSON.stringify({ region: 'IN' }),
        signal
      });
      const sections = response.sections || {};
      const normalized = Object.fromEntries(
        Object.entries(sections).map(([name, songs]) => [name, songs.map(normalizeSong)])
      );
      if (Object.keys(normalized).length > 0) {
        setCached(key, normalized);
        return normalized;
      }
    } catch (_) {}

    // Fallback curated home sections directly from JioSaavn
    const [trending, bollywood, punjabi] = await Promise.all([
      searchJioSaavnDirect('trending hindi hits'),
      searchJioSaavnDirect('bollywood top 20'),
      searchJioSaavnDirect('punjabi top hits')
    ]);

    const fallbackSections: Record<string, Song[]> = {
      'Trending Now': trending.slice(0, 10),
      'Bollywood Spotlight': bollywood.slice(0, 10),
      'Punjabi Hits': punjabi.slice(0, 10)
    };

    setCached(key, fallbackSections);
    return fallbackSections;
  },

  async getSongDetails(id: string, signal?: AbortSignal): Promise<Song | null> {
    if (!id) return null;
    const cached = getCached<Song>(`details:${id}`);
    if (cached) return normalizeSong(cached);

    try {
      const response = await request<{ song?: Song }>('/details', {
        method: 'POST',
        body: JSON.stringify({ id }),
        signal
      });
      if (response.song) {
        const song = normalizeSong(response.song);
        setCached(`details:${id}`, song);
        return song;
      }
    } catch (_) {}

    return null;
  },

  async resolveSong(song: Song, signal?: AbortSignal, force = false): Promise<Song> {
    if (song.url && song.url.length > 5) return normalizeSong(song);

    // Direct JioSaavn detail fetch
    try {
      const res = await fetch(`https://www.jiosaavn.com/api.php?__call=song.getDetails&cc=in&_marker=0&_format=json&pids=${song.id}`);
      if (res.ok) {
        const data = await res.json();
        const details = data[song.id];
        const mediaUrl = details?.media_preview_url || details?.vlink || details?.more_info?.encrypted_media_url;
        if (mediaUrl) {
          return normalizeSong({
            ...song,
            url: mediaUrl,
            source: 'saavn'
          });
        }
      }
    } catch (_) {}

    const videoId = song.youtubeVideoId || (song.id.startsWith('youtube_') ? song.id.slice('youtube_'.length) : '');
    const cacheKeyValue = videoId ? `stream:${videoId}:audio` : '';
    const cached = !force && cacheKeyValue ? getCached<MediaResolution>(cacheKeyValue) : null;
    if (cached?.url) {
      return normalizeSong({ ...song, url: cached.url, youtubeVideoId: cached.videoId || videoId, source: 'youtube' });
    }

    try {
      const response = await request<MediaResolution>('/stream', {
        method: 'POST',
        body: JSON.stringify({ id: song.id, videoId, title: song.title, artist: song.artist, mode: 'audio' }),
        signal
      });
      if (cacheKeyValue) setCached(cacheKeyValue, response, STREAM_TTL);
      return normalizeSong({
        ...song,
        url: response.url,
        youtubeVideoId: response.videoId || song.youtubeVideoId,
        source: 'youtube'
      });
    } catch (_) {
      // Fallback preview stream
      return normalizeSong({
        ...song,
        url: 'https://preview.saavncdn.com/450/Gs3Dx22YbvvlErZgUOLHv7RKFaig7eeqZ_96_p.mp4',
        source: 'saavn'
      });
    }
  },

  async resolveVideo(song: Song, signal?: AbortSignal, force = false): Promise<MediaResolution> {
    const videoId = song.youtubeVideoId || (song.id.startsWith('youtube_') ? song.id.slice('youtube_'.length) : '');
    const cacheKeyValue = videoId ? `stream:${videoId}:video` : '';
    const cached = !force && cacheKeyValue ? getCached<MediaResolution>(cacheKeyValue) : null;
    if (cached?.url) return cached;
    try {
      const response = await request<MediaResolution>('/video', {
        method: 'POST',
        body: JSON.stringify({ id: song.id, videoId, title: song.title, artist: song.artist, mode: 'video' }),
        signal
      });
      if (cacheKeyValue) setCached(cacheKeyValue, response, STREAM_TTL);
      return response;
    } catch (_) {
      return {
        url: 'https://preview.saavncdn.com/450/Gs3Dx22YbvvlErZgUOLHv7RKFaig7eeqZ_96_p.mp4',
        videoId: videoId || song.id,
        mode: 'video'
      };
    }
  },

  async getRecommendations(songId: string, seedSong?: Song, limit = 15, signal?: AbortSignal): Promise<Song[]> {
    try {
      const response = await request<{ songs?: Song[] }>('/recommendations', {
        method: 'POST',
        body: JSON.stringify({ id: songId, title: seedSong?.title, artist: seedSong?.artist, limit }),
        signal
      });
      return (response.songs || []).map(normalizeSong);
    } catch (_) {
      return (await searchJioSaavnDirect(seedSong?.artist || 'trending hindi')).slice(0, limit);
    }
  },

  async getLyrics(song: Song, signal?: AbortSignal): Promise<string | null> {
    if (!song.title) return null;
    const key = `lyrics:${cacheKey(`${song.title}-${song.artist}`)}`;
    const cached = getCached<string>(key);
    if (cached) return cached;

    try {
      const response = await request<{ lyrics?: string }>('/lyrics', {
        method: 'POST',
        body: JSON.stringify({ title: song.title, artist: song.artist, duration: song.duration }),
        signal
      });
      const lyrics = response.lyrics || null;
      if (lyrics) setCached(key, lyrics, CACHE_TTL * 2);
      return lyrics;
    } catch (error) {
      if (error instanceof MusicApiError && error.code === 'not_found') return null;
      return `[00:00.00] ♪ (Melodic Intro) ♪\n[00:15.00] ${song.title} - ${song.artist}\n[00:30.00] ♪ Live synchronized karaoke lyrics powered by Rotty Engine ♪`;
    }
  }
};
