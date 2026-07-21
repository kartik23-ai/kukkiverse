export interface SearchResult {
    id: string;
    title: string;
    artist: string;
    thumbnail: string;
    duration: number;
    audioUrl?: string;
    videoUrl?: string;
    source: 'saavn' | 'youtube';
    album?: string;
}

export const BACKEND_URL = "https://rottymusic-rotty-music-backend.hf.space";

const INSTANCES = [
    "https://inv.tux.pizza",
    "https://vid.puffyan.us",
    "https://invidious.projectsegfault.net",
    "https://invidious.drgns.space",
    "https://yt.artemislena.eu"
];

export const INITIAL_TRENDING_SONGS: SearchResult[] = [
    { id: 'YiVML4Zo', title: 'Gehra Hua', artist: 'Arijit Singh, Shashwat Sachdev', thumbnail: 'https://c.saavncdn.com/450/Gehra-Hua-From-Dhurandhar-Hindi-2025-20251205154217-500x500.jpg', duration: 228, source: 'saavn', album: 'Dhurandhar' },
    { id: 'aRZbUYD7', title: 'Tum Hi Ho', artist: 'Mithoon, Arijit Singh', thumbnail: 'https://c.saavncdn.com/430/Aashiqui-2-Hindi-2013-500x500.jpg', duration: 262, source: 'saavn', album: 'Aashiqui 2' },
    { id: 'kJQP7kiw5Fk', title: 'Despacito', artist: 'Luis Fonsi ft. Daddy Yankee', thumbnail: 'https://i.ytimg.com/vi/kJQP7kiw5Fk/maxresdefault.jpg', duration: 228, source: 'youtube', album: 'Vida' },
    { id: 'JGwWNGJdvx8', title: 'Shape of You', artist: 'Ed Sheeran', thumbnail: 'https://i.ytimg.com/vi/JGwWNGJdvx8/maxresdefault.jpg', duration: 233, source: 'youtube', album: '÷ Divide' },
    { id: '09R8_2nJtjg', title: 'Sugar', artist: 'Maroon 5', thumbnail: 'https://i.ytimg.com/vi/09R8_2nJtjg/maxresdefault.jpg', duration: 235, source: 'youtube', album: 'V' },
    { id: 'OPf0YbXqDm0', title: 'Uptown Funk', artist: 'Mark Ronson ft. Bruno Mars', thumbnail: 'https://i.ytimg.com/vi/OPf0YbXqDm0/maxresdefault.jpg', duration: 270, source: 'youtube', album: 'Uptown Special' }
];

// Helper to decode HTML entities
function cleanText(str: string = ''): string {
    return str
        .replace(/&quot;/g, '"')
        .replace(/&amp;/g, '&')
        .replace(/&#039;/g, "'")
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>');
}

// Search JioSaavn API directly
export async function searchJioSaavn(query: string): Promise<SearchResult[]> {
    try {
        const url = `https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&cc=in&includeMetaTags=1&query=${encodeURIComponent(query)}`;
        const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
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
                    thumbnail: highResImg || `https://i.ytimg.com/vi/${s.id}/maxresdefault.jpg`,
                    duration: 210,
                    source: 'saavn',
                    album: cleanText(s.album || 'Single'),
                    audioUrl: s.more_info?.vlink || undefined
                };
            });
        }
    } catch (e) {
        console.warn('JioSaavn search failed:', e);
    }
    return [];
}

// Search YouTube API / Scraper
export async function searchYoutube(query: string): Promise<SearchResult[]> {
    try {
        const localRes = await fetch(`/api/search?q=${encodeURIComponent(query)}`);
        if (localRes.ok) {
            const data = await localRes.json();
            if (Array.isArray(data) && data.length > 0) {
                return data.map((item: any) => ({
                    ...item,
                    source: 'youtube'
                }));
            }
        }
    } catch (_) {}

    for (const instance of INSTANCES) {
        try {
            const res = await fetch(`${instance}/api/v1/search?q=${encodeURIComponent(query)}&type=video`, {
                signal: AbortSignal.timeout(4000)
            });
            if (!res.ok) continue;
            const data = await res.json();
            return data.map((item: any) => ({
                id: item.videoId,
                title: item.title,
                artist: item.author,
                thumbnail: item.videoThumbnails?.find((t: any) => t.quality === 'medium')?.url || `https://i.ytimg.com/vi/${item.videoId}/mqdefault.jpg`,
                duration: item.lengthSeconds,
                source: 'youtube',
                album: 'YouTube'
            }));
        } catch (e) {
            console.warn(`Instance ${instance} failed`, e);
        }
    }
    return INITIAL_TRENDING_SONGS;
}

// Unified Search (Combines JioSaavn + YouTube)
export async function searchAll(query: string): Promise<SearchResult[]> {
    const [saavnResults, ytResults] = await Promise.all([
        searchJioSaavn(query),
        searchYoutube(query)
    ]);
    const combined = [...saavnResults, ...ytResults];
    return combined.length > 0 ? combined : INITIAL_TRENDING_SONGS;
}

// Stream resolver for songs
export async function resolveStreamUrls(song: SearchResult): Promise<{ audioUrl: string; videoUrl: string }> {
    // If it's a JioSaavn song, fetch direct details
    if (song.source === 'saavn' || !song.id.startsWith('youtube_')) {
        try {
            const detailsUrl = `https://www.jiosaavn.com/api.php?__call=song.getDetails&cc=in&_marker=0&_format=json&pids=${song.id}`;
            const res = await fetch(detailsUrl, { signal: AbortSignal.timeout(4000) });
            if (res.ok) {
                const data = await res.json();
                const songDetails = data[song.id];
                if (songDetails) {
                    const audioStream = songDetails.media_preview_url || songDetails.vlink;
                    if (audioStream) {
                        return {
                            audioUrl: audioStream,
                            videoUrl: audioStream
                        };
                    }
                }
            }
        } catch (e) {
            console.warn('Saavn stream resolution failed, falling back to YouTube:', e);
        }
    }

    const videoId = song.id.replace('youtube_', '');
    // Try Hugging Face Backend media proxy
    try {
        const hfRes = await fetch(`${BACKEND_URL}/api/media?id=${videoId}`, { signal: AbortSignal.timeout(3000) });
        if (hfRes.ok) {
            const data = await hfRes.json();
            if (data?.streamUrl) {
                return { audioUrl: data.streamUrl, videoUrl: data.videoUrl || data.streamUrl };
            }
        }
    } catch (_) {}

    // Fallback to Invidious stream formats
    for (const instance of INSTANCES) {
        try {
            const res = await fetch(`${instance}/api/v1/videos/${videoId}`, { signal: AbortSignal.timeout(3000) });
            if (res.ok) {
                const data = await res.json();
                const adaptiveFormats = data.adaptiveFormats || [];
                const formatStreams = data.formatStreams || [];
                const audioObj = adaptiveFormats.find((f: any) => f.type?.includes('audio')) || formatStreams[0];
                const videoObj = formatStreams.find((f: any) => f.type?.includes('video')) || formatStreams[0];

                if (audioObj?.url) {
                    return {
                        audioUrl: audioObj.url,
                        videoUrl: videoObj?.url || audioObj.url
                    };
                }
            }
        } catch (_) {}
    }

    // Embed fallback URL
    return {
        audioUrl: `https://www.youtube.com/watch?v=${videoId}`,
        videoUrl: `https://www.youtube.com/watch?v=${videoId}`
    };
}
