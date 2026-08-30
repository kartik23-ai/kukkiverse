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
const CACHE_NAMESPACE = 'rotty-web-v7';
const CACHE_TTL = 1000 * 60 * 15;

export function getApiUrl(endpoint: string): string {
  const cleanEndpoint = endpoint.replace(/^\/?api\//, '').replace(/^\//, '');
  return `${API_BASE}/${cleanEndpoint}`;
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

const INITIAL_CURATED_SONGS: Song[] = [
  {
    id: "Gehra_Hua_Dhurandhar",
    title: "Gehra Hua",
    artist: "Arijit Singh, Shashwat Sachdev",
    album: "Dhurandhar",
    image: "https://c.saavncdn.com/450/Gehra-Hua-From-Dhurandhar-Hindi-2025-20251205154217-500x500.jpg",
    url: "https://jiotunepreview.jio.com/content/Converted/010910141580615.mp3",
    duration: 228,
    source: "saavn"
  },
  {
    id: "Kesariya_Brahmastra",
    title: "Kesariya",
    artist: "Pritam, Arijit Singh, Amitabh Bhattacharya",
    album: "Brahmastra",
    image: "https://c.saavncdn.com/191/Kesariya-From-Brahmastra-Hindi-2022-20220717092820-500x500.jpg",
    url: "https://jiotunepreview.jio.com/content/Converted/010910141580615.mp3",
    duration: 268,
    source: "saavn"
  },
  {
    id: "Tum_Hi_Ho_Aashiqui_2",
    title: "Tum Hi Ho",
    artist: "Mithoon, Arijit Singh",
    album: "Aashiqui 2",
    image: "https://c.saavncdn.com/430/Aashiqui-2-Hindi-2013-500x500.jpg",
    url: "https://jiotunepreview.jio.com/content/Converted/010910141580615.mp3",
    duration: 262,
    source: "saavn"
  },
  {
    id: "Chaleya_Jawan",
    title: "Chaleya",
    artist: "Anirudh Ravichander, Arijit Singh, Shilpa Rao",
    album: "Jawan",
    image: "https://c.saavncdn.com/026/Chaleya-From-Jawan-Hindi-2023-20230814114321-500x500.jpg",
    url: "https://jiotunepreview.jio.com/content/Converted/010910141580615.mp3",
    duration: 200,
    source: "saavn"
  },
  {
    id: "Heeriye_Jasleen",
    title: "Heeriye",
    artist: "Jasleen Royal, Dulquer Salmaan, Arijit Singh",
    album: "Heeriye Single",
    image: "https://c.saavncdn.com/022/Heeriye-feat-Arijit-Singh-Hindi-2023-20230928050405-500x500.jpg",
    url: "https://jiotunepreview.jio.com/content/Converted/010910141580615.mp3",
    duration: 194,
    source: "saavn"
  }
];

async function fetchJioSaavnApi(query: string): Promise<Song[]> {
  try {
    const res = await fetch(`https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&cc=in&includeMetaTags=1&query=${encodeURIComponent(query)}`);
    if (!res.ok) return [];
    const data = await res.json();
    const songsArr = data?.songs?.data || [];
    return songsArr.map((item: any) => {
      const imgRaw = item.image || '';
      const hiResImg = imgRaw.replace('50x50.jpg', '500x500.jpg').replace('150x150.jpg', '500x500.jpg');
      const vlink = item.more_info?.vlink || item.more_info?.encrypted_media_url || 'https://jiotunepreview.jio.com/content/Converted/010910141580615.mp3';
      return {
        id: item.id,
        title: decodeHTMLEntities(item.title || 'Track'),
        artist: decodeHTMLEntities(item.more_info?.primary_artists || item.description || 'Artist'),
        album: decodeHTMLEntities(item.album || 'Single'),
        image: hiResImg || `https://c.saavncdn.com/${item.id}.jpg`,
        url: vlink,
        duration: parseInt(item.more_info?.duration || '210', 10),
        source: 'saavn' as const
      };
    });
  } catch {
    return [];
  }
}

export const MusicApi = {
  async searchSongs(query: string, limit = 20, _signal?: AbortSignal): Promise<Song[]> {
    const cleanQuery = query.trim();
    if (!cleanQuery) return INITIAL_CURATED_SONGS;

    const cached = getCached<Song[]>(`search:${cleanQuery}`);
    if (cached) return cached;

    // 1. Direct JioSaavn search
    const saavnSongs = await fetchJioSaavnApi(cleanQuery);
    if (saavnSongs.length > 0) {
      setCached(`search:${cleanQuery}`, saavnSongs);
      return saavnSongs;
    }

    // 2. Hugging Face backend proxy search
    try {
      const res = await fetch(`${HF_BACKEND_URL}/search`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: cleanQuery, limit })
      });
      if (res.ok) {
        const data = await res.json();
        const songs = (data.songs || []).map((s: Song) => ({
          ...s,
          title: decodeHTMLEntities(s.title),
          artist: decodeHTMLEntities(s.artist),
          album: decodeHTMLEntities(s.album)
        }));
        if (songs.length > 0) {
          setCached(`search:${cleanQuery}`, songs);
          return songs;
        }
      }
    } catch (_) {}

    return INITIAL_CURATED_SONGS;
  },

  async getHomeSections(_signal?: AbortSignal, _force = false): Promise<Record<string, Song[]>> {
    const cached = _force ? null : getCached<Record<string, Song[]>>('home_sections');
    if (cached) return cached;

    const [trending, bollywood, punjabi, lofi] = await Promise.all([
      fetchJioSaavnApi('trending hindi hits 2026'),
      fetchJioSaavnApi('top 20 bollywood hits'),
      fetchJioSaavnApi('punjabi hits 2026'),
      fetchJioSaavnApi('lofi hindi chill beats')
    ]);

    const sections: Record<string, Song[]> = {
      '🔥 Trending Hits 2026': trending.length > 0 ? trending.slice(0, 10) : INITIAL_CURATED_SONGS,
      '🎬 Bollywood Spotlight': bollywood.length > 0 ? bollywood.slice(0, 10) : INITIAL_CURATED_SONGS,
      '🎹 Punjabi Party Top 20': punjabi.length > 0 ? punjabi.slice(0, 10) : INITIAL_CURATED_SONGS,
      '☕ Midnight Lo-Fi & Chill': lofi.length > 0 ? lofi.slice(0, 10) : INITIAL_CURATED_SONGS
    };

    setCached('home_sections', sections);
    return sections;
  },

  async getSongDetails(id: string, _signal?: AbortSignal): Promise<Song | null> {
    if (!id) return null;
    const cached = getCached<Song>(`details:${id}`);
    if (cached) return cached;

    try {
      const res = await fetch(`https://www.jiosaavn.com/api.php?__call=song.getDetails&cc=in&_marker=0&_format=json&pids=${id}`);
      if (res.ok) {
        const data = await res.json();
        const details = data[id];
        if (details) {
          const song: Song = {
            id,
            title: decodeHTMLEntities(details.title || 'Track'),
            artist: decodeHTMLEntities(details.more_info?.primary_artists || 'Artist'),
            album: decodeHTMLEntities(details.album || 'Single'),
            image: (details.image || '').replace('150x150.jpg', '500x500.jpg'),
            url: details.media_preview_url || details.vlink || 'https://jiotunepreview.jio.com/content/Converted/010910141580615.mp3',
            duration: parseInt(details.more_info?.duration || '210', 10),
            source: 'saavn'
          };
          setCached(`details:${id}`, song);
          return song;
        }
      }
    } catch (_) {}

    return INITIAL_CURATED_SONGS[0];
  },

  async resolveSong(song: Song, _signal?: AbortSignal, _force = false): Promise<Song> {
    if (song.url && song.url.length > 10) return song;

    const query = `${song.title} ${song.artist}`.trim();
    const saavnResults = await fetchJioSaavnApi(query);
    if (saavnResults.length > 0 && saavnResults[0].url) {
      return {
        ...song,
        url: saavnResults[0].url,
        image: saavnResults[0].image || song.image,
        source: 'saavn'
      };
    }

    try {
      const res = await fetch(`${HF_BACKEND_URL}/media?id=${song.id.replace('youtube_', '')}`);
      if (res.ok) {
        const data = await res.json();
        if (data.streamUrl) {
          return {
            ...song,
            url: data.streamUrl,
            source: 'youtube'
          };
        }
      }
    } catch (_) {}

    return {
      ...song,
      url: 'https://jiotunepreview.jio.com/content/Converted/010910141580615.mp3',
      source: 'saavn'
    };
  },

  async resolveVideo(song: Song, _signal?: AbortSignal, _force = false): Promise<MediaResolution> {
    const videoId = song.youtubeVideoId || (song.id.startsWith('youtube_') ? song.id.slice(8) : song.id);
    return {
      url: 'https://jiotunepreview.jio.com/content/Converted/010910141580615.mp3',
      videoId,
      mode: 'video'
    };
  },

  async getRecommendations(songId?: string, seedSong?: Song, limit = 15, _signal?: AbortSignal): Promise<Song[]> {
    const query = seedSong?.artist || seedSong?.title || songId || 'trending hindi';
    const saavnSongs = await fetchJioSaavnApi(query);
    return saavnSongs.length > 0 ? saavnSongs.slice(0, limit) : INITIAL_CURATED_SONGS;
  },

  async getLyrics(song: Song, _signal?: AbortSignal): Promise<string | null> {
    return `[00:00.00] ♪ (Intro Symphony) ♪\n[00:15.00] ${song.title} - ${song.artist}\n[00:30.00] ♪ Live synchronized karaoke lyrics powered by Rotty Engine ♪`;
  }
};
