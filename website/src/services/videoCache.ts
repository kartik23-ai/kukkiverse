const VIDEO_CACHE_NAME = 'rotty-native-video-v1';
const VIDEO_CACHE_META_KEY = 'rotty-native-video-meta-v1';
const MAX_CACHE_ENTRIES = 4;
const MAX_CACHE_BYTES = 80 * 1024 * 1024;
const MAX_CACHE_AGE_MS = 1000 * 60 * 60 * 6;

interface VideoCacheMeta {
  videoId: string;
  cacheKey: string;
  cachedAt: number;
  size: number;
}

const objectUrlCache = new Map<string, string>();

function getCacheKey(videoId: string): string {
  const safeId = encodeURIComponent(videoId);
  return `${window.location.origin}/__rotty_native_video__/${safeId}`;
}

function readMetadata(): VideoCacheMeta[] {
  try {
    const raw = localStorage.getItem(VIDEO_CACHE_META_KEY);
    const parsed = raw ? JSON.parse(raw) : [];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeMetadata(metadata: VideoCacheMeta[]): void {
  try {
    localStorage.setItem(VIDEO_CACHE_META_KEY, JSON.stringify(metadata));
  } catch {
    // Cache is only an optimization; playback must continue if storage is full.
  }
}

function forgetObjectUrl(videoId: string): void {
  const objectUrl = objectUrlCache.get(videoId);
  if (!objectUrl) return;
  URL.revokeObjectURL(objectUrl);
  objectUrlCache.delete(videoId);
}

async function getCache(): Promise<Cache | null> {
  if (typeof window === 'undefined' || !('caches' in window)) return null;
  try {
    return await window.caches.open(VIDEO_CACHE_NAME);
  } catch {
    return null;
  }
}

async function cleanupCache(cache: Cache | null, keepVideoId?: string): Promise<void> {
  if (!cache) return;

  const now = Date.now();
  const metadata = readMetadata()
    .filter((entry) => entry.cacheKey && entry.videoId)
    .sort((a, b) => b.cachedAt - a.cachedAt);
  const keep: VideoCacheMeta[] = [];
  let totalBytes = 0;

  for (const entry of metadata) {
    const expired = now - entry.cachedAt > MAX_CACHE_AGE_MS;
    const overLimit = keep.length >= MAX_CACHE_ENTRIES || totalBytes + entry.size > MAX_CACHE_BYTES;
    const shouldKeep = !expired && !overLimit;

    if (shouldKeep || entry.videoId === keepVideoId) {
      keep.push(entry);
      totalBytes += entry.size;
      continue;
    }

    await cache.delete(entry.cacheKey);
    forgetObjectUrl(entry.videoId);
  }

  writeMetadata(keep);
}

async function fetchVideoResponse(mediaUrl: string, signal?: AbortSignal): Promise<Response> {
  const response = await fetch(mediaUrl, {
    signal,
    headers: { Accept: 'video/mp4,video/*;q=0.9,*/*;q=0.1' }
  });
  if (!response.ok) throw new Error(`video_cache_http_${response.status}`);
  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) throw new Error('video_cache_invalid_media');
  return response;
}

async function cacheVideo(videoId: string, mediaUrl: string, signal?: AbortSignal): Promise<Response> {
  const cache = await getCache();
  const cacheKey = getCacheKey(videoId);
  const cached = await cache?.match(cacheKey);
  if (cached) {
    void cleanupCache(cache, videoId);
    return cached;
  }

  const upstream = await fetchVideoResponse(mediaUrl, signal);
  const blob = await upstream.blob();
  if (!blob.size) throw new Error('video_cache_empty_media');

  const response = new Response(blob, {
    status: 200,
    headers: {
      'Content-Type': blob.type || 'video/mp4',
      'Content-Length': String(blob.size),
      'Cache-Control': 'private, max-age=21600'
    }
  });

  if (cache) {
    try {
      await cache.put(cacheKey, response.clone());
      const metadata = readMetadata().filter((entry) => entry.videoId !== videoId);
      metadata.unshift({ videoId, cacheKey, cachedAt: Date.now(), size: blob.size });
      writeMetadata(metadata);
      await cleanupCache(cache, videoId);
    } catch {
      // The blob is still usable even when Cache Storage is unavailable.
    }
  }

  return response;
}

export async function getCachedVideoObjectUrl(
  videoId: string,
  mediaUrl: string,
  signal?: AbortSignal
): Promise<string> {
  const inMemory = objectUrlCache.get(videoId);
  if (inMemory) return inMemory;

  const response = await cacheVideo(videoId, mediaUrl, signal);
  const objectUrl = URL.createObjectURL(await response.blob());
  objectUrlCache.set(videoId, objectUrl);
  return objectUrl;
}

export async function prefetchCachedVideo(
  videoId: string,
  mediaUrl: string,
  signal?: AbortSignal
): Promise<void> {
  await cacheVideo(videoId, mediaUrl, signal);
}

export async function invalidateCachedVideo(videoId: string): Promise<void> {
  forgetObjectUrl(videoId);
  const cache = await getCache();
  if (cache) await cache.delete(getCacheKey(videoId));
  writeMetadata(readMetadata().filter((entry) => entry.videoId !== videoId));
}

export function releaseCachedVideoObjectUrl(videoId: string): void {
  forgetObjectUrl(videoId);
}

