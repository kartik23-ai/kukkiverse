import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import https from 'https';
import http from 'http';
import { Readable } from 'stream';
import { URL } from 'url';

type JsonRecord = Record<string, any>;
type HttpResponse = { status: number; body: string };
type NormalizedSong = {
  id: string;
  title: string;
  artist: string;
  album: string;
  image: string;
  url: string;
  duration: number;
  language: string;
  source: 'youtube';
  youtubeVideoId: string;
};

const YOUTUBE_API_KEY = process.env.YOUTUBE_API_KEY || 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
const YOUTUBE_CLIENT_VERSION = '1.20250310.01.00';
const YOUTUBE_HEADERS = {
  'Content-Type': 'application/json',
  Accept: 'application/json',
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36',
  'X-Goog-Api-Format-Version': '1',
  'X-YouTube-Client-Name': '67',
  'X-YouTube-Client-Version': YOUTUBE_CLIENT_VERSION,
  Origin: 'https://music.youtube.com',
  Referer: 'https://music.youtube.com/'
};

const YOUTUBE_PLAYER_HEADERS = {
  ...YOUTUBE_HEADERS,
  'X-YouTube-Client-Name': '3',
  'X-YouTube-Client-Version': '20.10.38',
  Origin: 'https://www.youtube.com',
  Referer: 'https://www.youtube.com/'
};

const INVIDIOUS_INSTANCES = [
  'inv.nadeko.net',
  'yewtu.be',
  'invidious.nerdvpn.de',
  'inv.thepixora.com',
  'invidious.f5.si'
];

function isValidYouTubeVideoId(value: string): boolean {
  return /^[A-Za-z0-9_-]{11}$/.test(value);
}

function mediaProxyUrl(videoId: string, mode: 'audio' | 'video'): string {
  const full = mode === 'video' ? '&full=1' : '';
  return `/api/media?videoId=${encodeURIComponent(videoId)}&mode=${mode}${full}`;
}

const keepAliveAgent = new https.Agent({
  keepAlive: true,
  maxSockets: 80,
  keepAliveMsecs: 15_000
});

const streamCache = new Map<string, { url: string; expiresAt: number }>();
const MAX_MEDIA_CHUNK = 256 * 1024;
const MAX_BUFFERED_VIDEO = 40 * 1024 * 1024;

async function fetchBufferedMedia(url: string): Promise<{ body: Buffer; contentType: string }> {
  const fetchHeaders = (range: string) => ({ ...YOUTUBE_PLAYER_HEADERS, Accept: '*/*', Range: range });
  const first = await fetch(url, { headers: fetchHeaders(`bytes=0-${MAX_MEDIA_CHUNK - 1}`) });
  if (!first.ok && first.status !== 206) throw new Error(`media_upstream_${first.status}`);
  const firstChunk = Buffer.from(await first.arrayBuffer());
  const contentRange = first.headers.get('content-range') || '';
  const totalMatch = contentRange.match(/\/([0-9]+)$/);
  const total = Number(totalMatch?.[1] || firstChunk.length);
  const contentType = first.headers.get('content-type') || 'video/mp4';
  if (!totalMatch || total <= firstChunk.length || total > MAX_BUFFERED_VIDEO) {
    return { body: firstChunk, contentType };
  }

  const chunks: Buffer[] = [firstChunk];
  let start = firstChunk.length;
  while (start < total) {
    const end = Math.min(total - 1, start + MAX_MEDIA_CHUNK - 1);
    const response = await fetch(url, { headers: fetchHeaders(`bytes=${start}-${end}`) });
    if (!response.ok && response.status !== 206) throw new Error(`media_upstream_${response.status}`);
    const chunk = Buffer.from(await response.arrayBuffer());
    if (!chunk.length) break;
    chunks.push(chunk);
    start += chunk.length;
  }
  return { body: Buffer.concat(chunks, Math.min(total, chunks.reduce((sum, chunk) => sum + chunk.length, 0))), contentType };
}

function fetchUrl(
  targetUrl: string,
  headers: Record<string, string> = {},
  method = 'GET',
  body: string | null = null,
  timeoutMs = 8_000
): Promise<HttpResponse> {
  return new Promise((resolve, reject) => {
    const parsed = new URL(targetUrl);
    const transport = parsed.protocol === 'https:' ? https : http;
    const request = transport.request(
      {
        hostname: parsed.hostname,
        path: `${parsed.pathname}${parsed.search}`,
        method,
        agent: parsed.protocol === 'https:' ? keepAliveAgent : undefined,
        timeout: timeoutMs,
        headers: {
          'User-Agent': YOUTUBE_HEADERS['User-Agent'],
          Accept: 'application/json',
          ...headers
        }
      },
      (response) => {
        let responseBody = '';
        response.setEncoding('utf8');
        response.on('data', (chunk) => { responseBody += chunk; });
        response.on('end', () => resolve({ status: response.statusCode || 500, body: responseBody }));
      }
    );

    request.on('error', reject);
    request.on('timeout', () => {
      request.destroy(new Error('Upstream request timed out'));
    });
    if (body) request.write(body);
    request.end();
  });
}

async function fetchJson<T>(targetUrl: string, headers: Record<string, string> = {}, body?: JsonRecord): Promise<T> {
  const response = await fetchUrl(targetUrl, headers, body ? 'POST' : 'GET', body ? JSON.stringify(body) : null);
  let parsed: JsonRecord;
  try {
    parsed = JSON.parse(response.body) as JsonRecord;
  } catch {
    throw new Error(`Invalid JSON from ${targetUrl}`);
  }
  if (response.status < 200 || response.status >= 300) {
    throw new Error(String(parsed.error || parsed.message || `Upstream status ${response.status}`));
  }
  return parsed as T;
}

function youtubeContext() {
  return {
    client: {
      clientName: 'WEB_REMIX',
      clientVersion: YOUTUBE_CLIENT_VERSION,
      hl: 'en',
      gl: 'IN',
      userAgent: YOUTUBE_HEADERS['User-Agent']
    }
  };
}

function youtubePlayerContext() {
  return {
    client: {
      clientName: 'ANDROID',
      clientVersion: '20.10.38',
      androidSdkVersion: 35,
      hl: 'en',
      gl: 'IN'
    }
  };
}

async function youtubeApi(path: string, body: JsonRecord): Promise<JsonRecord> {
  const url = `https://music.youtube.com/youtubei/v1/${path}?key=${YOUTUBE_API_KEY}&prettyPrint=false`;
  return fetchJson<JsonRecord>(url, YOUTUBE_HEADERS, { context: youtubeContext(), ...body });
}

function text(value: unknown): string {
  if (typeof value === 'string') return value.trim();
  if (Array.isArray(value)) return value.map(text).filter(Boolean).join('');
  if (value && typeof value === 'object') {
    const record = value as JsonRecord;
    if (typeof record.text === 'string') return record.text.trim();
    if (Array.isArray(record.runs)) return record.runs.map(text).filter(Boolean).join('');
  }
  return '';
}

function runParts(value: unknown): string[] {
  if (value && typeof value === 'object') {
    const record = value as JsonRecord;
    if (Array.isArray(record.runs)) {
      return record.runs
        .map((run: unknown) => text(run))
        .map((part) => part.trim())
        .filter((part) => !/^[\u2022\u00b7]$/u.test(part))
        .filter((part) => part && !/^[\u2022\u00b7]$/u.test(part));
    }
  }
  return text(value).split(/[\u2022\u00b7]/u).map((part) => part.trim()).filter(Boolean);
}

function collectNodes(value: unknown, nodeName: string, result: JsonRecord[] = []): JsonRecord[] {
  if (Array.isArray(value)) {
    value.forEach((entry) => collectNodes(entry, nodeName, result));
    return result;
  }
  if (!value || typeof value !== 'object') return result;
  const record = value as JsonRecord;
  Object.entries(record).forEach(([key, child]) => {
    if (key === nodeName && child && typeof child === 'object') {
      if (Array.isArray(child)) child.forEach((entry) => entry && typeof entry === 'object' && result.push(entry as JsonRecord));
      else result.push(child as JsonRecord);
    }
    collectNodes(child, nodeName, result);
  });
  return result;
}

function firstVideoId(value: JsonRecord): string {
  const candidates = [
    value.playlistItemData?.videoId,
    value.navigationEndpoint?.watchEndpoint?.videoId,
    value.navigationEndpoint?.watchEndpoint?.watchEndpointSupportedOnesieConfig?.videoId,
    value.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint?.watchEndpoint?.videoId
  ];
  for (const candidate of candidates) {
    if (typeof candidate === 'string' && candidate) return candidate;
  }
  for (const endpoint of collectNodes(value, 'watchEndpoint')) {
    if (typeof endpoint.videoId === 'string' && endpoint.videoId) return endpoint.videoId;
  }
  return '';
}

function thumbnail(value: JsonRecord): string {
  const thumbnails = collectNodes(value, 'thumbnails');
  const urls = thumbnails.flatMap((entry) => Array.isArray(entry) ? entry : []).map((entry) => entry?.url).filter(Boolean);
  const url = String(urls.at(-1) || '');
  if (!url) return '';
  return url.replace('=w60-h60', '=w500-h500').replace('=w120-h120', '=w500-h500').replace('default.jpg', 'hqdefault.jpg');
}

function parseDuration(value: JsonRecord): number {
  const durationCandidates = [
    ...collectNodes(value, 'fixedColumns').flatMap((entry) => entry.column || []).map(text),
    ...collectNodes(value, 'musicResponsiveListItemFixedColumnRenderer').map(text),
    ...collectNodes(value, 'musicResponsiveListItemFlexColumnRenderer').map((entry) => text(entry.text)),
    ...collectNodes(value, 'lengthText').map(text),
    text(value.subtitle),
    text(value.lengthText)
  ];
  const durationText = durationCandidates.find((entry) => /\d+:\d+/.test(entry)) || '';
  const match = durationText.match(/(?:(\d+):)?(\d+):(\d+)/);
  if (!match) return 0;
  return (Number(match[1] || 0) * 3600) + (Number(match[2]) * 60) + Number(match[3]);
}

function parseResponsiveItem(item: JsonRecord): NormalizedSong | null {
  const videoId = firstVideoId(item);
  const columns = Array.isArray(item.flexColumns) ? item.flexColumns : [];
  const title = text(columns[0]?.musicResponsiveListItemFlexColumnRenderer?.text) || text(item.title);
  if (!videoId || !title) return null;

  const subtitleParts = runParts(columns[1]?.musicResponsiveListItemFlexColumnRenderer?.text);
  const artist = subtitleParts[0] || 'YouTube Artist';
  const album = subtitleParts[1] || 'YouTube Music';
  return {
    id: `youtube_${videoId}`,
    title,
    artist,
    album,
    image: thumbnail(item) || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
    url: '',
    duration: parseDuration(item),
    language: 'YouTube',
    source: 'youtube',
    youtubeVideoId: videoId
  };
}

function parseTwoRowItem(item: JsonRecord): NormalizedSong | null {
  const videoId = firstVideoId(item);
  const title = text(item.title);
  if (!videoId || !title) return null;
  const subtitle = runParts(item.subtitle);
  return {
    id: `youtube_${videoId}`,
    title,
    artist: subtitle[0] || 'YouTube Artist',
    album: subtitle[1] || 'YouTube Music',
    image: thumbnail(item) || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
    url: '',
    duration: parseDuration(item),
    language: 'YouTube',
    source: 'youtube',
    youtubeVideoId: videoId
  };
}

function uniqueSongs(songs: Array<NormalizedSong | null>, limit: number): NormalizedSong[] {
  const seen = new Set<string>();
  return songs.filter((song): song is NormalizedSong => {
    if (!song || seen.has(song.id)) return false;
    seen.add(song.id);
    return true;
  }).slice(0, limit);
}

async function youtubeSearch(query: string, limit = 20): Promise<NormalizedSong[]> {
  const data = await youtubeApi('search', {
    query,
    params: 'EgWKAQIIAWoKEAkQBRAKEAMQHg%3D%3D'
  });
  const items = collectNodes(data, 'musicResponsiveListItemRenderer');
  const twoRows = collectNodes(data, 'musicTwoRowItemRenderer');
  return uniqueSongs([
    ...items.map(parseResponsiveItem),
    ...twoRows.map(parseTwoRowItem)
  ], limit);
}

async function youtubeHome(): Promise<Record<string, NormalizedSong[]>> {
  const sections: Record<string, NormalizedSong[]> = {};
  try {
    const data = await youtubeApi('browse', { browseId: 'FEmusic_home' });
    const shelves = [
      ...collectNodes(data, 'musicCarouselShelfRenderer'),
      ...collectNodes(data, 'musicShelfRenderer')
    ];
    for (const shelf of shelves) {
      const title = text(shelf.header?.musicCarouselShelfBasicHeaderRenderer?.title)
        || text(shelf.title)
        || 'Made for You';
      const songs = [
        ...(collectNodes(shelf, 'musicResponsiveListItemRenderer').map(parseResponsiveItem)),
        ...(collectNodes(shelf, 'musicTwoRowItemRenderer').map(parseTwoRowItem))
      ];
      const unique = uniqueSongs(songs, 14);
      if (unique.length > 0) sections[title] = unique;
    }
  } catch (error) {
    console.warn('[YouTube] Home browse failed; using fresh discovery queries', error);
  }
  if (Object.keys(sections).length >= 4) return sections;

  const queries: Record<string, string> = {
    'Trending on YouTube Music': 'trending music India',
    'Fresh Hindi & Bollywood': 'new Hindi songs 2026',
    'Punjabi Energy': 'new Punjabi songs 2026',
    'English Essentials': 'popular English songs 2026'
  };
  const entries = await Promise.all(Object.entries(queries).map(async ([title, query]) => {
    try { return [title, await youtubeSearch(query, 12)] as const; }
    catch { return [title, [] as NormalizedSong[]] as const; }
  }));
  for (const [title, songs] of entries) {
    if (!sections[title] && songs.length > 0) sections[title] = songs;
  }
  if (Object.keys(sections).length === 0) throw new Error('YouTube Music returned no playable home sections');
  return sections;
}

function videoIdFromSong(id = '', videoId = ''): string {
  if (videoId) return videoId;
  if (id.startsWith('youtube_')) return id.slice('youtube_'.length).replace(/^video_/, '');
  return id;
}

async function resolveRequestVideoId(body: JsonRecord): Promise<string> {
  const supplied = videoIdFromSong(String(body.id || ''), String(body.videoId || ''));
  if (isValidYouTubeVideoId(supplied) && !supplied.startsWith('spotify_track_')) return supplied;

  const title = String(body.title || '').trim();
  const artist = String(body.artist || '').trim();
  if (!title) return '';
  const matches = await youtubeSearch(`${title} ${artist}`.trim(), 5);
  return matches[0]?.youtubeVideoId || '';
}

function expiryFromUrl(url: string): number {
  const expires = Number(new URL(url).searchParams.get('expire') || 0) * 1000;
  return expires || Date.now() + 120_000;
}

function chooseInvidiousFormat(data: JsonRecord, mode: 'audio' | 'video'): string {
  const adaptive = Array.isArray(data.adaptiveFormats) ? data.adaptiveFormats : [];
  const progressive = Array.isArray(data.formatStreams) ? data.formatStreams : [];
  if (mode === 'audio') {
    const audio = adaptive
      .filter((format: JsonRecord) => String(format.type || '').startsWith('audio/') && format.url)
      .sort((a: JsonRecord, b: JsonRecord) => Number(b.bitrate || 0) - Number(a.bitrate || 0));
    return String(audio[0]?.url || '');
  }

  const mp4Progressive = progressive
    .filter((format: JsonRecord) => String(format.type || '').startsWith('video/mp4') && format.url)
    .sort((a: JsonRecord, b: JsonRecord) => Math.abs(Number(a.height || 480) - 480) - Math.abs(Number(b.height || 480) - 480));
  if (mp4Progressive[0]?.url) return String(mp4Progressive[0].url);

  const mp4Adaptive = adaptive
    .filter((format: JsonRecord) => String(format.type || '').startsWith('video/mp4') && format.url)
    .sort((a: JsonRecord, b: JsonRecord) => Math.abs(Number(a.height || 480) - 480) - Math.abs(Number(b.height || 480) - 480));
  return String(mp4Adaptive[0]?.url || adaptive.find((format: JsonRecord) => String(format.type || '').startsWith('video/') && format.url)?.url || '');
}

async function fetchInvidious(videoId: string, mode: 'audio' | 'video'): Promise<string> {
  const cached = streamCache.get(`${mode}:${videoId}`);
  if (cached && cached.expiresAt > Date.now() + 15_000) return cached.url;

  const attempts = INVIDIOUS_INSTANCES.slice(0, 4).map(async (instance) => {
    const response = await fetchUrl(`https://${instance}/api/v1/videos/${encodeURIComponent(videoId)}`, {
      Accept: 'application/json',
      Referer: `https://${instance}/`
    }, 'GET', null, 5_500);
    if (response.status < 200 || response.status >= 300) throw new Error(`${instance} returned ${response.status}`);
    const data = JSON.parse(response.body) as JsonRecord;
    const url = chooseInvidiousFormat(data, mode);
    if (!url) throw new Error(`${instance} has no ${mode} format`);
    return url;
  });

  const url = await Promise.any(attempts);
  streamCache.set(`${mode}:${videoId}`, { url, expiresAt: expiryFromUrl(url) });
  return url;
}

async function fetchYouTubePlayer(videoId: string, mode: 'audio' | 'video'): Promise<string> {
  const data = await fetchJson<JsonRecord>(`https://www.youtube.com/youtubei/v1/player?key=${YOUTUBE_API_KEY}&prettyPrint=false`, YOUTUBE_PLAYER_HEADERS, {
    context: youtubePlayerContext(),
    videoId,
    contentCheckOk: true,
    racyCheckOk: true
  });
  const playability = data.playabilityStatus as JsonRecord | undefined;
  if (playability?.status && playability.status !== 'OK') {
    throw new Error(String(playability.reason || `YouTube player status: ${playability.status}`));
  }
  const streaming = data.streamingData as JsonRecord | undefined;
  const formats = [
    ...(Array.isArray(streaming?.adaptiveFormats) ? streaming.adaptiveFormats : []),
    ...(Array.isArray(streaming?.formats) ? streaming.formats : [])
  ] as JsonRecord[];
  const valid = formats.filter((format) => typeof format.url === 'string' && format.url);
  const selected = mode === 'audio'
    ? valid.filter((format) => String(format.mimeType || '').startsWith('audio/')).sort((a, b) => {
      const aIsMp4 = String(a.mimeType || '').startsWith('audio/mp4') ? 1 : 0;
      const bIsMp4 = String(b.mimeType || '').startsWith('audio/mp4') ? 1 : 0;
      return bIsMp4 - aIsMp4 || Number(b.bitrate || 0) - Number(a.bitrate || 0);
    })[0]
    : valid.filter((format) => String(format.mimeType || '').startsWith('video/mp4'))
      .sort((a, b) => {
        const aScore = (a.audioQuality ? 0 : 1) * 1000 + Math.abs(Number(a.height || 480) - 480);
        const bScore = (b.audioQuality ? 0 : 1) * 1000 + Math.abs(Number(b.height || 480) - 480);
        return aScore - bScore;
      })[0];
  if (!selected?.url) throw new Error(`YouTube player has no ${mode} stream`);
  return String(selected.url);
}

async function resolveStream(videoId: string, mode: 'audio' | 'video'): Promise<{ url: string; videoId: string; mode: 'audio' | 'video'; expiresAt: string }> {
  if (!isValidYouTubeVideoId(videoId)) throw new Error('A valid YouTube video ID is required');
  let url = '';
  try {
    url = await fetchInvidious(videoId, mode);
  } catch (invidiousError) {
    console.warn(`[YouTube] Invidious ${mode} resolution failed; trying YouTube player`, invidiousError);
    url = await fetchYouTubePlayer(videoId, mode);
  }
  return { url, videoId, mode, expiresAt: new Date(expiryFromUrl(url)).toISOString() };
}

async function fetchLyrics(title: string, artist: string, duration = 0): Promise<string | null> {
  const cleanTitle = title.split(' - ')[0].replace(/\([^)]*\)/g, '').trim();
  const cleanArtist = artist.split(',')[0].replace(/\b(feat|ft)\b.*/gi, '').trim();
  const base = `https://lrclib.net/api/get?track_name=${encodeURIComponent(cleanTitle)}&artist_name=${encodeURIComponent(cleanArtist)}&duration=${Math.round(duration)}`;
  try {
    const response = await fetchUrl(base, { 'User-Agent': 'RottyMusicWeb/2.0' });
    if (response.status === 200) {
      const data = JSON.parse(response.body) as JsonRecord;
      return String(data.syncedLyrics || data.plainLyrics || '') || null;
    }
  } catch (error) {
    console.warn('[Lyrics] LRCLIB request failed', error);
  }
  return null;
}

function toResponseSong(song: NormalizedSong): NormalizedSong {
  return { ...song, source: 'youtube', url: '' };
}

async function spotifyPlaylist(url: string): Promise<JsonRecord> {
  const match = url.trim().match(/(?:playlist\/|spotify:playlist:)([a-zA-Z0-9]{22})/);
  if (!match) throw new Error('Enter a valid Spotify playlist URL');
  const playlistId = match[1];
  const response = await fetchUrl(`https://open.spotify.com/embed/playlist/${playlistId}`, {
    Accept: 'text/html,application/xhtml+xml'
  });
  const script = response.body.match(/<script\s+id="resource"\s+type="application\/json">(.*?)<\/script>/s)
    || response.body.match(/<script\s+id="__NEXT_DATA__"\s+type="application\/json">(.*?)<\/script>/s);
  if (!script) throw new Error('Spotify playlist is private or unavailable');
  const state = JSON.parse(script[1]) as JsonRecord;
  const entity = state.props?.pageProps?.state?.data?.entity || state.state?.data?.entity;
  if (!entity) throw new Error('Spotify playlist data was not found');
  const image = String(entity.coverArt?.sources?.[0]?.url || '');
  const songs = (Array.isArray(entity.trackList) ? entity.trackList : []).map((track: JsonRecord, index: number) => {
    const uri = String(track.uri || '');
    const trackId = uri.split(':').at(-1) || `${index}`;
    return {
      id: `spotify_track_${trackId}`,
      title: String(track.title || 'Unknown Track'),
      artist: String(track.subtitle || 'Unknown Artist'),
      album: 'Spotify Playlist',
      image,
      duration: Math.floor(Number(track.duration || 0) / 1000),
      language: 'YouTube',
      source: 'youtube',
      url: '',
      youtubeVideoId: ''
    };
  });
  return {
    id: `spotify_playlist_${playlistId}`,
    name: String(entity.name || 'Spotify Playlist'),
    description: String(entity.subtitle || ''),
    image,
    songs
  };
}

function writeJson(res: any, status: number, payload: JsonRecord): void {
  res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(payload));
}

export default defineConfig({
  plugins: [
    react(),
    {
      name: 'youtube-music-api',
      configureServer(server: any) {
        server.middlewares.use((req: any, res: any, next: any) => {
          const parsedUrl = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
          if (parsedUrl.pathname === '/api/media' && req.method === 'GET') {
            const videoId = String(parsedUrl.searchParams.get('videoId') || '');
            const mode = parsedUrl.searchParams.get('mode') === 'video' ? 'video' : 'audio';
            if (!isValidYouTubeVideoId(videoId)) {
              writeJson(res, 400, { error: 'invalid_video_id' });
              return;
            }
            resolveStream(videoId, mode)
              .then(async (resolved) => {
                if (mode === 'video' && parsedUrl.searchParams.get('full') === '1') {
                  const buffered = await fetchBufferedMedia(resolved.url);
                  res.writeHead(200, {
                    'Accept-Ranges': 'bytes',
                    'Cache-Control': 'private, max-age=60',
                    'Content-Type': buffered.contentType,
                    'Content-Length': String(buffered.body.length),
                    'Access-Control-Allow-Origin': '*'
                  });
                  res.end(buffered.body);
                  return;
                }
                const requestedRange = String(req.headers.range || '');
                const rangeMatch = requestedRange.match(/^bytes=(\d+)-(\d*)$/);
                const rangeStart = rangeMatch ? Number(rangeMatch[1]) : 0;
                const requestedEnd = rangeMatch?.[2] ? Number(rangeMatch[2]) : rangeStart + MAX_MEDIA_CHUNK - 1;
                const rangeEnd = Math.min(requestedEnd, rangeStart + MAX_MEDIA_CHUNK - 1);
                const upstream = await fetch(resolved.url, {
                  headers: {
                    ...YOUTUBE_PLAYER_HEADERS,
                    Accept: '*/*',
                    Range: `bytes=${rangeStart}-${rangeEnd}`
                  }
                });
                if (!upstream.ok && upstream.status !== 206) {
                  writeJson(res, 502, { error: `media_upstream_${upstream.status}` });
                  return;
                }
                const headers: Record<string, string> = {
                  'Accept-Ranges': upstream.headers.get('accept-ranges') || 'bytes',
                  'Cache-Control': 'private, max-age=60',
                  'Content-Type': upstream.headers.get('content-type') || (mode === 'audio' ? 'audio/webm' : 'video/mp4'),
                  'Access-Control-Allow-Origin': '*'
                };
                for (const headerName of ['content-length', 'content-range']) {
                  const headerValue = upstream.headers.get(headerName);
                  if (headerValue) headers[headerName] = headerValue;
                }
                res.writeHead(upstream.status, headers);
                if (!upstream.body) {
                  res.end();
                  return;
                }
                Readable.fromWeb(upstream.body as any).pipe(res);
              })
              .catch((error) => {
                console.error('[YouTube media proxy] failed', error);
                if (!res.headersSent) writeJson(res, 502, { error: 'media_proxy_failed' });
              });
            return;
          }
          if (parsedUrl.pathname === '/api/health' && req.method === 'GET') {
            writeJson(res, 200, { ok: true, source: 'youtube', resolver: 'invidious-first' });
            return;
          }
          if (!parsedUrl.pathname.startsWith('/api/') || req.method !== 'POST') {
            next();
            return;
          }

          let bodyString = '';
          req.on('data', (chunk: Buffer) => { bodyString += chunk.toString(); });
          req.on('end', async () => {
            let body: JsonRecord = {};
            try { body = bodyString ? JSON.parse(bodyString) as JsonRecord : {}; } catch { writeJson(res, 400, { error: 'invalid_json' }); return; }

            try {
              if (parsedUrl.pathname === '/api/search') {
                const songs = await youtubeSearch(String(body.query || ''), Math.min(Number(body.limit || 20), 50));
                writeJson(res, 200, { source: 'youtube', songs: songs.map(toResponseSong) });
                return;
              }

              if (parsedUrl.pathname === '/api/home') {
                const sections = await youtubeHome();
                writeJson(res, 200, { source: 'youtube', sections });
                return;
              }

              if (parsedUrl.pathname === '/api/details') {
                const videoId = videoIdFromSong(String(body.id || ''), String(body.videoId || ''));
                const songs = await youtubeSearch(videoId, 1);
                const song = songs[0];
                if (!song) { writeJson(res, 404, { error: 'not_found' }); return; }
                try {
                  const player = await youtubeApi('player', { videoId });
                  const duration = Number(player.videoDetails?.lengthSeconds || song.duration || 0);
                  song.duration = duration;
                } catch { /* metadata remains usable without duration */ }
                writeJson(res, 200, { source: 'youtube', song: toResponseSong(song) });
                return;
              }

              if (parsedUrl.pathname === '/api/stream' || parsedUrl.pathname === '/api/video') {
                const mode = parsedUrl.pathname === '/api/video' ? 'video' : String(body.mode || 'audio') === 'video' ? 'video' : 'audio';
                const videoId = await resolveRequestVideoId(body);
                const resolved = await resolveStream(videoId, mode);
                writeJson(res, 200, { ...resolved, url: mediaProxyUrl(resolved.videoId, resolved.mode) });
                return;
              }

              if (parsedUrl.pathname === '/api/recommendations') {
                const query = `${String(body.artist || '')} songs`.trim() || String(body.title || 'trending music');
                const songs = await youtubeSearch(query, Math.min(Number(body.limit || 15), 30));
                writeJson(res, 200, { source: 'youtube', songs });
                return;
              }

              if (parsedUrl.pathname === '/api/lyrics') {
                const lyrics = await fetchLyrics(String(body.title || ''), String(body.artist || ''), Number(body.duration || 0));
                if (!lyrics) { writeJson(res, 404, { error: 'lyrics_not_found' }); return; }
                writeJson(res, 200, { lyrics });
                return;
              }

              if (parsedUrl.pathname === '/api/spotify-sync') {
                const playlist = await spotifyPlaylist(String(body.url || ''));
                writeJson(res, 200, playlist);
                return;
              }

              if (parsedUrl.pathname === '/api/health') {
                writeJson(res, 200, { ok: true, source: 'youtube', resolver: 'invidious-first' });
                return;
              }

              writeJson(res, 404, { error: 'not_found' });
            } catch (error) {
              console.error(`[YouTube API] ${parsedUrl.pathname} failed`, error);
              writeJson(res, 502, { error: error instanceof Error ? error.message : 'provider_unavailable' });
            }
          });
        });
      }
    }
  ],
  server: {
    proxy: {
      '/media': {
        target: 'https://www.youtube.com',
        changeOrigin: true,
        secure: true
      }
    }
  }
});
