export type MusicSource = 'youtube';

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

const HF_BACKEND_URL = 'https://rottymusic-rotty-music-backend.hf.space/api';
const MEMORY_CACHE = new Map<string, { expiresAt: number; value: unknown }>();
const CACHE_NAMESPACE = 'rotty-youtube-v10';
const CACHE_TTL = 1000 * 60 * 10;

export function getApiUrl(endpoint: string): string {
  const cleanEndpoint = endpoint.replace(/^\/?api\//, '').replace(/^\//, '');
  return `${HF_BACKEND_URL}/${cleanEndpoint}`;
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

function getCached<T>(key: string): T | null {
  const memoryKey = `${CACHE_NAMESPACE}:${key}`;
  const memory = MEMORY_CACHE.get(memoryKey);
  if (memory && memory.expiresAt > Date.now()) return memory.value as T;
  MEMORY_CACHE.delete(memoryKey);
  try {
    const raw = sessionStorage.getItem(`rotty-api:${memoryKey}`);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { expiresAt: number; value: T };
    if (parsed.expiresAt <= Date.now()) {
      sessionStorage.removeItem(`rotty-api:${memoryKey}`);
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
  } catch {}
}

// 100% Dynamic YouTube Search Scraper (Live Direct Request)
async function searchYouTubeDynamic(query: string): Promise<Song[]> {
  const cleanQuery = query.trim();
  if (!cleanQuery) return [];

  const cached = getCached<Song[]>(`yt_search:${cleanQuery}`);
  if (cached) return cached;

  // 1. Try Hugging Face production Space YouTube backend endpoint
  try {
    const res = await fetch(`${HF_BACKEND_URL}/search`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: cleanQuery, limit: 18 })
    });
    if (res.ok) {
      const data = await res.json();
      const songs = (data.songs || []).map((s: Song) => ({
        ...s,
        id: s.id.startsWith('youtube_') ? s.id : `youtube_${s.id}`,
        youtubeVideoId: s.youtubeVideoId || s.id.replace('youtube_', ''),
        title: decodeHTMLEntities(s.title),
        artist: decodeHTMLEntities(s.artist),
        album: decodeHTMLEntities(s.album || 'YouTube Music'),
        source: 'youtube' as const
      }));
      if (songs.length > 0) {
        setCached(`yt_search:${cleanQuery}`, songs);
        return songs;
      }
    }
  } catch (_) {}

  // 2. Try Invidious public CORS API search instances
  const invidiousInstances = [
    'https://invidious.nerdvpn.de',
    'https://inv.tux.pizza',
    'https://vid.puffyan.us'
  ];
  for (const inst of invidiousInstances) {
    try {
      const res = await fetch(`${inst}/api/v1/search?q=${encodeURIComponent(cleanQuery)}&type=video`);
      if (res.ok) {
        const items = await res.json();
        if (Array.isArray(items) && items.length > 0) {
          const songs: Song[] = items.slice(0, 18).map((item: any) => ({
            id: `youtube_${item.videoId}`,
            youtubeVideoId: item.videoId,
            title: decodeHTMLEntities(item.title || 'YouTube Track'),
            artist: decodeHTMLEntities(item.author || 'YouTube Artist'),
            album: 'YouTube Music',
            image: item.videoThumbnails?.slice(-1)[0]?.url || `https://i.ytimg.com/vi/${item.videoId}/hqdefault.jpg`,
            url: '',
            duration: item.lengthSeconds || 210,
            source: 'youtube' as const
          }));
          setCached(`yt_search:${cleanQuery}`, songs);
          return songs;
        }
      }
    } catch (_) {}
  }

  return [];
}

export const MusicApi = {
  async searchSongs(query: string, limit = 20, _signal?: AbortSignal): Promise<Song[]> {
    const cleanQuery = query.trim();
    if (!cleanQuery) return await searchYouTubeDynamic('new hindi songs 2026 hits');
    const songs = await searchYouTubeDynamic(cleanQuery);
    return songs.slice(0, limit);
  },

  async getHomeSections(_signal?: AbortSignal, force = false): Promise<Record<string, Song[]>> {
    const cached = force ? null : getCached<Record<string, Song[]>>('yt_home_sections');
    if (cached) return cached;

    const [trending, bollywood, punjabi, lofi] = await Promise.all([
      searchYouTubeDynamic('trending hindi songs 2026'),
      searchYouTubeDynamic('top bollywood songs 2026'),
      searchYouTubeDynamic('punjabi hit songs 2026'),
      searchYouTubeDynamic('lofi hindi songs chill beats')
    ]);

    const sections: Record<string, Song[]> = {
      '🔥 Trending YouTube Hits 2026': trending,
      '🎬 Top Bollywood Spotlight': bollywood,
      '🎹 Punjabi Party 2026': punjabi,
      '☕ Midnight Lo-Fi & Chill': lofi
    };

    setCached('yt_home_sections', sections);
    return sections;
  },

  async getSongDetails(id: string, _signal?: AbortSignal): Promise<Song | null> {
    if (!id) return null;
    const videoId = id.startsWith('youtube_') ? id.slice(8) : id;
    const cached = getCached<Song>(`yt_details:${videoId}`);
    if (cached) return cached;

    const song: Song = {
      id: `youtube_${videoId}`,
      youtubeVideoId: videoId,
      title: 'YouTube Track',
      artist: 'YouTube Music',
      album: 'YouTube Music',
      image: `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
      url: '',
      duration: 210,
      source: 'youtube'
    };
    setCached(`yt_details:${videoId}`, song);
    return song;
  },

  async resolveSong(song: Song, _signal?: AbortSignal, force = false): Promise<Song> {
    if (song.url && song.url.length > 10) return song;

    const videoId = song.youtubeVideoId || (song.id.startsWith('youtube_') ? song.id.slice(8) : song.id);
    const cacheKey = `yt_stream:${videoId}:audio`;
    const cached = !force ? getCached<MediaResolution>(cacheKey) : null;
    if (cached?.url) {
      return {
        ...song,
        url: cached.url,
        youtubeVideoId: videoId,
        source: 'youtube'
      };
    }

    // Resolve audio stream via Hugging Face backend proxy
    try {
      const res = await fetch(`${HF_BACKEND_URL}/stream`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: song.id, videoId, title: song.title, artist: song.artist, mode: 'audio' })
      });
      if (res.ok) {
        const data = await res.json();
        if (data.url) {
          setCached(cacheKey, data);
          return {
            ...song,
            url: data.url,
            youtubeVideoId: videoId,
            source: 'youtube'
          };
        }
      }
    } catch (_) {}

    // Fallback Invidious audio stream URL
    try {
      const res = await fetch(`https://invidious.nerdvpn.de/api/v1/videos/${videoId}`);
      if (res.ok) {
        const data = await res.json();
        const audioFormat = (data.adaptiveFormats || []).find((f: any) => f.type && f.type.includes('audio'));
        if (audioFormat && audioFormat.url) {
          return {
            ...song,
            url: audioFormat.url,
            youtubeVideoId: videoId,
            source: 'youtube'
          };
        }
      }
    } catch (_) {}

    return {
      ...song,
      youtubeVideoId: videoId,
      source: 'youtube'
    };
  },

  async resolveVideo(song: Song, _signal?: AbortSignal, force = false): Promise<MediaResolution> {
    const videoId = song.youtubeVideoId || (song.id.startsWith('youtube_') ? song.id.slice(8) : song.id);
    const cacheKey = `yt_stream:${videoId}:video`;
    const cached = !force ? getCached<MediaResolution>(cacheKey) : null;
    if (cached?.url) return cached;

    try {
      const res = await fetch(`${HF_BACKEND_URL}/video`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: song.id, videoId, title: song.title, artist: song.artist, mode: 'video' })
      });
      if (res.ok) {
        const data = await res.json();
        setCached(cacheKey, data);
        return data;
      }
    } catch (_) {}

    return {
      url: '',
      videoId,
      mode: 'video'
    };
  },

  async getRecommendations(songId?: string, seedSong?: Song, limit = 15, _signal?: AbortSignal): Promise<Song[]> {
    const query = seedSong?.artist || seedSong?.title || songId || 'trending hindi songs';
    const songs = await searchYouTubeDynamic(query);
    return songs.slice(0, limit);
  },

  async getLyrics(song: Song, _signal?: AbortSignal): Promise<string | null> {
    try {
      const res = await fetch(`${HF_BACKEND_URL}/lyrics`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: song.title, artist: song.artist, duration: song.duration })
      });
      if (res.ok) {
        const data = await res.json();
        if (data.lyrics) return data.lyrics;
      }
    } catch (_) {}

    return `[00:00.00] ♪ (YouTube Music Symphony) ♪\n[00:15.00] ${song.title} - ${song.artist}\n[00:30.00] ♪ Live synchronized lyrics powered by Rotty Engine ♪`;
  }
};
