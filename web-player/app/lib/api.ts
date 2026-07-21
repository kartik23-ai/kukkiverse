export interface SearchResult {
    id: string;
    title: string;
    artist: string;
    thumbnail: string;
    duration: number;
    audioUrl?: string;
    videoUrl?: string;
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
    { id: 'kJQP7kiw5Fk', title: 'Despacito', artist: 'Luis Fonsi ft. Daddy Yankee', thumbnail: 'https://i.ytimg.com/vi/kJQP7kiw5Fk/maxresdefault.jpg', duration: 228 },
    { id: 'JGwWNGJdvx8', title: 'Shape of You', artist: 'Ed Sheeran', thumbnail: 'https://i.ytimg.com/vi/JGwWNGJdvx8/maxresdefault.jpg', duration: 233 },
    { id: '09R8_2nJtjg', title: 'Sugar', artist: 'Maroon 5', thumbnail: 'https://i.ytimg.com/vi/09R8_2nJtjg/maxresdefault.jpg', duration: 235 },
    { id: 'OPf0YbXqDm0', title: 'Uptown Funk', artist: 'Mark Ronson ft. Bruno Mars', thumbnail: 'https://i.ytimg.com/vi/OPf0YbXqDm0/maxresdefault.jpg', duration: 270 },
    { id: 'dQw4w9WgXcQ', title: 'Never Gonna Give You Up', artist: 'Rick Astley', thumbnail: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg', duration: 213 },
    { id: '9bZkp7q19f0', title: 'Gangnam Style', artist: 'PSY', thumbnail: 'https://i.ytimg.com/vi/9bZkp7q19f0/maxresdefault.jpg', duration: 252 },
    { id: '3tmd-ClpJxA', title: 'Faded', artist: 'Alan Walker', thumbnail: 'https://i.ytimg.com/vi/3tmd-ClpJxA/maxresdefault.jpg', duration: 212 },
    { id: 'hT_nvWreIhg', title: 'Counting Stars', artist: 'OneRepublic', thumbnail: 'https://i.ytimg.com/vi/hT_nvWreIhg/maxresdefault.jpg', duration: 257 }
];

export async function searchYoutube(query: string): Promise<SearchResult[]> {
    try {
        const localRes = await fetch(`/api/search?q=${encodeURIComponent(query)}`);
        if (localRes.ok) {
            const data = await localRes.json();
            if (Array.isArray(data) && data.length > 0) {
                return data;
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
                duration: item.lengthSeconds
            }));
        } catch (e) {
            console.warn(`Instance ${instance} failed`, e);
        }
    }
    return INITIAL_TRENDING_SONGS;
}

export async function resolveStreamUrls(videoId: string): Promise<{ audioUrl: string; videoUrl: string }> {
    const cleanId = videoId.replace('youtube_', '');
    // Try Hugging Face Backend media proxy first
    try {
        const hfRes = await fetch(`${BACKEND_URL}/api/media?id=${cleanId}`, { signal: AbortSignal.timeout(3000) });
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
            const res = await fetch(`${instance}/api/v1/videos/${cleanId}`, { signal: AbortSignal.timeout(3000) });
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
        audioUrl: `https://www.youtube.com/watch?v=${cleanId}`,
        videoUrl: `https://www.youtube.com/watch?v=${cleanId}`
    };
}
