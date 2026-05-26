import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import crypto from 'crypto'
import https from 'https'
import http from 'http'
import { URL } from 'url'
import CryptoJS from 'crypto-js'

// AES encryption details matching backend/server.js
const SECRET_KEY = 'rotty-ghost-key-32chars-xxxxxxxx';
const KEY_BUF = Buffer.from(SECRET_KEY.slice(0, 32).padEnd(32, '0'), 'utf8');

// Global keep-alive agent to reuse TCP/TLS connections
const keepAliveAgent = new https.Agent({
  keepAlive: true,
  maxSockets: 100,
  keepAliveMsecs: 15000,
});

function encryptPayload(plainText: string): string {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-cbc', KEY_BUF, iv);
  const encrypted = Buffer.concat([cipher.update(plainText, 'utf8'), cipher.final()]);
  return iv.toString('base64') + ':' + encrypted.toString('base64');
}

// Node HTTPS request helper
function fetchUrl(targetUrl: string, headers: Record<string, string> = {}, method = 'GET', body: string | null = null): Promise<{ status?: number; body: string }> {
  return new Promise((resolve, reject) => {
    const parsed = new URL(targetUrl);
    const lib = parsed.protocol === 'https:' ? https : http;
    
    const options: http.RequestOptions = {
      hostname: parsed.hostname,
      path: parsed.pathname + parsed.search,
      method: method,
      agent: parsed.protocol === 'https:' ? keepAliveAgent : undefined,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        ...headers,
      },
      timeout: 12000,
    };
    
    const req = lib.request(options, (res) => {
      let data = '';
      res.on('data', (d) => (data += d));
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    
    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
    
    if (body) {
      req.write(body);
    }
    req.end();
  });
}

// JioSaavn Search helper
async function saavnSearch(query: string, limit = 25) {
  const qs = new URLSearchParams({
    __call: 'search.getResults',
    _format: 'json',
    _marker: '0',
    ctx: 'web6dot0',
    q: query,
    p: '1',
    n: String(limit),
    type: 'song',
  });
  const res = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
    Referer: 'https://www.jiosaavn.com',
  });
  const body = JSON.parse(res.body);
  return body.results || [];
}

// DES ECB decryption helper for JioSaavn encrypted media URLs
function decryptDesEcb(ciphertextBase64: string): string {
  if (!ciphertextBase64) return '';
  try {
    const key = CryptoJS.enc.Utf8.parse('38346591');
    const decrypted = CryptoJS.DES.decrypt(
      { ciphertext: CryptoJS.enc.Base64.parse(ciphertextBase64) } as any,
      key,
      {
        mode: CryptoJS.mode.ECB,
        padding: CryptoJS.pad.Pkcs7
      }
    );
    return decrypted.toString(CryptoJS.enc.Utf8);
  } catch (e: any) {
    console.error('[GhostProxy] DES decryption error:', e);
    return '';
  }
}

// Extract media URL
function extractMediaUrl(song: any) {
  // 1. Try to decrypt the encrypted media URL first
  const info = song.more_info || song;
  const encUrl = info.encrypted_media_url || song.encrypted_media_url || info.encrypted_media_path || song.encrypted_media_path;
  if (encUrl) {
    const decrypted = decryptDesEcb(encUrl);
    if (decrypted) {
      let finalUrl = decrypted.replace('_96.mp4', '_320.mp4');
      if (finalUrl.includes('preview.saavncdn.com')) {
        finalUrl = finalUrl.replace('preview.saavncdn.com', 'aac.saavncdn.com');
      }
      return finalUrl;
    }
  }

  // 2. Fallback to media_preview_url
  const mediaPreviewUrl = info.media_preview_url || song.media_preview_url || '';
  if (!mediaPreviewUrl) return '';
  let url = mediaPreviewUrl.replace('http:', 'https:');
  url = url.replace('_96_p.mp4', '_320.mp4').replace('_96.mp4', '_320.mp4');
  url = url.replace('media-saavn.akamaized.net', 'aac.saavncdn.com');
  url = url.replace('preview.saavncdn.com', 'aac.saavncdn.com');
  return url;
}

// LRCLIB Synced Lyrics fetcher
async function fetchLrclib(title: string, artist: string, duration = 0) {
  try {
    const cleanTitle = title.split(' - ')[0].replace(/\([^)]*\)/g, '').trim();
    const cleanArtist = artist.split(',')[0].replace(/\b(feat|ft)\b.*/gi, '').trim();
    
    const getUrl = `https://lrclib.net/api/get?track_name=${encodeURIComponent(cleanTitle)}&artist_name=${encodeURIComponent(cleanArtist)}&duration=${duration}`;
    const res = await fetchUrl(getUrl, { 'User-Agent': 'RottyMusicWeb/1.0' });
    if (res.status === 200) {
      const data = JSON.parse(res.body);
      if (data.syncedLyrics) return data.syncedLyrics;
      if (data.plainLyrics) return data.plainLyrics;
    }
  } catch (_) {}

  try {
    const cleanTitle = title.split(' - ')[0].replace(/\([^)]*\)/g, '').trim();
    const cleanArtist = artist.split(',')[0].replace(/\b(feat|ft)\b.*/gi, '').trim();
    
    const searchUrl = `https://lrclib.net/api/search?q=${encodeURIComponent(cleanTitle + ' ' + cleanArtist)}`;
    const res = await fetchUrl(searchUrl);
    if (res.status === 200) {
      const results = JSON.parse(res.body);
      if (Array.isArray(results) && results.length > 0) {
        let bestMatch = results[0];
        let minDiff = Math.abs((results[0].duration || 0) - duration);
        for (const item of results) {
          const diff = Math.abs((item.duration || 0) - duration);
          if (diff < minDiff) {
            minDiff = diff;
            bestMatch = item;
          }
        }
        if (minDiff < 30 || duration === 0) {
          return bestMatch.syncedLyrics || bestMatch.plainLyrics || null;
        }
      }
    }
  } catch (_) {}
  return null;
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    {
      name: 'api-proxy-middleware',
      configureServer(server: any) {
        server.middlewares.use(async (req: any, res: any, next: any) => {
          const parsedUrl = new URL(req.url || '', `http://${req.headers.host}`);
          const pathname = parsedUrl.pathname;
          
          if (pathname.startsWith('/api/') && req.method === 'POST') {
            // Read request body
            let bodyStr = '';
            req.on('data', (chunk: any) => { bodyStr += chunk; });
            req.on('end', async () => {
              let body: any = {};
              try {
                if (bodyStr) body = JSON.parse(bodyStr);
              } catch (_) {}
              
              res.setHeader('Content-Type', 'application/json');
              
              try {
                if (pathname === '/api/search') {
                  const { query, limit = 25 } = body;
                  const songs = await saavnSearch(query || '', limit);
                  const sanitized = songs.map((s: any) => ({
                    id: s.id || s.songid || '',
                    title: s.song || s.title || s.name || '',
                    artist: s.primary_artists || s.singers || s.subtitle || s.artist || 'Artist',
                    album: s.album || '',
                    image: (s.image || '').replace('http://', 'https://'),
                    duration: Number(s.duration) || 0,
                    language: s.language || '',
                    url: extractMediaUrl(s)
                  })).filter((s: any) => s.id);
                  
                  res.writeHead(200);
                  res.end(JSON.stringify({ d: encryptPayload(JSON.stringify(sanitized)) }));
                  return;
                }
                
                if (pathname === '/api/details') {
                  const { id } = body;
                  const qs = new URLSearchParams({
                    __call: 'song.getDetails',
                    _format: 'json',
                    ctx: 'web6dot0',
                    pids: id,
                  });
                  const response = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
                    Referer: 'https://www.jiosaavn.com',
                  });
                  
                  const data = JSON.parse(response.body);
                  let song: any = null;
                  if (Array.isArray(data) && data.length > 0) {
                    song = data[0];
                  } else if (data && data.songs && data.songs.length > 0) {
                    song = data.songs[0];
                  } else if (data && typeof data === 'object') {
                    const keys = Object.keys(data);
                    if (keys.length > 0 && data[keys[0]] && data[keys[0]].id) {
                      song = data[keys[0]];
                    }
                  }
                  
                  if (song) {
                    const sanitized = {
                      id: song.id || '',
                      title: song.song || song.name || '',
                      artist: song.primary_artists || song.singers || 'Artist',
                      album: song.album || '',
                      image: (song.image || '').replace('http://', 'https://'),
                      duration: Number(song.duration) || 0,
                      language: song.language || '',
                      url: extractMediaUrl(song)
                    };
                    res.writeHead(200);
                    res.end(JSON.stringify({ d: encryptPayload(JSON.stringify(sanitized)) }));
                  } else {
                    res.writeHead(404);
                    res.end(JSON.stringify({ error: 'not_found' }));
                  }
                  return;
                }
                
                if (pathname === '/api/stream') {
                  const { id } = body;
                  const qs = new URLSearchParams({
                    __call: 'song.getDetails',
                    _format: 'json',
                    ctx: 'web6dot0',
                    pids: id,
                  });
                  const response = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
                    Referer: 'https://www.jiosaavn.com',
                  });
                  
                  const data = JSON.parse(response.body);
                  let song: any = null;
                  if (Array.isArray(data) && data.length > 0) {
                    song = data[0];
                  } else if (data && data.songs && data.songs.length > 0) {
                    song = data.songs[0];
                  } else if (data && typeof data === 'object') {
                    const keys = Object.keys(data);
                    if (keys.length > 0 && data[keys[0]] && data[keys[0]].id) {
                      song = data[keys[0]];
                    }
                  }
                  
                  const url = song ? extractMediaUrl(song) : '';
                  if (url) {
                    res.writeHead(200);
                    res.end(JSON.stringify({ d: encryptPayload(url) }));
                  } else {
                    res.writeHead(404);
                    res.end(JSON.stringify({ error: 'stream_not_found' }));
                  }
                  return;
                }
                
                if (pathname === '/api/recommendations') {
                  const { id, limit = 15 } = body;
                  const qs = new URLSearchParams({
                    __call: 'reco.getreco',
                    _format: 'json',
                    ctx: 'web6dot0',
                    pid: id,
                    api_version: '4',
                    n: String(limit),
                  });
                  const response = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
                    Referer: 'https://www.jiosaavn.com',
                  });
                  
                  const list = JSON.parse(response.body);
                  const sanitized = (Array.isArray(list) ? list : []).map((s: any) => ({
                    id: s.id || '',
                    title: s.song || s.title || '',
                    artist: s.primary_artists || s.subtitle || '',
                    album: s.album || '',
                    image: (s.image || '').replace('http://', 'https://'),
                    duration: Number(s.duration) || 0,
                    language: s.language || '',
                    url: extractMediaUrl(s)
                  })).filter((s: any) => s.id);
                  
                  res.writeHead(200);
                  res.end(JSON.stringify({ d: encryptPayload(JSON.stringify(sanitized)) }));
                  return;
                }
                
                if (pathname === '/api/spotify-sync') {
                  const { url } = body;
                  if (!url) {
                    res.writeHead(400);
                    res.end(JSON.stringify({ error: 'url required' }));
                    return;
                  }
                  
                  let playlistId = '';
                  const trimmedUrl = url.trim();
                  if (trimmedUrl.startsWith('spotify:playlist:')) {
                    playlistId = trimmedUrl.substring('spotify:playlist:'.length);
                  } else {
                    const match = trimmedUrl.match(/playlist\/([a-zA-Z0-9]{22})/);
                    if (match) {
                      playlistId = match[1];
                    }
                  }
                  
                  if (!playlistId) {
                    res.writeHead(400);
                    res.end(JSON.stringify({ error: 'invalid_spotify_url' }));
                    return;
                  }
                  
                  try {
                    const embedUrl = `https://open.spotify.com/embed/playlist/${playlistId}`;
                    const response = await fetchUrl(embedUrl, {
                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
                    });
                    
                    const html = response.body;
                    const scriptMatch = html.match(/<script\s+id="resource"\s+type="application\/json">(.*?)<\/script>/s)
                      || html.match(/<script\s+id="initial-state"\s+type="application\/json">(.*?)<\/script>/s)
                      || html.match(/<script\s+id="__NEXT_DATA__"\s+type="application\/json">(.*?)<\/script>/s);
                      
                    if (scriptMatch) {
                      const jsonStr = scriptMatch[1].trim();
                      const decoded = JSON.parse(jsonStr);
                      const state = decoded.props?.pageProps?.state || decoded.state;
                      const entity = state?.data?.entity;
                      
                      if (entity) {
                        const name = entity.name || 'Spotify Sync';
                        const desc = entity.subtitle || '';
                        const images = entity.coverArt?.sources || [];
                        const imageUrl = images.length > 0 ? images[0].url || '' : '';
                        const trackList = entity.trackList || [];
                        
                        const songs = trackList.map((item: any) => {
                          const uri = item.uri || '';
                          const trackId = uri.split(':').pop() || '';
                          return {
                            id: `spotify_track_${trackId}`,
                            title: item.title || 'Unknown Track',
                            artist: item.subtitle || 'Unknown Artist',
                            album: 'Spotify Playlist',
                            image: imageUrl,
                            duration: Math.floor((Number(item.duration) || 0) / 1000),
                            url: ''
                          };
                        }).filter((s: any) => s.id);
                        
                        const playlist = {
                          id: `spotify_playlist_${playlistId}`,
                          name,
                          description: desc,
                          image: imageUrl,
                          songs
                        };
                        
                        res.writeHead(200);
                        res.end(JSON.stringify({ d: encryptPayload(JSON.stringify(playlist)) }));
                        return;
                      }
                    }
                    
                    res.writeHead(404);
                    res.end(JSON.stringify({ error: 'playlist_not_found_or_private' }));
                  } catch (e: any) {
                    res.writeHead(500);
                    res.end(JSON.stringify({ error: e.message || 'internal_server_error' }));
                  }
                  return;
                }
                
                if (pathname === '/api/lyrics') {
                  const { title, artist, duration = 0 } = body;
                  const lyrics = await fetchLrclib(title, artist || '', Number(duration));
                  if (lyrics) {
                    res.writeHead(200);
                    res.end(JSON.stringify({ d: encryptPayload(lyrics) }));
                  } else {
                    res.writeHead(404);
                    res.end(JSON.stringify({ error: 'lyrics_not_found' }));
                  }
                  return;
                }
                
                if (pathname === '/api/home') {
                  const sections: Record<string, any[]> = {};
                  const queries = {
                    Trending: 'trending hindi songs',
                    Bollywood: 'bollywood hits',
                    Punjabi: 'punjabi hits',
                    TopHits: 'top hindi songs',
                  };
                  
                  for (const [key, q] of Object.entries(queries)) {
                    try {
                      const songs = await saavnSearch(q, 12);
                      sections[key] = songs.map((s: any) => ({
                        id: s.id || '',
                        title: s.song || s.title || '',
                        artist: s.primary_artists || s.subtitle || '',
                        album: s.album || '',
                        image: (s.image || '').replace('http://', 'https://'),
                        duration: Number(s.duration) || 0,
                        language: s.language || '',
                        url: extractMediaUrl(s)
                      })).filter((s: any) => s.id);
                    } catch (_) {
                      sections[key] = [];
                    }
                  }
                  
                  res.writeHead(200);
                  res.end(JSON.stringify({ d: encryptPayload(JSON.stringify(sections)) }));
                  return;
                }
                
                res.writeHead(404);
                res.end(JSON.stringify({ error: 'not_found' }));
              } catch (e: any) {
                res.writeHead(500);
                res.end(JSON.stringify({ error: e.message || 'internal_server_error' }));
              }
            });
            return;
          }
          
          next();
        });
      }
    }
  ],
  server: {
    proxy: {
      '/api-media': {
        target: 'https://aac.saavncdn.com',
        changeOrigin: true,
        agent: keepAliveAgent,
        rewrite: (path) => path.replace(/^\/api-media/, ''),
        headers: {
          'Referer': 'https://www.jiosaavn.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        }
      }
    }
  }
})

