/**
 * ╔══════════════════════════════════════════════════════════╗
 * ║     ROTTY MUSIC — GHOST PROXY SERVER v2.0               ║
 * ║     Ultra-secure backend. All API sources hidden.       ║
 * ║     AES-256 encrypted responses. Firebase App Check.    ║
 * ║     Rate-limited. Cloudflare-ready.                     ║
 * ╚══════════════════════════════════════════════════════════╝
 *
 * Deploy on Railway / Render / Vercel Edge:
 *   npm install && node server.js
 *
 * Env vars required:
 *   ROTTY_SECRET_KEY      — 32-char AES-256 key
 *   FIREBASE_PROJECT_ID   — Firebase project (for App Check)
 *   PORT                  — (optional, defaults to 3000)
 */

const express  = require('express');
const crypto   = require('crypto');
const https    = require('https');
const http     = require('http');
const url      = require('url');

const app = express();
app.use(express.json());

// ─── Rate Limiting (in-memory, simple) ─────────────────────────────
const RATE_LIMITS = {};
const RATE_WINDOW_MS = 60000; // 1 minute
const MAX_REQUESTS = 60;      // 60 requests per minute

function rateLimit(ip) {
  const now = Date.now();
  if (!RATE_LIMITS[ip]) RATE_LIMITS[ip] = { count: 0, reset: now + RATE_WINDOW_MS };
  if (now > RATE_LIMITS[ip].reset) {
    RATE_LIMITS[ip] = { count: 0, reset: now + RATE_WINDOW_MS };
  }
  RATE_LIMITS[ip].count++;
  return RATE_LIMITS[ip].count <= MAX_REQUESTS;
}

// Rate limit middleware
app.use((req, res, next) => {
  const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';
  if (!rateLimit(ip)) {
    return res.status(429).json({ error: 'rate_limited', retry_after: 60 });
  }
  next();
});

// ─── Firebase App Check Middleware ──────────────────────────────────
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || '';

async function verifyAppCheck(req, res, next) {
  // Skip App Check if not configured (dev mode)
  if (!FIREBASE_PROJECT_ID) return next();

  const token = req.headers['x-firebase-appcheck'];
  if (!token) {
    return res.status(401).json({ error: 'app_check_missing' });
  }

  try {
    // Verify token with Firebase REST API
    const verifyUrl = `https://firebaseappcheck.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}:verifyAppCheckToken`;
    const verifyRes = await fetchUrl(verifyUrl, {
      'Content-Type': 'application/json',
    }, 'POST', JSON.stringify({ token }));

    if (verifyRes.status !== 200) {
      return res.status(401).json({ error: 'app_check_invalid' });
    }
    next();
  } catch (_) {
    return res.status(401).json({ error: 'app_check_failed' });
  }
}

app.use('/api', verifyAppCheck);

// ─── AES-256-CBC Encryption ────────────────────────────────────────
const SECRET_KEY = process.env.ROTTY_SECRET_KEY || 'rotty-ghost-key-32chars-xxxxxxxx';
const KEY_BUF    = Buffer.from(SECRET_KEY.slice(0, 32).padEnd(32, '0'), 'utf8');

function encryptPayload(plainText) {
  const iv         = crypto.randomBytes(16);
  const cipher     = crypto.createCipheriv('aes-256-cbc', KEY_BUF, iv);
  const encrypted  = Buffer.concat([cipher.update(plainText, 'utf8'), cipher.final()]);
  // Return as base64 for cleaner transport
  return iv.toString('base64') + ':' + encrypted.toString('base64');
}

// ─── HTTP Helper (supports POST for App Check verify) ──────────────
function fetchUrl(targetUrl, headers = {}, method = 'GET', body = null) {
  return new Promise((resolve, reject) => {
    const parsed   = url.parse(targetUrl);
    const lib      = parsed.protocol === 'https:' ? https : http;
    const options  = {
      hostname : parsed.hostname,
      path     : parsed.path,
      method   : method,
      headers  : {
        'User-Agent' : 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Accept'     : 'application/json',
        ...headers,
      },
      timeout  : 12000,
    };
    const req = lib.request(options, (res) => {
      let data = '';
      res.on('data', (d) => (data += d));
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    req.on('error',   reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    if (body) req.write(body);
    req.end();
  });
}

// ─── JioSaavn Source A: Direct web API ────────────────────────────
async function saavnSearch(query, limit = 25) {
  const qs = new URLSearchParams({
    __call : 'search.getResults',
    _format : 'json',
    _marker : '0',
    ctx     : 'web6dot0',
    q       : query,
    p       : '1',
    n       : String(limit),
    type    : 'song',
  });
  const res = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
    Referer: 'https://www.jiosaavn.com',
  });
  if (res.status !== 200) throw new Error('saavn_a_fail');
  const body = JSON.parse(res.body);
  return body.results || [];
}

// ─── JioSaavn Source B: Fallback ──────────────────────────────────
async function saavnFallbackSearch(query, limit = 25) {
  const encQ = encodeURIComponent(query);
  const res  = await fetchUrl(
    `https://saavn.sumit.co/api/search/songs?query=${encQ}&page=1&limit=${limit}`
  );
  if (res.status !== 200) throw new Error('saavn_b_fail');
  const body = JSON.parse(res.body);
  return body?.data?.results || [];
}

// ─── Extract 320kbps URL ──────────────────────────────────────────
function extract320Url(song) {
  if (Array.isArray(song.downloadUrl)) {
    const h = song.downloadUrl.find(d => d.quality === '320kbps') ||
              song.downloadUrl[song.downloadUrl.length - 1];
    if (h?.link) return h.link;
  }
  const info = song.more_info || song;
  if (info.media_preview_url) {
    return info.media_preview_url.replace('/preview/', '/aac/').replace('_96_p.mp4', '_320.mp4');
  }
  if (typeof info.vlink === 'string') return info.vlink;
  return null;
}

// ─── LRCLIB — synced lyrics ────────────────────────────────────────
async function fetchLrclib(title, artist, duration = 0) {
  try {
    const q = encodeURIComponent(title);
    const a = encodeURIComponent(artist);
    const res = await fetchUrl(
      `https://lrclib.net/api/search?q=${q}&artist_name=${a}`,
      { 'Lrclib-Client': 'RottyMusic v2.0' }
    );
    if (res.status !== 200) return null;
    const results = JSON.parse(res.body);
    if (!Array.isArray(results) || results.length === 0) return null;

    let best = null;
    let bestScore = Infinity;
    for (const r of results) {
      if (!r.syncedLyrics && !r.plainLyrics) continue;
      const durDiff = duration > 0 ? Math.abs((r.duration || 0) - duration) : 0;
      const score   = durDiff + (r.syncedLyrics ? 0 : 100);
      if (score < bestScore) { bestScore = score; best = r; }
    }
    if (!best) return null;
    return best.syncedLyrics || best.plainLyrics;
  } catch (_) { return null; }
}

// ═══════════════════════════════════════════════════════════════════
// ROUTES
// ═══════════════════════════════════════════════════════════════════

app.get('/', (_, res) => res.json({ ok: true, service: 'rotty-ghost', version: '2.0' }));

// POST /api/search
app.post('/api/search', async (req, res) => {
  const { query, limit = 25 } = req.body;
  if (!query || typeof query !== 'string') {
    return res.status(400).json({ error: 'query required' });
  }

  let songs = [];
  try { songs = await saavnSearch(query.trim(), limit); }
  catch (_) {
    try { songs = await saavnFallbackSearch(query.trim(), limit); }
    catch (__) { return res.status(502).json({ error: 'all_sources_failed' }); }
  }

  const sanitized = songs.map(s => ({
    id      : s.id || s.songid || '',
    title   : s.title || s.song || '',
    artist  : s.subtitle || s.primary_artists || s.artist || '',
    album   : s.album || '',
    image   : (s.image || '').replace('http://', 'https://'),
    duration: s.duration || s.more_info?.duration || 0,
    language: s.language || '',
  })).filter(s => s.id);

  return res.json({ d: encryptPayload(JSON.stringify(sanitized)) });
});

// POST /api/stream
app.post('/api/stream', async (req, res) => {
  const { id, title, artist } = req.body;
  if (!id) return res.status(400).json({ error: 'id required' });

  let streamUrl = null;

  try {
    const qs  = new URLSearchParams({
      __call  : 'song.getDetails', _format : 'json', _marker : '0',
      ctx     : 'web6dot0', pids : id,
    });
    const r   = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
      Referer: 'https://www.jiosaavn.com',
    });
    if (r.status === 200) {
      const body = JSON.parse(r.body);
      const songs = Array.isArray(body) ? body : (body?.songs || []);
      if (songs.length > 0) streamUrl = extract320Url(songs[0]);
    }
  } catch (_) {}

  if (!streamUrl) {
    try {
      const r = await fetchUrl(`https://saavn.sumit.co/api/songs/${id}`);
      if (r.status === 200) {
        const body = JSON.parse(r.body);
        const song = body?.data?.[0] || body?.data || null;
        if (song) streamUrl = extract320Url(song);
      }
    } catch (_) {}
  }

  if (!streamUrl) return res.status(404).json({ error: 'stream_not_found' });
  return res.json({ d: encryptPayload(streamUrl) });
});

// POST /api/lyrics
app.post('/api/lyrics', async (req, res) => {
  const { title, artist, duration = 0 } = req.body;
  if (!title) return res.status(400).json({ error: 'title required' });
  const lyrics = await fetchLrclib(title, artist || '', Number(duration));
  if (!lyrics) return res.status(404).json({ error: 'lyrics_not_found' });
  return res.json({ d: encryptPayload(lyrics) });
});

// POST /api/home
app.post('/api/home', async (req, res) => {
  const sections = {};
  const queries  = {
    Trending  : 'trending hindi songs 2025',
    Bollywood : 'bollywood hits 2025',
    Punjabi   : 'punjabi hits',
    TopHits   : 'top hindi songs',
  };
  for (const [key, q] of Object.entries(queries)) {
    try {
      const songs = await saavnSearch(q, 12);
      sections[key] = songs.slice(0, 12).map(s => ({
        id: s.id || '', title: s.title || s.song || '',
        artist: s.subtitle || s.primary_artists || '',
        album: s.album || '', image: (s.image || '').replace('http://', 'https://'),
        duration: s.duration || s.more_info?.duration || 0,
        language: s.language || '',
      })).filter(s => s.id);
    } catch (_) { sections[key] = []; }
  }
  return res.json({ d: encryptPayload(JSON.stringify(sections)) });
});

// POST /api/details — Get song details
app.post('/api/details', async (req, res) => {
  const { id } = req.body;
  if (!id) return res.status(400).json({ error: 'id required' });

  try {
    const qs = new URLSearchParams({
      __call: 'song.getDetails', _format: 'json', _marker: '0',
      ctx: 'web6dot0', pids: id,
    });
    const r = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
      Referer: 'https://www.jiosaavn.com',
    });
    if (r.status === 200) {
      return res.json({ d: encryptPayload(r.body) });
    }
  } catch (_) {}

  // Fallback
  try {
    const r = await fetchUrl(`https://saavn.sumit.co/api/songs/${id}`);
    if (r.status === 200) {
      return res.json({ d: encryptPayload(r.body) });
    }
  } catch (_) {}

  return res.status(404).json({ error: 'not_found' });
});

// ─── Start server ──────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🔒 Rotty Ghost Proxy v2.0 running on port ${PORT}`);
  console.log(`🔑 AES-256 encryption: ACTIVE`);
  console.log(`🛡️ Firebase App Check: ${FIREBASE_PROJECT_ID ? 'ACTIVE' : 'DISABLED (dev mode)'}`);
  console.log(`⏱️ Rate limiting: 60 req/min per IP`);
});
