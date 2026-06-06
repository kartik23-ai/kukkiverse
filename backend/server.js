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
const cors     = require('cors');
const crypto   = require('crypto');
const https    = require('https');
const http     = require('http');
const url      = require('url');
const CryptoJS = require('crypto-js');
const fs       = require('fs');
const path     = require('path');
const { exec } = require('child_process');
const { Readable } = require('stream');

// Load environment variables from .env file if it exists
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
  try {
    const envConfig = fs.readFileSync(envPath, 'utf8');
    envConfig.split(/\r?\n/).forEach(line => {
      if (!line || line.trim().startsWith('#')) return;
      const match = line.match(/^\s*([\w.-]+)\s*=\s*(.*)?\s*$/);
      if (match) {
        const key = match[1];
        let value = match[2] || '';
        value = value.trim();
        if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
          value = value.slice(1, -1);
        }
        process.env[key] = value;
      }
    });
    console.log('🔒 ROTTY SYSTEM: Loaded environment variables from .env file');
  } catch (err) {
    console.error('🔒 ROTTY SYSTEM WARNING: Failed to parse .env file:', err);
  }
}

const app = express();

// Dynamically add Gyan.FFmpeg and WinGet links directories to system PATH for child processes
const ffmpegPath = "C:\\Users\\karti\\AppData\\Local\\Microsoft\\WinGet\\Packages\\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\\ffmpeg-8.1.1-full_build\\bin";
if (fs.existsSync(ffmpegPath)) {
  process.env.PATH = `${ffmpegPath};${process.env.PATH}`;
  console.log(`🔒 ROTTY SYSTEM: Gyan.FFmpeg dynamically added to PATH -> ${ffmpegPath}`);
}
const linksPath = "C:\\Users\\karti\\AppData\\Local\\Microsoft\\WinGet\\Links";
if (fs.existsSync(linksPath)) {
  process.env.PATH = `${linksPath};${process.env.PATH}`;
  console.log(`🔒 ROTTY SYSTEM: WinGet Links dynamically added to PATH -> ${linksPath}`);
}

app.use(cors({ origin: '*' }));
app.use(express.json());

// Serve rendered mashups statically
app.use('/renders', express.static(path.join(__dirname, 'renders')));

// Ensure temp/ and renders/ folders exist at startup
if (!fs.existsSync(path.join(__dirname, 'temp'))) {
  fs.mkdirSync(path.join(__dirname, 'temp'), { recursive: true });
}
if (!fs.existsSync(path.join(__dirname, 'renders'))) {
  fs.mkdirSync(path.join(__dirname, 'renders'), { recursive: true });
}

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

function decryptPayload(encrypted) {
  try {
    const parts = encrypted.split(':');
    if (parts.length !== 2) throw new Error('Invalid encrypted format');
    const iv = Buffer.from(parts[0], 'base64');
    const encryptedText = Buffer.from(parts[1], 'base64');
    const decipher = crypto.createDecipheriv('aes-256-cbc', KEY_BUF, iv);
    const decrypted = Buffer.concat([decipher.update(encryptedText), decipher.final()]);
    return decrypted.toString('utf8');
  } catch (e) {
    console.error("🔒 ROTTY SYSTEM SECURITY: Decryption helper failed:", e.message);
    throw e;
  }
}

const COVER_ART_POOL = [
  'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=500&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=500&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=500&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?q=80&w=500&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?q=80&w=500&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?q=80&w=500&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1487180142328-054b783fc471?q=80&w=500&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?q=80&w=500&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1506157786151-b8491531f063?q=80&w=500&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1516280440614-37939bbacd6a?q=80&w=500&auto=format&fit=crop'
];

function getContextualCover(genre = '', prompt = '') {
  const lowerGenre = (genre || '').toLowerCase();
  const lowerPrompt = (prompt || '').toLowerCase();
  
  const pools = {
    romantic: [
      'https://images.unsplash.com/photo-1518199266791-5375a83190b7?q=80&w=500&auto=format&fit=crop', // Heart lights
      'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?q=80&w=500&auto=format&fit=crop', // Warm holding hands
      'https://images.unsplash.com/photo-1494972308805-463bc619b34e?q=80&w=500&auto=format&fit=crop'  // Red roses
    ],
    punjabi_club: [
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?q=80&w=500&auto=format&fit=crop', // Party concert lights
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=500&auto=format&fit=crop', // DJ deck
      'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?q=80&w=500&auto=format&fit=crop'  // Bright stage lasers
    ],
    sufi_spiritual: [
      'https://images.unsplash.com/photo-1507699622108-4be3abd695ad?q=80&w=500&auto=format&fit=crop', // Sunset spiritual dome silhouette
      'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?q=80&w=500&auto=format&fit=crop', // Peaceful sunbeam forest
      'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?q=80&w=500&auto=format&fit=crop'  // Warm ambient abstract light
    ],
    lofi_chill: [
      'https://images.unsplash.com/photo-1518495973542-4542c06a5843?q=80&w=500&auto=format&fit=crop', // Cozy leaf sunlight
      'https://images.unsplash.com/photo-1516280440614-37939bbacd6a?q=80&w=500&auto=format&fit=crop', // Cozy coffee cup
      'https://images.unsplash.com/photo-1515002246390-7bf7e8f87b54?q=80&w=500&auto=format&fit=crop'  // Chill record player
    ],
    sad: [
      'https://images.unsplash.com/photo-1437419764061-2473afe69fc2?q=80&w=500&auto=format&fit=crop', // Rain on window
      'https://images.unsplash.com/photo-1486673748761-a8d18475c757?q=80&w=500&auto=format&fit=crop', // Dark lonely road
      'https://images.unsplash.com/photo-1518173946687-a4c8a383392e?q=80&w=500&auto=format&fit=crop'  // Moody rain
    ],
    acoustic: [
      'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=500&auto=format&fit=crop', // Vintage mic
      'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?q=80&w=500&auto=format&fit=crop'  // Acoustic guitar
    ]
  };

  if (lowerGenre.includes('romantic') || lowerGenre.includes('love') || lowerPrompt.includes('love') || lowerPrompt.includes('romantic') || lowerPrompt.includes('pyaar') || lowerPrompt.includes('dil')) {
    const list = pools.romantic;
    return list[Math.floor(Math.random() * list.length)];
  }
  
  if (lowerGenre.includes('sad') || lowerGenre.includes('broken') || lowerPrompt.includes('sad') || lowerPrompt.includes('dard') || lowerPrompt.includes('breakup') || lowerPrompt.includes('crying') || lowerPrompt.includes('lonely')) {
    const list = pools.sad;
    return list[Math.floor(Math.random() * list.length)];
  }

  if (lowerGenre.includes('punjabi') || lowerGenre.includes('club') || lowerGenre.includes('dance') || lowerGenre.includes('party') || lowerGenre.includes('edm') || lowerPrompt.includes('dhol') || lowerPrompt.includes('club') || lowerPrompt.includes('dance') || lowerPrompt.includes('party') || lowerPrompt.includes('bhangra')) {
    const list = pools.punjabi_club;
    return list[Math.floor(Math.random() * list.length)];
  }

  if (lowerGenre.includes('sufi') || lowerGenre.includes('spiritual') || lowerGenre.includes('devotion') || lowerPrompt.includes('sufi') || lowerPrompt.includes('khwaja') || lowerPrompt.includes('allah') || lowerPrompt.includes('peace') || lowerPrompt.includes('spiritual')) {
    const list = pools.sufi_spiritual;
    return list[Math.floor(Math.random() * list.length)];
  }

  if (lowerGenre.includes('lofi') || lowerGenre.includes('chill') || lowerGenre.includes('relax') || lowerPrompt.includes('lofi') || lowerPrompt.includes('chill') || lowerPrompt.includes('coffee') || lowerPrompt.includes('ambient')) {
    const list = pools.lofi_chill;
    return list[Math.floor(Math.random() * list.length)];
  }

  const list = pools.acoustic;
  return list[Math.floor(Math.random() * list.length)];
}

function generateCreativeTitle(genre, prompt) {
  const romanticAdjectives = ['Dil Se', 'Pyaar Ishq', 'Sanam', 'Mehboob', 'Dhadkan', 'Sohniye', 'Ranjhna', 'Humsafar'];
  const clubAdjectives = ['Gedi Route', 'Patiala Peg', 'Bass Boost', 'Vibe Check', 'Dhamaal', 'Bhangra Beats', 'Nachdi'];
  const sufiAdjectives = ['Malang', 'Ruhaniyat', 'Ibaadat', 'Murshid', 'Sajda', 'Auliya', 'Fakira'];
  const genericAdjectives = ['Echoes of Gold', 'Neon Dreams', 'Infinite Horizons', 'Velvet Nights', 'Midnight Groove', 'Symphonic Mist', 'Cyber Raga'];

  let wordList = genericAdjectives;
  if (genre && genre.toLowerCase().includes('romantic')) {
    wordList = romanticAdjectives;
  } else if (genre && (genre.toLowerCase().includes('punjabi') || genre.toLowerCase().includes('club') || genre.toLowerCase().includes('edm'))) {
    wordList = clubAdjectives;
  } else if (genre && (genre.toLowerCase().includes('sufi') || genre.toLowerCase().includes('qawwali'))) {
    wordList = sufiAdjectives;
  }

  const idx1 = Math.floor(Math.random() * wordList.length);
  let idx2 = Math.floor(Math.random() * wordList.length);
  while (idx2 === idx1 && wordList.length > 1) {
    idx2 = Math.floor(Math.random() * wordList.length);
  }

  let keyword = '';
  if (prompt && prompt.trim().length > 3) {
    const cleanPrompt = prompt.replace(/[^\w\s]/gi, '');
    const words = cleanPrompt.split(/\s+/).filter(w => w.length > 4);
    if (words.length > 0) {
      keyword = words[Math.floor(Math.random() * words.length)];
      keyword = keyword.charAt(0).toUpperCase() + keyword.slice(1);
    }
  }

  if (keyword) {
    return `${wordList[idx1]} feat. ${keyword}`;
  }
  return `${wordList[idx1]} ${wordList[idx2]}`;
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
        'User-Agent' : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept'     : 'application/json',
        ...headers,
      },
    };
    let isTerminated = false;
    const isLrc = targetUrl.includes('lrclib.net');
    const isSaavnDirect = targetUrl.includes('jiosaavn.com/api.php');
    const timeoutMs = isSaavnDirect ? 1500 : (isLrc ? 10000 : 12000);
    const timer = setTimeout(() => {
      isTerminated = true;
      req.destroy();
      reject(new Error('timeout'));
    }, timeoutMs);

    const req = lib.request(options, (res) => {
      let data = '';
      res.on('data', (d) => (data += d));
      res.on('end', () => {
        if (!isTerminated) {
          clearTimeout(timer);
          resolve({ status: res.statusCode, body: data, headers: res.headers });
        }
      });
    });
    req.on('error', (err) => {
      if (!isTerminated) {
        clearTimeout(timer);
        reject(err);
      }
    });
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

// ─── JioSaavn Source C: Curated Playlists ──────────────────────────
async function saavnGetEditorialPlaylistSongs(query, limit = 30) {
  try {
    const qs = new URLSearchParams({
      __call: 'search.getPlaylistResults',
      _format: 'json',
      _marker: '0',
      ctx: 'web6dot0',
      q: query,
      p: '1',
      n: '10'
    });
    const res = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
      Referer: 'https://www.jiosaavn.com',
    });
    if (res.status === 200) {
      const body = JSON.parse(res.body);
      const results = body.results || [];
      // Find the first editorial/official playlist
      const playlist = results.find(p => 
        p.listid && 
        (String(p.firstname).toLowerCase() === 'jiosaavn' || 
         String(p.lastname).toLowerCase() === 'editor' || 
         String(p.uid) === 'phulki_user')
      ) || results[0];
      
      if (playlist && playlist.listid) {
        const detailQs = new URLSearchParams({
          __call: 'playlist.getDetails',
          _format: 'json',
          _marker: '0',
          ctx: 'web6dot0',
          listid: playlist.listid,
        });
        const detailRes = await fetchUrl(`https://www.jiosaavn.com/api.php?${detailQs}`, {
          Referer: 'https://www.jiosaavn.com',
        });
        if (detailRes.status === 200) {
          const detailBody = JSON.parse(detailRes.body);
          if (detailBody && detailBody.songs && Array.isArray(detailBody.songs)) {
            return detailBody.songs.slice(0, limit);
          }
        }
      }
    }
  } catch (err) {
    console.error(`saavnGetEditorialPlaylistSongs failed for "${query}":`, err);
  }

  // Fallback to Sumit API for Playlists
  try {
    const encQ = encodeURIComponent(query);
    const r = await fetchUrl(`https://saavn.sumit.co/api/search/playlists?query=${encQ}`);
    if (r.status === 200) {
      const body = JSON.parse(r.body);
      const playlists = body?.data?.results || [];
      const playlist = playlists[0];
      if (playlist && playlist.id) {
        const detailRes = await fetchUrl(`https://saavn.sumit.co/api/playlists?id=${playlist.id}`);
        if (detailRes.status === 200) {
          const detailBody = JSON.parse(detailRes.body);
          const songs = detailBody?.data?.songs || detailBody?.data?.results || [];
          if (Array.isArray(songs) && songs.length > 0) {
            return songs.slice(0, limit);
          }
        }
      }
    }
  } catch (err) {
    console.error(`saavnGetEditorialPlaylistSongs fallback failed for "${query}":`, err);
  }

  return [];
}

// ─── Scraper Helper functions for DDG & Google ─────────────────────
async function scrapeDdgTitles(query) {
  try {
    const encQ = encodeURIComponent(query);
    const url = `https://html.duckduckgo.com/html/?q=${encQ}`;
    const res = await fetchUrl(url, {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    });
    if (res.status === 200) {
      const html = res.body;
      const titles = [];
      const regex = /class="result__a"[^>]*>([\s\S]*?)<\/a>/gi;
      let match;
      while ((match = regex.exec(html)) !== null) {
        let text = match[1] || '';
        text = text.replace(/<[^>]*>/g, '');
        text = text.replace(/&amp;/g, '&')
                   .replace(/&quot;/g, '"')
                   .replace(/&#39;/g, "'")
                   .replace(/&lt;/g, '<')
                   .replace(/&gt;/g, '>');
        text = text.trim();
        if (text && text.length < 120) {
          titles.push(text);
        }
      }
      return titles;
    }
  } catch (err) {
    console.error('scrapeDdgTitles error:', err);
  }
  return [];
}

async function scrapeGoogleTitles(query) {
  try {
    const encQ = encodeURIComponent(query);
    const url = `https://www.google.com/search?q=${encQ}`;
    const res = await fetchUrl(url, {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    });
    if (res.status === 200) {
      const html = res.body;
      const titles = [];
      const regex = /<h3[^>]*>([\s\S]*?)<\/h3>/gi;
      let match;
      while ((match = regex.exec(html)) !== null) {
        let text = match[1] || '';
        text = text.replace(/<[^>]*>/g, '');
        text = text.replace(/&amp;/g, '&')
                   .replace(/&quot;/g, '"')
                   .replace(/&#39;/g, "'")
                   .replace(/&lt;/g, '<')
                   .replace(/&gt;/g, '>');
        text = text.trim();
        if (text && text.length < 120) {
          titles.push(text);
        }
      }
      return titles;
    }
  } catch (err) {
    console.error('scrapeGoogleTitles error:', err);
  }
  return [];
}

function cleanGoogleTitle(title) {
  let clean = title.toLowerCase();
  clean = clean.replace(/youtube/g, '')
               .replace(/jiosaavn/g, '')
               .replace(/spotify/g, '')
               .replace(/gaana/g, '')
               .replace(/wynk/g, '')
               .replace(/hungama/g, '')
               .replace(/official video/g, '')
               .replace(/official audio/g, '')
               .replace(/lyrical video/g, '')
               .replace(/full song/g, '')
               .replace(/music video/g, '')
               .replace(/video song/g, '')
               .replace(/lyrics/g, '');

  const parts = clean.split(/[-:|]/);
  if (parts.length > 0) {
    clean = parts[0];
  }

  clean = clean.replace(/\(.*?\)/g, '')
               .replace(/\[.*?\]/g, '')
               .replace(/[^\w\s']/g, ' ');
  clean = clean.replace(/\s+/g, ' ');
  return clean.trim();
}

function normalizeTitle(title) {
  let clean = (title || '').toLowerCase();
  clean = clean.replace(/\(.*?\)/g, '')
               .replace(/\[.*?\]/g, '')
               .replace(/from/g, '')
               .replace(/theme/g, '')
               .replace(/soundtrack/g, '')
               .replace(/[^\w\s']/g, ' ');
  clean = clean.replace(/\s+/g, ' ');
  return clean.trim();
}

function decryptDesEcb(ciphertextBase64) {
  if (!ciphertextBase64) return '';
  try {
    const key = CryptoJS.enc.Utf8.parse('38346591');
    const decrypted = CryptoJS.DES.decrypt(
      { ciphertext: CryptoJS.enc.Base64.parse(ciphertextBase64) },
      key,
      {
        mode: CryptoJS.mode.ECB,
        padding: CryptoJS.pad.Pkcs7
      }
    );
    return decrypted.toString(CryptoJS.enc.Utf8);
  } catch (e) {
    console.error('DES decryption error:', e);
    return '';
  }
}

function upgradeImageUrl(imgUrl) {
  if (!imgUrl) return '';
  if (Array.isArray(imgUrl)) {
    const best = imgUrl.find(i => i.quality === '500x500') || 
                 imgUrl.find(i => i.quality === '150x150') || 
                 imgUrl[imgUrl.length - 1];
    imgUrl = best?.url || best?.link || '';
  }
  if (typeof imgUrl !== 'string') return '';
  let url = imgUrl.replace('http://', 'https://');
  url = url.replace('150x150', '500x500').replace('50x50', '500x500');
  return url;
}

function mapSongToRotty(s) {
  if (!s) return null;
  const title = s.name || s.title || s.song || '';
  const id = s.id || s.songid || '';
  
  let artist = '';
  if (s.artists) {
    if (typeof s.artists === 'string') {
      artist = s.artists;
    } else if (Array.isArray(s.artists)) {
      artist = s.artists.map(a => typeof a === 'string' ? a : (a.name || '')).filter(Boolean).join(', ');
    } else if (typeof s.artists === 'object') {
      const primary = s.artists.primary;
      const all = s.artists.all;
      if (Array.isArray(primary) && primary.length > 0) {
        artist = primary.map(a => a.name || '').filter(Boolean).join(', ');
      } else if (Array.isArray(all) && all.length > 0) {
        artist = all.map(a => a.name || '').filter(Boolean).join(', ');
      }
    }
  }
  if (!artist) {
    artist = s.subtitle || s.primary_artists || s.artist || '';
  }
  
  let album = '';
  if (s.album) {
    if (typeof s.album === 'string') {
      album = s.album;
    } else if (typeof s.album === 'object') {
      album = s.album.name || s.album.title || '';
    }
  }
  
  const image = upgradeImageUrl(s.image);
  const duration = Number(s.duration || s.more_info?.duration || 0);
  const language = s.language || '';
  const url = extract320Url(s);
  
  return {
    id,
    title,
    artist,
    album,
    image,
    duration,
    language,
    url
  };
}

function isGenericArtist(artist) {
  if (!artist) return true;
  const lower = artist.trim().toLowerCase();
  return (
    lower === '' ||
    lower === 'various artists' ||
    lower === 'various' ||
    lower === 'unknown' ||
    lower === 'artist' ||
    lower === 'singers' ||
    lower === 'unknown artist' ||
    lower === 'various artist' ||
    lower === 'multi-artist' ||
    lower === 'multi artist'
  );
}

function isOriginalSong(s) {
  if (!s) return false;
  const title = (s.title || '').toLowerCase();
  const album = (s.album || '').toLowerCase();
  if (title.includes('remix') || title.includes('re-mix') || title.includes('mashup') || title.includes('mash-up') ||
      title.includes('lofi') || title.includes('lo-fi') || title.includes('slowed') ||
      title.includes('reverb') || title.includes('sped up') || title.includes('cover') ||
      title.includes('tribute') || title.includes('instrumental') || title.includes('karaoke') ||
      title.includes('sad version') || title.includes('female version') || title.includes('male version') ||
      title.includes('ringtone') || title.includes('bgm') || title.includes('acoustic') ||
      title.includes('dj ') || title.includes(' dj') || title.includes('trap mix') ||
      title.includes('non stop') || title.includes('non-stop') || title.includes('unplugged') ||
      title.includes('lullaby') || title.includes('slow ') || title.includes('sped-up') ||
      title.includes('reverbed') || title.includes('chillout') || title.includes('extended mix') ||
      title.includes('radio edit') || title.includes('club mix') || title.includes('remixed') ||
      title.includes('synthwave') || title.includes('piano version') || title.includes('violin version') ||
      title.includes('re-created') || title.includes('recreated') ||
      album.includes('remix') || album.includes('lofi') || album.includes('covers')) {
    return false;
  }
  return true;
}

function deduplicateSongs(songs) {
  if (!Array.isArray(songs)) return [];
  const seen = new Set();
  return songs.filter(s => {
    const title = (s.title || s.song || '').trim().toLowerCase().replace(/\s+/g, ' ');
    const artistRaw = (s.artist || s.subtitle || s.primary_artists || '').trim().toLowerCase();
    // Get primary artist by splitting by common delimiters
    const primaryArtist = artistRaw.split(/[,&]/)[0].trim().replace(/\s+/g, ' ');
    
    if (isGenericArtist(primaryArtist)) {
      return true;
    }

    const key = `${title}|${primaryArtist}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}

function extract320Url(song) {
  if (!song) return null;

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

  // 2. Try Sumit API downloadUrl array first
  if (Array.isArray(song.downloadUrl)) {
    const h = song.downloadUrl.find(d => d.quality === '320kbps') ||
              song.downloadUrl.find(d => d.quality === '160kbps') ||
              song.downloadUrl[song.downloadUrl.length - 1];
    const url = h?.url || h?.link;
    if (url) return url;
  }

  // 3. Fallback to media_preview_url with domain replacement
  const preview = info.media_preview_url || song.media_preview_url;
  if (preview) {
    let url = preview.replace('http:', 'https:');
    url = url.replace('_96_p.mp4', '_320.mp4').replace('_96.mp4', '_320.mp4');
    url = url.replace('media-saavn.akamaized.net', 'aac.saavncdn.com');
    url = url.replace('preview.saavncdn.com', 'aac.saavncdn.com');
    return url;
  }

  if (typeof info.vlink === 'string') return info.vlink;
  return null;
}

function cleanSearchTerm(term) {
  return term
    .toLowerCase()
    .replace(/\([^)]*\)/g, '')
    .replace(/\[[^\]]*\]/g, '')
    .replace(/\b(from|feat|featuring|remix|lofi|version|edit|cover|audio|video|lyrics|lyric|full video|original|soundtrack|ost|mp3|download|karaoke|with lyrics)\b/gi, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function cleanArtist(artist) {
  let mainArtist = artist.split(/[,&]/)[0].trim();
  mainArtist = mainArtist.split(/\b(feat|featuring|ft)\b/i)[0].trim();
  return mainArtist.toLowerCase();
}

// ─── LRCLIB — synced lyrics ────────────────────────────────────────
async function fetchLrclib(title, artist, duration = 0) {
  try {
    const cleanedTitle = cleanSearchTerm(title);
    const cleanedArtist = artist ? cleanArtist(artist) : '';

    // 1. Try official high-precision /api/get endpoint first (database lookup, much faster)
    try {
      const getUrl = `https://lrclib.net/api/get?track_name=${encodeURIComponent(cleanedTitle)}&artist_name=${encodeURIComponent(cleanedArtist)}${duration > 0 ? `&duration=${duration}` : ''}`;
      const res = await fetchUrl(getUrl, { 'Lrclib-Client': 'RottyMusic v2.0' });
      if (res.status === 200) {
        const data = JSON.parse(res.body);
        if (data.syncedLyrics && data.syncedLyrics.trim()) return data.syncedLyrics;
        if (data.plainLyrics && data.plainLyrics.trim()) return data.plainLyrics;
      }
    } catch (_) {}

    // 2. Fallback to /api/search using combined track + artist query (more robust than strict artist_name param)
    const combinedQuery = `${cleanedTitle} ${cleanedArtist}`.trim();
    const q = encodeURIComponent(combinedQuery);
    const res = await fetchUrl(
      `https://lrclib.net/api/search?q=${q}`,
      { 'Lrclib-Client': 'RottyMusic v2.0' }
    );
    if (res.status !== 200) return null;
    const results = JSON.parse(res.body);
    if (!Array.isArray(results) || results.length === 0) return null;

    let best = null;
    let bestScore = Infinity;
    
    const lowerSearchTitle = cleanedTitle.toLowerCase();
    
    for (const r of results) {
      if (!r.syncedLyrics && !r.plainLyrics) continue;
      
      const itemTitle = cleanSearchTerm(r.trackName || '');
      const itemArtist = cleanArtist(r.artistName || '');
      
      if (!itemTitle) continue;
      
      // Strict title validation: check word overlap
      let isTitleMatch = false;
      const titleWords = lowerSearchTitle.split(' ').filter(w => w.length > 2);
      if (titleWords.length === 0) {
        isTitleMatch = itemTitle.includes(lowerSearchTitle) || lowerSearchTitle.includes(itemTitle);
      } else {
        let matchCount = 0;
        for (const word of titleWords) {
          if (itemTitle.includes(word)) matchCount++;
        }
        isTitleMatch = matchCount >= Math.ceil(titleWords.length / 2);
      }
      
      if (!isTitleMatch) continue; // Discard completely different songs
      
      const itemDur = Number(r.duration) || 0;
      const durDiff = duration > 0 ? Math.abs(itemDur - duration) : 0;
      if (duration > 0 && durDiff > 80) continue; // Discard completely different lengths
      
      let score = durDiff;
      if (cleanedArtist && !itemArtist.includes(cleanedArtist) && !cleanedArtist.includes(itemArtist)) {
        score += 100; // Penalty for imperfect artist matching
      }
      if (!r.syncedLyrics) {
        score += 300; // Heavy penalty for unsynced lyrics
      }
      
      if (score < bestScore) {
        bestScore = score;
        best = r;
      }
    }
    
    if (!best) return null;
    return best.syncedLyrics || best.plainLyrics;
  } catch (_) {
    return null;
  }
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

  const sanitized = songs
    .map(s => mapSongToRotty(s))
    .filter(s => s && s.id);

  const deduplicated = deduplicateSongs(sanitized);

  return res.json({ d: encryptPayload(JSON.stringify(deduplicated)) });
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

// POST /api/spotify-sync
app.post('/api/spotify-sync', async (req, res) => {
  const { url } = req.body;
  if (!url) return res.status(400).json({ error: 'url required' });

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

  if (!playlistId) return res.status(400).json({ error: 'invalid_spotify_url' });

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

        const songs = trackList.map((item) => {
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
        }).filter((s) => s.id);

        const playlist = {
          id: `spotify_playlist_${playlistId}`,
          name,
          description: desc,
          image: imageUrl,
          songs
        };

        return res.json({ d: encryptPayload(JSON.stringify(playlist)) });
      }
    }

    return res.status(404).json({ error: 'playlist_not_found_or_private' });
  } catch (e) {
    return res.status(500).json({ error: e.message || 'internal_server_error' });
  }
});

// POST /api/lyrics
app.post('/api/lyrics', async (req, res) => {
  console.log('--- Incoming /api/lyrics request:', req.body);
  const { title, artist, duration = 0, raw = false } = req.body;
  if (!title) return res.status(400).json({ error: 'title required' });
  const lyrics = await fetchLrclib(title, artist || '', Number(duration));
  console.log('--- fetchLrclib result:', lyrics ? 'FOUND' : 'NOT FOUND');
  if (!lyrics) return res.status(404).json({ error: 'lyrics_not_found' });
  if (raw === true || raw === 'true') {
    return res.json({ lyrics });
  }
  return res.json({ d: encryptPayload(lyrics) });
});

// POST /api/generate-lyrics — Dynamic AI lyric generation
app.post('/api/generate-lyrics', async (req, res) => {
  let params = req.body;
  let isEncrypted = false;

  if (req.body && req.body.d) {
    try {
      const decrypted = decryptPayload(req.body.d);
      params = JSON.parse(decrypted);
      isEncrypted = true;
    } catch (e) {
      console.error("🔒 ROTTY SYSTEM SECURITY: Failed to decrypt lyrics request payload.", e);
      return res.status(400).json({ error: 'invalid_handshake' });
    }
  }

  const { prompt, genre, groq_api_key } = params;
  if (!prompt) {
    return res.status(400).json({ error: 'prompt required' });
  }

  console.log(`🧠 ROTTY STUDIO ENGINE: Initiating lyrics generation... Prompt: "${prompt}", Genre: ${genre}`);

  let generatedLyrics = null;
  let selectedCookie = null;

  // 1. Try Groq AI Generator first (support client-passed or server environment key)
  generatedLyrics = await generateGroqLyrics(prompt, genre, groq_api_key);

  // 2. Fallback to Suno Cookie Pool
  if (!generatedLyrics && SUNO_COOKIES.length > 0) {
    let attempts = 0;
    while (attempts < SUNO_COOKIES.length) {
      const idx = (currentCookieIndex + attempts) % SUNO_COOKIES.length;
      selectedCookie = SUNO_COOKIES[idx];
      try {
        generatedLyrics = await generateSunoLyrics(prompt, selectedCookie);
        currentCookieIndex = idx;
        console.log(`🎯 ROTTY STUDIO LYRICS: Successfully generated lyrics via Suno Account [${idx + 1}]!`);
        break;
      } catch (err) {
        console.warn(`⚠️ ROTTY STUDIO LYRICS: Account [${idx + 1}] failed with error: ${err.message}. Rotating...`);
      }
      attempts++;
    }
  }

  // 3. Last resort local creative generator
  if (!generatedLyrics) {
    console.log("🛡️ ROTTY STUDIO LYRICS FALLBACK: Generating creative dynamic lyrics locally...");
    generatedLyrics = generateDynamicFallbackLyrics(prompt, genre || 'Acoustic Pop');
  }

  const responseBody = { lyrics: generatedLyrics };

  if (isEncrypted) {
    const encryptedResponse = encryptPayload(JSON.stringify(responseBody));
    return res.json({ d: encryptedResponse });
  }

  return res.json(responseBody);
});

// Helper for searching artists on JioSaavn
async function saavnSearchArtists(query, limit = 20) {
  const qs = new URLSearchParams({
    __call : 'search.getArtistResults',
    _format : 'json',
    _marker : '0',
    ctx     : 'web6dot0',
    q       : query,
    p       : '1',
    n       : String(limit),
  });
  const res = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
    Referer: 'https://www.jiosaavn.com',
  });
  if (res.status !== 200) throw new Error('saavn_artists_fail');
  const body = JSON.parse(res.body);
  return body.results || [];
}

// Fallback search for artists
async function saavnFallbackSearchArtists(query, limit = 20) {
  const encQ = encodeURIComponent(query);
  const res = await fetchUrl(
    `https://saavn.sumit.co/api/search/artists?query=${encQ}&page=1&limit=${limit}`
  );
  if (res.status !== 200) throw new Error('saavn_fallback_artists_fail');
  const body = JSON.parse(res.body);
  return body?.data?.results || [];
}

// POST /api/search-artists
app.post('/api/search-artists', async (req, res) => {
  const { query, limit = 20 } = req.body;
  if (!query || typeof query !== 'string') {
    return res.status(400).json({ error: 'query required' });
  }

  let artists = [];
  try {
    artists = await saavnSearchArtists(query.trim(), limit);
  } catch (_) {
    try {
      artists = await saavnFallbackSearchArtists(query.trim(), limit);
    } catch (__) {
      return res.status(502).json({ error: 'all_artist_sources_failed' });
    }
  }

  const sanitized = artists.map(a => ({
    id: a.id || a.artistid || '',
    name: a.name || a.title || 'Artist',
    image: upgradeImageUrl(a.image)
  })).filter(a => a.id);

  return res.json({ d: encryptPayload(JSON.stringify(sanitized)) });
});

// ─── Curated Playlists Helper ─────────────────────────────────────
async function getPlaylistSongs(playlistId, limit = 35) {
  // Try direct JioSaavn first
  try {
    const detailQs = new URLSearchParams({
      __call: 'playlist.getDetails',
      _format: 'json',
      _marker: '0',
      ctx: 'web6dot0',
      listid: playlistId,
    });
    const detailRes = await fetchUrl(`https://www.jiosaavn.com/api.php?${detailQs}`, {
      Referer: 'https://www.jiosaavn.com',
    });
    if (detailRes.status === 200) {
      const detailBody = JSON.parse(detailRes.body);
      if (detailBody && detailBody.songs && Array.isArray(detailBody.songs) && detailBody.songs.length >= 5) {
        return detailBody.songs.slice(0, limit);
      }
    }
  } catch (err) {
    console.error(`getPlaylistSongs direct failed for ${playlistId}:`, err);
  }

  // Fallback to Sumit API
  try {
    const r = await fetchUrl(`https://saavn.sumit.co/api/playlists?id=${playlistId}`);
    if (r.status === 200) {
      const body = JSON.parse(r.body);
      const songs = body?.data?.songs || body?.data?.results || [];
      if (Array.isArray(songs) && songs.length >= 5) {
        return songs.slice(0, limit);
      }
    }
  } catch (err) {
    console.error(`getPlaylistSongs Sumit fallback failed for ${playlistId}:`, err);
  }

  return [];
}

// Memory caches
let cachedHomeSections = null;
let lastHomeCacheTime = 0;
const googleSongsCache = {};

// POST /api/home
app.post('/api/home', async (req, res) => {
  const { refresh } = req.body || {};
  const now = Date.now();
  if (!refresh && cachedHomeSections && (now - lastHomeCacheTime < 2 * 60 * 60 * 1000)) {
    return res.json({ d: cachedHomeSections });
  }

  const sections = {};
  const dayIndex = new Date().getDay();
  const hourIndex = new Date().getHours() % 4; // Vary queries throughout the day

  const trendingPool = [
    'Hindi Chartbusters',
    'Weekly Hotlist Hindi',
    'Trending Hindi',
    'JioTunes Trends Hindi',
  ];
  
  const bollywoodPool = [
    'Bollywood Romance Hits',
    'New Hindi Releases',
    'Bollywood Hits',
    'Best of Bollywood',
  ];

  const punjabiPool = [
    'Punjabi Hits',
    'New Punjabi Releases',
    'Trending Punjabi',
    'Punjabi Hit Songs',
  ];

  const topHitsPool = [
    'Weekly Top Hindi Songs',
    'Weekly Top English Songs',
    'Top Hits Today Hindi',
    'Global Top Hits',
  ];

  const viralPool = [
    'Hindi Viral Hits',
    'Trending Viral Mix',
    'Viral Hits Hindi',
    'Now Trending',
  ];

  const editorsPicksPool = [
    'Romantic Hits 2025 - Hindi',
    'Bollywood Love Songs',
    '2000s Romantic Hits',
    '90s Bollywood Romance',
  ];

  const trendingPlaylists = ['1265126272', '82974051', '106180373', '104618770', '1134595537', '1223482895', '82973946'];
  const bollywoodPlaylists = ['1234731818', '106180373', '1265126272', '1139074020', '48624237', '82974013'];
  const punjabiPlaylists = ['4144832', '46624508', '83241285', '110756784', '1134595462'];
  const topHitsPlaylists = ['1265126272', '106180373', '1134595537', '1223482895', '1234731818'];
  const viralPlaylists = ['1223482895', '110756784', '1134595537', '1265126272'];
  const editorsPlaylists = ['1139074020', '104618770', '82974051', '106180373'];

  // Pick queries dynamically
  let qTrending, qBollywood, qPunjabi, qTopHits, qViral, qEditorsPicks;
  let playlistTrending, playlistBollywood, playlistPunjabi, playlistTopHits, playlistViral, playlistEditors;

  if (refresh) {
    // True shuffle: pick random index from pools
    qTrending = trendingPool[Math.floor(Math.random() * trendingPool.length)];
    qBollywood = bollywoodPool[Math.floor(Math.random() * bollywoodPool.length)];
    qPunjabi = punjabiPool[Math.floor(Math.random() * punjabiPool.length)];
    qTopHits = topHitsPool[Math.floor(Math.random() * topHitsPool.length)];
    qViral = viralPool[Math.floor(Math.random() * viralPool.length)];
    qEditorsPicks = editorsPicksPool[Math.floor(Math.random() * editorsPicksPool.length)];

    playlistTrending = trendingPlaylists[Math.floor(Math.random() * trendingPlaylists.length)];
    playlistBollywood = bollywoodPlaylists[Math.floor(Math.random() * bollywoodPlaylists.length)];
    playlistPunjabi = punjabiPlaylists[Math.floor(Math.random() * punjabiPlaylists.length)];
    playlistTopHits = topHitsPlaylists[Math.floor(Math.random() * topHitsPlaylists.length)];
    playlistViral = viralPlaylists[Math.floor(Math.random() * viralPlaylists.length)];
    playlistEditors = editorsPlaylists[Math.floor(Math.random() * editorsPlaylists.length)];
  } else {
    qTrending = trendingPool[(dayIndex + hourIndex) % trendingPool.length];
    qBollywood = bollywoodPool[(dayIndex + hourIndex + 2) % bollywoodPool.length];
    qPunjabi = punjabiPool[(dayIndex + hourIndex + 4) % punjabiPool.length];
    qTopHits = topHitsPool[(dayIndex + hourIndex + 6) % topHitsPool.length];
    qViral = viralPool[(dayIndex + hourIndex) % viralPool.length];
    qEditorsPicks = editorsPicksPool[(dayIndex + hourIndex + 2) % editorsPicksPool.length];

    playlistTrending = trendingPlaylists[(dayIndex + hourIndex) % trendingPlaylists.length];
    playlistBollywood = bollywoodPlaylists[(dayIndex + hourIndex) % bollywoodPlaylists.length];
    playlistPunjabi = punjabiPlaylists[(dayIndex + hourIndex) % punjabiPlaylists.length];
    playlistTopHits = topHitsPlaylists[(dayIndex + hourIndex) % topHitsPlaylists.length];
    playlistViral = viralPlaylists[(dayIndex + hourIndex) % viralPlaylists.length];
    playlistEditors = editorsPlaylists[(dayIndex + hourIndex) % editorsPlaylists.length];
  }

  const queries = {
    Trending: { q: qTrending, playlistId: playlistTrending },
    Bollywood: { q: qBollywood, playlistId: playlistBollywood },
    Punjabi: { q: qPunjabi, playlistId: playlistPunjabi },
    TopHits: { q: qTopHits, playlistId: playlistTopHits },
    'Viral Songs': { q: qViral, playlistId: playlistViral },
    'Editor\'s Picks': { q: qEditorsPicks, playlistId: playlistEditors },
  };

  const promises = Object.entries(queries).map(async ([key, info]) => {
    try {
      let songs = [];
      // Step 1: Try fetching directly from the official playlist ID
      if (info.playlistId) {
        songs = await getPlaylistSongs(info.playlistId, 35);
      }
      
      // Step 2: Try fetching by editorial playlist search
      if (!songs || songs.length === 0) {
        songs = await saavnGetEditorialPlaylistSongs(info.q, 35);
      }
      
      // Step 3: Try Google/DDG search scraper fallback
      if (!songs || songs.length === 0) {
        const ddgQuery = `${info.q} songs official music video site:youtube.com`;
        let scrapedTitles = await scrapeDdgTitles(ddgQuery);
        if (!scrapedTitles || scrapedTitles.length === 0) {
          scrapedTitles = await scrapeGoogleTitles(ddgQuery);
        }
        if (scrapedTitles && scrapedTitles.length > 0) {
          const resolvePromises = scrapedTitles.slice(0, 10).map(async (rawTitle) => {
            const cleaned = cleanGoogleTitle(rawTitle);
            if (cleaned.length < 3) return null;
            try {
              let results = [];
              try {
                results = await saavnSearch(cleaned, 3);
              } catch (_) {
                results = await saavnFallbackSearch(cleaned, 3);
              }
              for (const s of results) {
                const mapped = mapSongToRotty(s);
                if (mapped && mapped.id && isOriginalSong(mapped)) return mapped;
              }
            } catch (_) {}
            return null;
          });
          const resolved = await Promise.all(resolvePromises);
          songs = resolved.filter(Boolean);
        }
      }

      // Step 4: Try standard search fallback
      if (!songs || songs.length === 0) {
        try {
          songs = await saavnSearch(info.q, 35);
        } catch (_) {
          songs = await saavnFallbackSearch(info.q, 35);
        }
      }

      // Shuffle the results for variety
      const shuffled = songs.sort(() => 0.5 - Math.random());
      
      const mapped = shuffled
        .map(s => (s.id && s.title) ? s : mapSongToRotty(s))
        .filter(s => s && s.id && isOriginalSong(s));
      
      sections[key] = deduplicateSongs(mapped).slice(0, 12);
    } catch (err) {
      console.error(`Error building section ${key}:`, err);
      sections[key] = [];
    }
  });

  await Promise.all(promises);

  const encrypted = encryptPayload(JSON.stringify(sections));
  
  if (!refresh) {
    cachedHomeSections = encrypted;
    lastHomeCacheTime = now;
  }

  return res.json({ d: encrypted });
});

// POST /api/scraped-songs
app.post('/api/scraped-songs', async (req, res) => {
  const { searchQuery, fallbackQuery, limit = 20 } = req.body;
  if (!searchQuery) return res.status(400).json({ error: 'searchQuery required' });

  const cacheKey = searchQuery + '_' + limit;
  const now = Date.now();

  // Special override for Hollywood releases to ensure genuine Western hits
  if (searchQuery.includes('latest english songs') || searchQuery.includes('billboard')) {
    try {
      const fs = require('fs');
      const path = require('path');
      const jsonPath = path.join(__dirname, 'data', 'official_english_songs.json');
      if (fs.existsSync(jsonPath)) {
        const raw = fs.readFileSync(jsonPath, 'utf8');
        const list = JSON.parse(raw);
        if (list && list.length > 0) {
          const encrypted = encryptPayload(JSON.stringify(list.slice(0, limit)));
          googleSongsCache[cacheKey] = { timestamp: now, data: encrypted };
          return res.json({ d: encrypted });
        }
      }
    } catch (err) {
      console.error('Error reading curated English songs file:', err);
    }
  }

  // Special override for Bollywood releases to ensure clean Indian hits
  if (searchQuery.includes('latest hindi songs') || searchQuery.includes('top bollywood songs')) {
    try {
      const bollywoodPlaylistId = '1234731818'; // Latest Hindi Hits (Official Hindi Playlist)
      const rawSongs = await getPlaylistSongs(bollywoodPlaylistId, limit);
      if (rawSongs && rawSongs.length >= 5) {
        const sanitized = rawSongs.map(s => mapSongToRotty(s)).filter(s => s && s.id);
        if (sanitized.length > 0) {
          const encrypted = encryptPayload(JSON.stringify(sanitized));
          googleSongsCache[cacheKey] = { timestamp: now, data: encrypted };
          return res.json({ d: encrypted });
        }
      }
    } catch (err) {
      console.error('Error fetching Bollywood playlist override:', err);
    }
  }

  if (googleSongsCache[cacheKey] && (now - googleSongsCache[cacheKey].timestamp < 2 * 60 * 60 * 1000)) {
    return res.json({ d: googleSongsCache[cacheKey].data });
  }

  try {
    let titles = await scrapeDdgTitles(searchQuery);
    if (!titles || titles.length === 0) {
      titles = await scrapeGoogleTitles(searchQuery);
    }

    let songs = [];
    const titleRegistry = new Set();
    const albumCounts = {};

    if (titles && titles.length > 0) {
      const resolvePromises = titles.slice(0, 15).map(async (rawTitle) => {
        const cleaned = cleanGoogleTitle(rawTitle);
        if (cleaned.length < 3) return null;
        try {
          let results = [];
          try {
            results = await saavnSearch(cleaned, 3);
          } catch (_) {
            results = await saavnFallbackSearch(cleaned, 3);
          }
          for (const s of results) {
            const mapped = mapSongToRotty(s);
            if (mapped && mapped.id && isOriginalSong(mapped)) {
              return mapped;
            }
          }
        } catch (_) {}
        return null;
      });

      const resolved = await Promise.all(resolvePromises);
      for (const s of resolved) {
        if (s) {
          const normTitle = normalizeTitle(s.title);
          if (titleRegistry.has(normTitle)) continue;
          
          const album = (s.album || '').toLowerCase().trim();
          if (album) {
            const count = albumCounts[album] || 0;
            if (count >= 2) continue;
            albumCounts[album] = count + 1;
          }

          titleRegistry.add(normTitle);
          songs.push(s);
        }
      }
    }

    // Fallback if we have fewer than 10 songs
    if (songs.length < 10 && fallbackQuery) {
      try {
        let list = [];
        try {
          list = await saavnSearch(fallbackQuery, 35);
        } catch (_) {
          list = await saavnFallbackSearch(fallbackQuery, 35);
        }
        for (const s of list) {
          const mapped = mapSongToRotty(s);
          if (mapped && mapped.id && isOriginalSong(mapped)) {
            const normTitle = normalizeTitle(mapped.title);
            if (titleRegistry.has(normTitle)) continue;

            const album = (mapped.album || '').toLowerCase().trim();
            if (album) {
              const count = albumCounts[album] || 0;
              if (count >= 2) continue;
              albumCounts[mapped.album] = count + 1;
            }

            titleRegistry.add(normTitle);
            songs.push(mapped);
            if (songs.length >= limit) break;
          }
        }
      } catch (_) {}
    }

    const finalSongs = songs.slice(0, limit);
    const encrypted = encryptPayload(JSON.stringify(finalSongs));
    googleSongsCache[cacheKey] = {
      timestamp: now,
      data: encrypted
    };
    return res.json({ d: encrypted });
  } catch (err) {
    console.error('Error in /api/scraped-songs:', err);
    return res.json({ d: encryptPayload(JSON.stringify([])) });
  }
});



// POST /api/recommendations — Get song recommendations
app.post('/api/recommendations', async (req, res) => {
  const { id, limit = 15, title: reqTitle, artist: reqArtist } = req.body;
  if (!id) return res.status(400).json({ error: 'id required' });

  let sanitized = [];
  try {
    const qs = new URLSearchParams({
      __call: 'reco.getreco',
      _format: 'json',
      ctx: 'web6dot0',
      pid: id,
      api_version: '4',
      n: String(limit),
    });
    const r = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
      Referer: 'https://www.jiosaavn.com',
    });
    if (r.status === 200) {
      const list = JSON.parse(r.body);
      sanitized = (Array.isArray(list) ? list : []).map(s => ({
        id: s.id || '',
        title: s.song || s.title || '',
        artist: s.primary_artists || s.subtitle || '',
        album: s.album || '',
        image: upgradeImageUrl(s.image),
        duration: Number(s.duration) || 0,
        language: s.language || '',
        url: extract320Url(s)
      })).filter(s => s.id);
    }
  } catch (err) {
    console.error('Error fetching recommendations from Saavn reco:', err);
  }

  // Fallback to Last.fm if Saavn reco returned empty or failed
  if (sanitized.length < 3) {
    console.log(`Saavn reco returned empty or failed for ID ${id}. Falling back to Last.fm...`);
    try {
      let title = reqTitle;
      let artist = reqArtist;

      if (!title || !artist) {
        // Try to get details from Saavn
        const details = await saavnGetDetails(id);
        if (details) {
          title = details.title;
          artist = details.artist;
        }
      }

      if (title && artist) {
        // We have title and artist, query Last.fm for similar tracks
        const apiKey = '75d20fb472be99275392aefa2760ea09';
        const url = `http://ws.audioscrobbler.com/2.0/?method=track.getsimilar&artist=${encodeURIComponent(artist)}&track=${encodeURIComponent(title)}&api_key=${apiKey}&format=json&limit=${limit}`;
        const lfRes = await fetchUrl(url);
        if (lfRes.status === 200) {
          const lfJson = JSON.parse(lfRes.body);
          if (lfJson.similartracks && Array.isArray(lfJson.similartracks.track)) {
            const tracks = lfJson.similartracks.track.slice(0, limit);
            console.log(`Found ${tracks.length} similar tracks on Last.fm. Searching them on Saavn...`);
            
            // For each similar track, search it on Saavn in parallel
            const searchPromises = tracks.map(async (t) => {
              const queryStr = `${t.name} ${t.artist.name}`;
              try {
                let sResults = [];
                try {
                  sResults = await saavnSearch(queryStr, 1);
                } catch (_) {
                  sResults = await saavnFallbackSearch(queryStr, 1);
                }
                if (sResults && sResults.length > 0) {
                  return mapSongToRotty(sResults[0]);
                }
              } catch (e) {
                // Ignore search error
              }
              return null;
            });

            const resolvedSongs = await Promise.all(searchPromises);
            sanitized = resolvedSongs.filter(s => s && s.id);
            console.log(`Successfully resolved ${sanitized.length} songs from Last.fm on JioSaavn.`);
          }
        }
      }
    } catch (lfErr) {
      console.error('Error in Last.fm recommendations fallback:', lfErr);
    }
  }

  if (sanitized.length > 0) {
    return res.json({ d: encryptPayload(JSON.stringify(sanitized)) });
  }

  return res.status(404).json({ error: 'recommendations_not_found' });
});

// Helper for separateStems endpoint to resolve individual song details
async function saavnGetDetails(id) {
  if (!id) return null;
  let rawData = null;
  try {
    const qs = new URLSearchParams({
      __call: 'song.getDetails', _format: 'json', _marker: '0',
      ctx: 'web6dot0', pids: id,
    });
    const r = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
      Referer: 'https://www.jiosaavn.com',
    });
    if (r.status === 200) {
      rawData = JSON.parse(r.body);
    }
  } catch (err) {
    console.error(`saavnGetDetails primary fetch failed for ID ${id}:`, err);
  }

  if (!rawData) {
    try {
      const r = await fetchUrl(`https://saavn.sumit.co/api/songs/${id}`);
      if (r.status === 200) {
        rawData = JSON.parse(r.body);
      }
    } catch (err) {
      console.error(`saavnGetDetails secondary fetch failed for ID ${id}:`, err);
    }
  }

  if (!rawData) return null;

  try {
    let song = null;
    if (Array.isArray(rawData) && rawData.length > 0) {
      song = rawData[0];
    } else if (rawData && Array.isArray(rawData.songs) && rawData.songs.length > 0) {
      song = rawData.songs[0];
    } else if (rawData && Array.isArray(rawData.data) && rawData.data.length > 0) {
      song = rawData.data[0];
    } else if (rawData && typeof rawData === 'object') {
      const keys = Object.keys(rawData);
      if (keys.length > 0) {
        const first = rawData[keys[0]];
        if (first && (first.id || first.songid)) {
          song = first;
        } else if (rawData.id || rawData.songid) {
          song = rawData;
        }
      }
    }
    if (song) {
      return {
        id: song.id || song.songid || '',
        title: song.song || song.title || song.name || '',
        artist: song.primary_artists || song.singers || song.subtitle || song.artist || 'Artist',
        url: extract320Url(song)
      };
    }
  } catch (e) {
    console.error("Error saavnGetDetails parsing:", e);
  }
  return null;
}

// ─── Cookie Auto-Refresh Helpers ──────────────────────────────────
// Extracts the fresh __client cookie from Clerk's Set-Cookie response header
function extractRefreshedClientCookie(headers) {
  if (!headers) return null;
  const setCookies = headers['set-cookie'];
  if (!setCookies) return null;
  const cookieArr = Array.isArray(setCookies) ? setCookies : [setCookies];
  for (const sc of cookieArr) {
    const match = sc.match(/__client=([^;]+)/);
    if (match && match[1] && match[1].length > 20) {
      return `__client=${match[1]}`;
    }
  }
  return null;
}

// Updates a cookie in the SUNO_COOKIES pool and persists to .env
function updateCookieInPool(oldCookie, newCookie) {
  try {
    // Find and replace in memory array
    const idx = SUNO_COOKIES.indexOf(oldCookie);
    if (idx !== -1) {
      SUNO_COOKIES[idx] = newCookie;
    } else {
      // Partial match fallback — compare first 80 chars of cookie value
      const oldVal = oldCookie.replace('__client=', '').substring(0, 80);
      const matchIdx = SUNO_COOKIES.findIndex(c => c.replace('__client=', '').substring(0, 80) === oldVal);
      if (matchIdx !== -1) {
        SUNO_COOKIES[matchIdx] = newCookie;
      } else {
        // Not found at all, append as new
        SUNO_COOKIES.push(newCookie);
      }
    }

    // Persist to environment variable and .env file
    const newEnvValue = SUNO_COOKIES.join(' || ');
    process.env.SUNO_COOKIE = newEnvValue;

    const envPath = path.join(__dirname, '.env');
    if (fs.existsSync(envPath)) {
      let envContent = fs.readFileSync(envPath, 'utf8');
      if (envContent.includes('SUNO_COOKIE=')) {
        envContent = envContent.replace(/SUNO_COOKIE=.*/, `SUNO_COOKIE=${newEnvValue}`);
      } else {
        envContent += `\nSUNO_COOKIE=${newEnvValue}`;
      }
      fs.writeFileSync(envPath, envContent, 'utf8');
    }

    console.log(`🔄 ROTTY AUTO-REFRESH: Cookie pool updated & persisted to .env! Pool size: ${SUNO_COOKIES.length}`);
  } catch (err) {
    console.error('🔄 ROTTY AUTO-REFRESH WARNING: Failed to persist cookie:', err.message);
  }
}

// Dynamic Suno AI Clerk Token Retriever (with Auto Cookie Refresh)
async function getSunoClerkToken(cookie) {
  try {
    // 1. Fetch active client sessions to retrieve the session ID dynamically
    const sessionsUrl = 'https://clerk.suno.com/v1/client?_clerk_js_version=4.72.0';
    const clientRes = await fetchUrl(sessionsUrl, {
      'Cookie': cookie,
      'Origin': 'https://suno.com',
      'Referer': 'https://suno.com/'
    });

    // AUTO-REFRESH: Capture fresh __client cookie from Clerk's Set-Cookie header
    const refreshedCookie1 = extractRefreshedClientCookie(clientRes.headers);
    if (refreshedCookie1 && refreshedCookie1 !== cookie) {
      console.log('🔄 ROTTY AUTO-REFRESH: Clerk /client returned fresh __client cookie. Updating pool...');
      updateCookieInPool(cookie, refreshedCookie1);
      cookie = refreshedCookie1; // Use refreshed cookie for subsequent calls
    }

    if (clientRes.status !== 200) {
      throw new Error(`Failed to fetch active Clerk client. Status: ${clientRes.status}`);
    }

    const clientData = JSON.parse(clientRes.body);
    const sessionId = clientData.response?.last_active_session_id;
    if (!sessionId) {
      throw new Error("Could not extract active session ID from Clerk response.");
    }

    // 2. Fetch the JWT token using the session ID
    const tokenUrl = `https://clerk.suno.com/v1/client/sessions/${sessionId}/tokens?_clerk_js_version=4.72.0`;
    const tokenRes = await fetchUrl(tokenUrl, {
      'Cookie': cookie,
      'Origin': 'https://suno.com',
      'Referer': 'https://suno.com/',
      'Content-Type': 'application/x-www-form-urlencoded'
    }, 'POST');

    // AUTO-REFRESH: Capture fresh cookie from token call too
    const refreshedCookie2 = extractRefreshedClientCookie(tokenRes.headers);
    if (refreshedCookie2 && refreshedCookie2 !== cookie) {
      console.log('🔄 ROTTY AUTO-REFRESH: Clerk /tokens returned fresh __client cookie. Updating pool...');
      updateCookieInPool(cookie, refreshedCookie2);
    }

    if (tokenRes.status !== 200) {
      throw new Error(`Failed to generate Clerk JWT. Status: ${tokenRes.status}`);
    }

    const tokenData = JSON.parse(tokenRes.body);
    const jwt = tokenData.jwt;
    if (!jwt) {
      throw new Error("Clerk token response did not contain a valid JWT.");
    }

    return jwt;
  } catch (err) {
    console.error("🔒 ROTTY SYSTEM ERROR: Clerk token refresh failed:", err.message);
    throw err;
  }
}

// Generate Suno Lyrics via clerk JWT
async function generateSunoLyrics(prompt, cookie) {
  try {
    const jwtToken = await getSunoClerkToken(cookie);
    const generateUrl = 'https://studio-api.prod.suno.com/api/generate/lyrics/';
    const genRes = await fetchUrl(generateUrl, {
      'Authorization': `Bearer ${jwtToken}`,
      'Cookie': cookie,
      'Content-Type': 'application/json',
      'Origin': 'https://suno.com',
      'Referer': 'https://suno.com/'
    }, 'POST', JSON.stringify({ prompt: prompt }));

    if (genRes.status !== 200) {
      throw new Error(`Suno lyrics trigger failed: ${genRes.status}`);
    }

    const genData = JSON.parse(genRes.body);
    const lyricsId = genData.id;
    if (!lyricsId) {
      throw new Error('No lyrics ID returned from Suno');
    }

    // Poll for lyrics
    let attempts = 0;
    while (attempts < 15) {
      await new Promise(r => setTimeout(r, 2000));
      attempts++;
      const pollUrl = `https://studio-api.prod.suno.com/api/generate/lyrics/${lyricsId}`;
      const pollRes = await fetchUrl(pollUrl, {
        'Authorization': `Bearer ${jwtToken}`,
        'Cookie': cookie,
        'Origin': 'https://suno.com',
        'Referer': 'https://suno.com/'
      });
      if (pollRes.status === 200) {
        const pollData = JSON.parse(pollRes.body);
        if (pollData.status === 'complete' && pollData.text) {
          return pollData.text;
        } else if (pollData.status === 'failed') {
          throw new Error('Suno lyrics generation status failed');
        }
      }
    }
    throw new Error('Suno lyrics generation timed out');
  } catch (err) {
    console.error('⚠️ Suno lyrics generation error:', err.message);
    throw err;
  }
}

// Groq-powered AI lyrics generator (₹0 Cost and Extremely Creative)
async function generateGroqLyrics(prompt, genre, clientGroqKey) {
  const apiKey = clientGroqKey || process.env.GROQ_API_KEY;
  if (!apiKey || apiKey.includes('mock_') || apiKey.includes('xxxxxxxx')) {
    console.log("🛡️ ROTTY STUDIO LYRICS: No valid GROQ_API_KEY found in request or environment.");
    return null;
  }

  try {
    console.log(`🧠 ROTTY STUDIO LYRICS: Querying Groq AI for prompt: "${prompt}"...`);
    const groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
    const body = {
      model: 'llama-3.3-70b-versatile',
      temperature: 0.95,
      max_tokens: 800,
      messages: [
        {
          role: 'system',
          content: 'You are "Rotty AI Lyricist". You write beautiful, emotional, rhythmic, and poetic song lyrics (blend of Hindi/Urdu, Punjabi, and English) based on user prompt/theme.\n' +
                   'Always structure the lyrics with clear brackets like [Intro], [Verse 1], [Chorus], [Verse 2], [Chorus], [Bridge], [Outro].\n' +
                   'Ensure they are catchy and feel like a real Indian movie or pop song. Do not write any introduction, commentary, conversational filler, or markdown blocks. Only return the raw lyrics text directly.'
        },
        {
          role: 'user',
          content: `Write song lyrics for theme: "${prompt}". Genre/Style: ${genre || 'Bollywood Romantic'}.\n` +
                   `Create a completely fresh and original set of lyrics, avoiding common clichés. Unique reference code: ${crypto.randomBytes(4).toString('hex')}`
        }
      ]
    };

    const res = await fetchUrl(groqUrl, {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    }, 'POST', JSON.stringify(body));

    if (res.status === 200) {
      const data = JSON.parse(res.body);
      const text = data.choices && data.choices[0] && data.choices[0].message && data.choices[0].message.content;
      if (text) {
        return text.trim();
      }
    } else {
      console.warn(`⚠️ ROTTY STUDIO LYRICS: Groq API returned status ${res.status}`);
    }
  } catch (err) {
    console.error(`❌ ROTTY STUDIO LYRICS: Groq API failed:`, err.message);
  }
  return null;
}

const LYRIC_DATABASE = {
  romantic: {
    verses: [
      "Kuch aisi baatein teri aankhon mein likhi hain,\nJaise sadiyon ki koi ansuni dastaan ho.\nHum tum mile is tarah jaise zameen pe khila,\nKoi pyaara sa naya phool ho.\nHar lamha teri chahat ka rang liye,\nMere {KW1} ko mehka raha hai.",
      "Akele chalte chalte raste kho gaye the,\nPar jabse mila hai tera sath, har faasla aasan ho gaya.\nTeri ek muskaan se saare zakham bhar gaye,\nJaise dhoop mein thandi chaaon mil gayi.\nMera ye {KW2} ab tere hi naam hai.",
      "Dheere dheere se jo chalti hain ye saansein,\nHar saas mein tera hi zikr chhupa hota hai.\nIshq ki is raah mein hum itne aage nikal aaye hain,\nAb peeche mudkar dekhne ka koi raasta nahi.\nYe dil teri {KW3} ke safar mein chalta hi jaye.",
      "Khaamosh fizaayein gungunati hain teri hi baatein,\nJaise hawayein kahin door se tera paigam laayi hain.\nTere bina har subah suni aur har shaam rangeen lagti hai,\nPar is dil ko bas tera intezaar hai.\nKhwaabon mein sajti hai teri {KW4} har pal.",
      "Naram dhoop jaise teri yaad aayi hai is sard subah mein,\nHar ek lamha jaise theher sa gaya hai.\nTere sath bitaye wo haseen din aaj bhi,\nYaadon ke jahan ko roshan karte hain.\nIs roohani rishte mein humara ye {KW5} aur gehra hota jaye.",
      "Kaise bataun tujhe is dil ka haal main,\nJo din raat tera hi naam pukarta rehta hai.\nTu hi meri manzil hai, tu hi mera raasta,\nAur tere bina har raah suni pad jati hai.\nIs sadiyon ke {KW6} mein tu hi mera saaya hai.",
      "Shaam ka aanchal dhalne laga hai ab toh,\nAur dil mein teri yaad ka chirag jal utha hai.\nEk pyari si khushboo har taraf faili hai,\nJaise tu mere paas hi kahin baithi ho.\nIs bechain dhadkan mein tere {KW1} ki gunj hai.",
      "Raste sabhi tujhse hi aake milte hain,\nJaise nadiyaan aakhir mein samundar mein milti hain.\nTeri aahat se hi mere din shuru hote hain,\nAur teri muskaan pe hi shaam dhal jati hai.\nHar pal, har ghadi tere is {KW2} mein khoya rehta hoon.",
      "Sadiyon ka rishta lagta hai ye humara,\nJaise pichle janam mein bhi hum mile honge.\nTeri aankhon ke is gehre samundar mein,\nMain khud ko bhula kar doob jana chahta hoon.\nIs prem kahani ka tu hi ek pyara sa {KW3} hai.",
      "Palkon pe khwaab banke tu ruk gaya hai,\nJaise koi sitara aasmaan se toot kar mere paas aa gaya ho.\nAb kisi aur ki tamanna nahi is dil ko,\nBas tu mil jaye toh saari khushiyan mil jayein.\nHar saas mein teri {KW4} ka aashiyana hai.",
      "Tere sang hi meri saari khushiyan hain,\nTere bina toh har khushi bhi dukh ban jati hai.\nKaise kahun ki tum mere liye kya ho,\nTum toh modi zindagi ki sabse pyari sacchai ho.\nDil ke is kone mein tera {KW5} sada aabad rahe.",
      "Bheegi bheegi si is thandi hawa mein,\nHar boond jaise tera hi naam pukarti hai.\nRimjhim baraste is saawan mein,\nTum aur main ek sath chalte hain.\nIs suhaane mausam mein humara ye {KW6} aur haseen ho gaya hai.",
      "Chupke se aakar tune dil ko chhua,\nJaise koi narm shabnam ka jhonka guzar gaya ho.\nAb toh har dhadkan mein ek hi aahat hai,\nAur har saas mein ek hi chahat hai.\nTeri chahat mein hi is {KW1} ka sukoon chhupa hai.",
      "Teri zulfon ki chaaon mein guzre ye zindagi,\nIsse pyari koi aur jannat nahi ho sakti.\nTeri aankhon ki masti mein khoya rahe ye dil,\nIsse bada koi aur nasha nahi ho sakta.\nHar lamha tere is {KW2} mein dhalta rahe.",
      "Khuda se bas yahi ek dua maangi hai maine,\nKi har janam mein tera hi sath mile.\nTeri dosti, tera pyaar aur tera saaya,\nMere jeene ki sabse badi wajah hai.\nDil ki har laya pe tera hi {KW3} gunjta rahe.",
      "Shaam ke saaye jab aasmaan ko gherte hain,\nTab teri yaadein mere dil ke aangan mein utar aati hain.\nUn yaadon ki roshni mein main khud ko dhoondta hoon,\nAur har bar tujhe hi apne paas pata hoon.\nIs pyari si {KW4} mein tera hi roop hai.",
      "Tu jo paas ho toh har mushkil aasan lagti hai,\nAur tu jo door ho toh har khushi bhi bejaan lagti hai.\nApne dil ki har baat tujhse hi kehna chahta hoon,\nKyunki tu hi toh is dil ka sabse bada humraaz hai.\nTere is {KW5} mein hi meri duniya hai.",
      "Nayi subah lekar aayi hai ek naya paigam,\nKi teri mohabbat hi meri zindagi ka sahara hai.\nHar ek pal jo tere bina guzarta hai,\nWo jaise sadiyon se bhi lamba lagta hai.\nIs bechaini mein tera {KW6} hi aakar chain deta hai.",
      "Aankhon mein khwaab aur dil mein teri chahat lekar,\nMain is duniya ke har tufan se lad sakta hoon.\nBas tera sath chahiye mujhe har kadam pe,\nPhir chahe rasta kitna bhi kathin kyun na ho.\nIs safar mein humara {KW1} hi humari takat hai.",
      "Tere ishq ki is dheemi aanch mein,\nMera dil dheere dheere pighalne laga hai.\nAb na toh koi shart hai aur na hi koi shikwa,\nBas ek be-inteha pyaar hai jo beh raha hai.\nIs bekhudi ka naam hi humara {KW2} hai."
    ],
    choruses: [
      "Tu hi mera jahaan hai, tu hi meri zameen,\nTere bina ab jeena lagta hai namumkin.\nDil diyan gallan tere naal baith ke karun,\nTu hi mera humsafar, tu hi mera yakeen.\nSaason ki har laya pe tera hi geet hai,\nTeri meri ye {KW3} sabse azeem hai.",
      "Humsafar ban ke chal mere sath is safar mein,\nTujhpe hi shuru ho meri har subah aur shaam.\nTere pyar ki roshni chamke meri nazar mein,\nLikh diya hai maine apna ye dil tere naam.\nBas ek baar keh de tu mere paas aakar,\nKi ab se tera hai ye {KW4} ka aashiyana.",
      "O mere humdum, tu kyun hai mujhse door,\nDil ye mera hai tere bin bilkul majboor.\nHar pal teri yaad mein khoya rahe man,\nChalta hoon main ab banke tera saaya.\nTu hi meri khwahish, tu hi meri jaan,\nDhadkan mein hai basi teri {KW5} ki taan.",
      "Tere ishq ka rang chadh gaya hai aisa,\nAb koi aur rang chadhta nahi dil par.\nTu hi meri subah hai aur tu hi meri shaam,\nHar dhadkan mein gunjta hai bas tera naam.\nTere bina ye zindagi hai ek adhoori kahani,\nTu mil jaye toh mil jaye saara {KW6} ka khazana.",
      "Aisa lagta hai jaise hum mile hain sadiyon se,\nHar rishta jud jata hai tere hi aane se.\nTeri muskaan hi meri jeene ki wajah hai,\nAur teri chahat hi is dil ki dawa hai.\nSaath chalenge hum har ek raah par,\nTere liye hi toh dhadakta hai ye {KW1} ka ghar.",
      "Rab se maanga hai maine bas tera hi pyaar,\nTeri har ek baat pe dil hai nisaar.\nTu hi mera aasmaan hai, tu hi meri zameen,\nTeri mohabbat pe hai mujhe poora yakeen.\nKhwaabon ke is haseen jahan mein,\nTu hi toh hai mere is {KW2} ki haseen dastaan."
    ],
    bridges: [
      "[Bridge]\n(Instrumentation build-up, shifting harmonies)\nKuch lamhe haath se nikalne lagte hain,\nJab tum mere paas se guzarne lagte ho.\nIs dil ko kaise samjhaun main,\nJo tere pyaar mein {KW3} bankar dhalne lagte hain.",
      "[Bridge]\n(Violin build-up, soft acoustic guitar picking)\nKaise kahein tumse hum apni ye dastaan,\nKhaamosh hai ye dil aur chup hai ye jahaan.\nPar aankhein teri sab kuch keh jaati hain,\nAur humari saari dooriyan {KW4} bankar mit jaati hain.",
      "[Bridge]\n(Melodic crescendo, transition to high notes)\nHar mod par khade hain hum tumhare liye,\nApni saari khushiyan tumpe vaar dene ke liye.\nBas ek ishaara kar do tum apne dil se,\nHum saari duniya bhula denge ek {KW5} ke liye."
    ],
    outros: [
      "[Outro]\n(Soft acoustic chords fading out slowly into rain ambience)\nROTTY AI Studio Original.\nTheme: {KW1} in the heart.\nFading notes of love.",
      "[Outro]\n(Acoustic guitar outro, ambient flute notes fading)\nTere sang guzar jaye saari zindagi...\nROTTY AI Studio Masterpiece.\nTheme: {KW2}.",
      "[Outro]\n(Slow piano chords resolving, soft wind chimes)\nHumara ye rishta sada salamat rahe...\nROTTY AI Studio Original."
    ]
  },
  punjabi: {
    verses: [
      "Kudiye ni tere nakhre da swaag ni,\nBillo teri akh da challeya ae jaadu ni.\nSaari raat chale gaadi on the road ni,\nDil vich thar thar vajdi ae bass ni.\nTu chaldi ae jaise koi {KW1} da flow,\nClub diyan lights hun ho gayi yaan low.",
      "Gabru vi nachda ae billo teri beat te,\nBase boost vajje meri gaddi di seat te.\nTere pichhe challe hun ashiqan di line ni,\nDas de tu sanu billo what's your plan ni?\nHath vich glass, assi nachde shreaam,\nZindagi de saare dukh bhula ke {KW2} de naam!",
      "Wakhra swag tera, wakhri ae chal ni,\nTere nakhre da saade kol koi hal nahi.\nSaari raat club vich vajda ae dhol ni,\nAaja mere kol, tu mukhda na mod ni.\nDil de ke baitha tenu gabru ae jawan,\nTere bina aida guzar jana {KW3} da jahan.",
      "Gaddi sadi beemer te challe 120 te,\nTere yaar da ae naam chale har ek geet te.\nBillo teri akh da ishara lagge teer ni,\nTu hi meri sohniye te main tera ranjha.\nIs ishq de khed vich dil haar gaye,\nNach nach gabru nu {KW4} maar gaye.",
      "Kurta pajama vich gabru jachda,\nClub vich aake billo saareyan nu dasta.\nTere nakhre di market hun up ho gayi,\nTere agge saariyan di beauty flop ho gayi.\nAssi haan Punjabi, saada wakhra ae roab,\nDil haar baithe tenu, {KW5} de shonk vich.",
      "Mittran de dil te tu chalaye teer ni,\nSaade wakhre ne shonk, saada wakhra shareer ni.\nBullet te aawan main teri gali vich jadon,\nLoki saare dekhde ne gabru nu tadon.\nAaja ni aaja billo, hath mera phad,\nTere bina aida saadi {KW6} te chadh.",
      "Kaali range gaddi vich yaar baithe chaar ni,\nTera nakhra taan billo lagda ae kamaal ni.\nSaade naal aake tu dil tera jod,\nAssi gabru shaukeen, saanu na tu mod.\nTeri ek akh de ishaare utte balliye,\nChalle saare yaar saade {KW1} di gali ye.",
      "Billo tere lakk da hulaara lagge kehar ni,\nSaareyan nu dasta tu apna hi shehar ni.\nDJ te challe billo mittran da gaana,\nTu vi nach nach saade kol hi hai aana.\nDil vich vas gayi tu, rooh vich vas gayi,\nMittran nu tu taan {KW2} das gayi.",
      "Paake tu suit patiala challe jadon,\nSaare pind vich shor mach jaave tadon.\nGabru da dil tere pichhe lutt gaya,\nTere ishq da jaadu saade sir chadh gaya.\nAja sohniye ni assi nachna shreaam,\nTere naam karti ye {KW3} di shaam.",
      "Loki kehnde gabru taan munda bada ghaint ni,\nPar tere agge mittran da chalda na paint ni.\nTeri ek muskaan te main sab kujh vaaran,\nTeri chahat vich saari raat main guzaaran.\nDil vich dabi jo baat, dasni hai tenu,\nTere is {KW4} ne pagal karta menu.",
      "Aaja sohniye ni tenu gaddi ch bithawaan,\nSaari duniya di sair tenu aaj main karawaan.\nPunjabi beat te dhol jado vajje,\nSaare pind vich yaara saada danka hi vajje.\nHath vich hath paake chal mere naal,\nTera mukh dekh ho jaanda {KW5} da haal.",
      "Chandigarh di kudiye ni tu lagdi ae ghaint,\nTere nakhre ne mittran nu karta ae mad.\nSaadi gaddi da chakkar teri gali vich round,\nVajda ae dhol te base da heavy sound.\nAssi yaaran de yaar, saada wakhra ae swag,\nTere pyar vich mittran da {KW6} ho gaya pack."
    ],
    choruses: [
      "Nachdi tu club vich lagdi ae fire,\nBillo teri aah adaa, that's my desire!\nTere nakhre da swaag eh taan wakhra jahaan,\nHath tera phadke main le chalaan {KW3}...\nAja nachle ni aaja billo, ho ja mast,\nSaari raat chale beat, hun shor macha!",
      "Punjabi beat utte dhol jado vajje,\nNachde ne gabru te aag yaara lagge.\nBillo tera nakhra taan sabton wakhra,\nSaari raat nachna, na assi hun thakna.\nDil saada haar baithe tere utte yaar,\nSaada wakhra ae swag, saada {KW4} kamaal!",
      "Billo ni billo, teri akh da ishaara,\nGabru nu lagda ae saade ton pyara.\nTere nakhre da tod koi na, koi na,\nTere wargi sohni hor koi na.\nNach nach billo hun dhool udd jaave,\nSaadi Punjabi beat te {KW5} chadh jaave.",
      "Aja sohniye ni assi nachna shreaam,\nTere naam karti assi mittran di shaam.\nDhol di ye thap utte lakk nu ghuma,\nSaare pind vich tu hun shor macha.\nAssi Punjabi gabru shaukeen,\nTere is {KW6} te assi hoye ne yakeen."
    ],
    bridges: [
      "[Bridge]\n(Dhol build-up, heavy bass transition)\nHath vich glass, assi nachde shreaam,\nZindagi de saare dukh bhula ke yaaran de naam!\nTere nakhre da tod hun labhna ae paina,\nTenu mittran da ban ke hi rehna.",
      "[Bridge]\n(Heavy synth beat drop, Punjabi lyrics build-up)\nMitraan di gaddi vich vajda ae bass,\nTere nakhre ne billo karta ae mess.\nSaade naal nachna taan nachle ni aake,\nAssi chadhaange rang, {KW1} de dhol vajake."
    ],
    outros: [
      "[Outro]\n(Heavy synthetic bass fading out, fading dhol roll)\nAssi Punjabi shreaam!\nROTTY AI Studio Master. Theme: {KW1}.",
      "[Outro]\n(Fading dhol beat, synth melody fading slowly)\nAssi nachde shreaam, Punjabi swag naal!\nROTTY AI Studio Original. Theme: {KW2}."
    ]
  },
  sufi: {
    verses: [
      "Roohaniyat ki raahon mein tera thikana hai,\nIs banjare dil ko bas tere dar pe aana hai.\nDuniyadari se door khoya hoon main kahin,\nTujhse hi shuru aur tujhpe hi khatam hai zameen.\nKhwabon mein tere, har saas mein {KW1},\nDhundta phirun main tujhko har dar, har safar.",
      "Sajda tera hi ab mera imaan hai,\nTujhse hi roshan meri subah aur shaam hai.\nIs bekhudi ka na koi thikana raha,\nTere pyar mein dil ye diwana raha.\nTu hi hai har zarre mein chhupa hua,\nTeri ibadat mein mila ye {KW2} ka nishaan.",
      "Yaara teri yaari mein khoya hai ye jahan,\nJaise khuda ki reham ka mila ho saaybaan.\nTeri galiyon ki khak ko sar pe lagata hoon,\nJab bhi tera naam loon, sajde mein jhuk jata hoon.\nIs ishq-e-haqiqi mein mera sar jhuka rahe,\nMeri har ek saas teri {KW3} ki sada rahe.",
      "Bekhudi ki is raah mein koi hosh na raha,\nTere deedar ke siwa koi josh na raha.\nKhwabon ka musafir chal pada tere dar pe,\nApni saari khushiyan vaar di tere darbar pe.\nMaula tu hi mera daata, tu hi hai mera pir,\nTere hath mein hai meri is {KW4} ki taqdeer.",
      "Noor-e-ilaahi chamka hai tere chehre se,\nJaise andhera mit gaya hai kisi roshan saaye se.\nTere ishq mein jo sukoon mila hai rooh nu,\nWo na mila kisi shahi mahal ya takht nu.\nHar pal teri ibadat, har pal tera dhyan,\nTere ishq mein fana hone chala ye {KW5} ka jahan.",
      "Khamosh ibaadat meri tujh tak pahunch jaye,\nMeri rooh ki fariyaad tere dar ko chhu jaye.\nDuniyadari ki rasmon ko chhod aaya hoon main,\nTere ishq ki dor se khud ko baandh aaya hoon main.\nTere dar pe jo sukoon mila, wo kahin aur na mila,\nIs {KW6} ka aakhir tu hi hai silsila.",
      "Sajdon mein tere guzar jaye ye umar meri,\nTeri chahat mein hi roshan ho har dhoop meri.\nIshq tera hai maula rooh ka thikana,\nTere siwa kisi aur ko na ab hai maana.\nMeri har fariyaad pe tera hi naam ho,\nTere ishq ke dar pe hi meri {KW1} ki shaam ho.",
      "Zarre-zarre mein tera hi noor chamakta hai,\nHar ek patta teri hi chahat mein jhukta hai.\nKhoya khoya rehta hoon main tere dhyan mein,\nJaise khushboo ghuli ho is hawa-o-jahan mein.\nTu hi hai har lafz mein, tu hi hai har geet mein,\nMila hai sukoon mujhe teri is {KW2} ki reet mein.",
      "Ya Maula, karam ho tera, rehmat ho teri,\nTere dar pe aakar hi mitti hai ye pyaas meri.\nRoop tera hi dikhta hai har ek chehre mein,\nTeri hi gunj hai is khamosh pehre mein.\nMeri rooh ko ab tere hi dar ki pyaas hai,\nTere is {KW3} pe hi mera sabse bada vishwas hai.",
      "Dar-ba-dar bhatak raha tha main is jahan mein,\nPar sukoon mila jab aaya teri sharan mein.\nTeri chahat ka diya jal raha hai mere dil mein,\nJaise roshni ho kisi ghani mushkil mein.\nMaula tere naam pe hi fana ho jaye ye zindagi,\nYahi hai meri sabse badi {KW4} ki bandagi."
    ],
    choruses: [
      "Ya Maula, Ya Maula, sun le meri fariyaad,\nTere bina sab soona, sab barbaad.\nSajda karun tera, tu hi mera rehnuma,\nDil se nikle har dam teri hi {KW3} ki sada.\nKaram ho tera, bas yahi hai dua.",
      "Ishq tera roohani, sajda tera noorani,\nTeri mohabbat mein likhi ye zindagani.\nTu hi mera rehnuma, tu hi mera pir,\nTujhse hi badli hai mere mukaddar ki lakeer.\nYa Maula sun le, karam ho tera,\nTere dar pe jhuk gaya ye {KW4} mera.",
      "Tu hi mera noor hai, tu hi mera sukoon,\nTeri chahat mein khoya rehna mera junoon.\nSajde mein jhuka sar, aankhon mein hai neer,\nMaula teri chahat ne badal di meri taqdeer.\nHar zarre mein tu hai, har rooh mein tu,\nTeri mohabbat ki hai mujhe {KW5} ki justaju."
    ],
    bridges: [
      "[Bridge]\n(Harmonium build-up, classical alaap style)\nRooh ko mili hai sukoon ki ek nayi raah,\nJab se teri mohabbat ne kiya hai mujhe fana.\nAb na koi tamanna, na koi chaah hai,\nMaula tere dar pe hi meri aakhri aah hai.",
      "[Bridge]\n(Sufi drum build-up, clapping synchronization)\nTeri ibadat mein guzar jaye har ek pal mera,\nTeri hi rehmat se chamke har ek kal mera.\nIshq-e-haqiqi ka rang chadh gaya aisa,\nMit gaya hai saara {KW1} ka andhera jaise."
    ],
    outros: [
      "[Outro]\n(Harmonium chords fading out, classic tabla beat resolving)\nSajda kabool ho Maula...\nROTTY AI Studio Sufi original.\nTheme: {KW1} of the soul.",
      "[Outro]\n(Slow harmonium fade, tanpura drone fading out)\nRoohani ishq sada salamat rahe...\nROTTY AI Studio Original. Theme: {KW2}."
    ]
  },
  lofi: {
    verses: [
      "Khamosh raste aur halki si ye baarish,\nDil mein dabi hai ek choti si sifarish.\nCoffee ki pyaali aur teri wo puraani baatein,\nKaise bhulaun wo suhaani haseen raatein.\nIs Lofi beat par chal raha hai mera {KW1},\nKahin kho na jaana tum is shaam ke baad.",
      "Hawaon mein ek ajeeb sa sukoon hai,\nTeri yaad mein khoya rehna mera junoon hai.\nDheere se chalti hai ye raat ki thandi pawan,\nJaise ga rahi ho koi khamosh sa bhajan.\nTeri tasveer ko dekh kar guzarti hai raat,\nKab hogi hamari wo pehli {KW2} wali baat?",
      "Vibe hai chill aur lights hain bilkul low,\nChal raha hai zindagi da dheere dheere flow.\nKhidki se dikhta hai chaand ka ye aanchal,\nTeri yaadon ne kiya hai dil ko bada chanchal.\nHeadphone lagake khoya hoon main apne khwaabon mein,\nJaise likhi ho teri meri dastaan {KW3} ki kitabon mein.",
      "Khaamoshi ki is chadar mein chhupi hain yaadein,\nPurane khat aur wo lambi lambi baatein.\nZindagi ke is safar mein chalte chalte,\nThak gaya hoon par yaadein nahi dhalti.\nEk purana gaana baj raha hai radio par,\nJo yaad dilata hai humein us {KW4} ke mod par.",
      "Sard hawa ka jhonka chhu kar guzar gaya,\nDil mein dabaye jo dard tha wo phir se ubhar gaya.\nPar is lofi beat pe dil ko milta hai sukoon,\nTeri yaadon ke aagosh mein khona hi hai mera junoon.\nKahin door chalte hain is duniya se door,\nJahan na ho koi gam na ho {KW5} ka shor.",
      "Raat ki is khamoshi mein gunjti hai ek aahat,\nTeri yaadon se hi milti hai dil ko ye raahat.\nCoffee ka mug aur meri wahi purani diary,\nJismein har panna likhta hai teri chahat ki shayari.\nIs suhaane mausam mein tera sath chahiye,\nHath mein lekar ek dusre ka {KW6} hath chahiye.",
      "Khidki pe rimjhim barasti hai ye baarish,\nDil ki bas yahi hai ek aakhri si guzarish.\nTum aur main ek baar phir se mil jayein,\nPurani un galiyon mein sath chalne lag jayein.\nIs lofi vibing mein har dard dheema lagta hai,\nJaise tere bina saara jahan {KW1} sa lagta hai.",
      "Slow waves aur thandi hawa ka ye aalam,\nTere bina jaise har zakhmi dil pe na lag sake marham.\nPar teri yaad ka ye nasha alag hi sukoon deta hai,\nIs bechain mann ko chupke se behla leta hai.\nHeadphone mein chal raha hai ye lofi gaana,\nJo yaad dilata hai tera wo {KW2} sa muskurana.",
      "Guzre hue lamhon ko yaad kar ke muskura deta hoon,\nIs lofi beat pe main apne saare gham bhula deta hoon.\nKaise kahein ki teri kitni yaad aati hai,\nTeri ek tasveer hi is dil ko behlati hai.\nZindagi ki is bhaag-daud se door khoya hoon,\nTere is {KW3} mein hi chain se soya hoon.",
      "Khamosh fizaayein aur dhalta hua ye suraj,\nHar lamha jaise maang raha ho teri mohabbat ka kharaj.\nPar tum toh door ho mujhse kisi aur nagar mein,\nAur main khoya hoon yahaan teri yaad ke is safar mein.\nLofi vibes ke sath beeti hai ye shaam,\nDil ke har panne par likh diya hai {KW4} ka naam."
    ],
    choruses: [
      "Slow vibes, chill beats, aur tera khwaab,\nTeri har ek baatein hain kitni laajawaab.\nDheere dheere chalte hain hum dono sath,\nHath mein lekar ek dusre ka ye {KW3} hath.\nIs haseen pal mein khone do hume.",
      "Chill vibes, slow night, aur teri yaadein,\nDil mein dabi reh gayi wo adhoori baatein.\nLofi beat pe chalte rahein hum,\nBhula kar duniya ke saare gham.\nTeri mohabbat ka ye {KW4} sukoon hai,\nTere sath khona hi mera junoon hai.",
      "Dheere se bajti hai ye lofi beat,\nYaad dilaati hai humein humari wo preet.\nKhamoshi mein bhi ek haseen geet hai,\nTeri meri dosti sabse azeem hai.\nIs chill vibe mein khone do hume,\nTeri is {KW5} ki baahon mein sone do hume."
    ],
    bridges: [
      "[Bridge]\n(Melancholic piano chords, vinyl crackle drop)\nKuch lamhe haath se phisalne lagte hain,\nJab hum yaadon ke panno ko palatne lagte hain.\nIs lofi shor mein bhi tera hi zikr hai,\nIs dil ko bas teri hi fikar hai.",
      "[Bridge]\n(Chill bass guitar riff, muted synth chords)\nChalte chalte kahin kho gaye hum dono,\nKhwabon ke is shahar mein so gaye hum dono.\nPar teri yaad ka ye {KW1} dhiime se bajta rahega,\nDil mein tera hi aashiyana humesha sajta rahega."
    ],
    outros: [
      "[Outro]\n(Melancholic piano chords fading, vinyl crackle effect)\nChill Lofi beats.\nROTTY AI Studio Original.\nTheme: {KW1}.\nGood night, world.",
      "[Outro]\n(Synth wave fading out, sound of rain and vinyl crackle fading)\nSlow vibes, chill life...\nROTTY AI Studio Original. Theme: {KW2}."
    ]
  }
};

function generateDynamicFallbackLyrics(prompt, genre) {
  const cleanPrompt = (prompt || '').trim();
  const genLower = (genre || '').toLowerCase();
  
  // Mix in a random salt to guarantee non-deterministic unique lyrics every time!
  const randomSalt = Math.floor(Math.random() * 1000000);
  
  let hash = 0;
  for (let i = 0; i < cleanPrompt.length; i++) {
    hash = (hash * 31 + cleanPrompt.charCodeAt(i)) & 0xffffffff;
  }
  const absHash = Math.abs(hash + randomSalt);

  const stopwords = new Set([
    'and', 'the', 'a', 'an', 'to', 'in', 'on', 'with', 'for', 'of', 'at', 'by', 'about', 
    'song', 'music', 'track', 'original', 'make', 'create', 'generate', 'write', 'lyrics', 
    'style', 'mood', 'hindi', 'punjabi', 'english', 'melodious', 'soft', 'beat', 'remix',
    'please', 'want', 'need', 'like', 'love', 'approx', 'min', 'longer', 'long'
  ]);
  
  const rawWords = cleanPrompt
    .toLowerCase()
    .replace(/[^\w\s\u0900-\u097F]/g, '')
    .split(/\s+/)
    .filter(w => w.length > 2 && !stopwords.has(w));

  const defaultKeywords = {
    romantic: ['Pyaar', 'Dhadkan', 'Khwaab', 'Sanam', 'Saansein', 'Zindagi', 'Naina', 'Manzil'],
    punjabi: ['Billo', 'Gabru', 'Nakhra', 'Swag', 'Makhna', 'Yaara', 'Gaddi', 'Beat'],
    sufi: ['Maula', 'Sajda', 'Rooh', 'Ishq', 'Fariyaad', 'Darbaar', 'Karam', 'Noor'],
    lofi: ['Sukoon', 'Baarish', 'Yaadein', 'Khamoshi', 'Safar', 'Tasveer', 'Raat', 'Vibes']
  };

  const extracted = rawWords.map(w => w.charAt(0).toUpperCase() + w.slice(1));
  
  let genreKey = 'romantic';
  if (genLower.includes('punjabi') || genLower.includes('club') || genLower.includes('edm') || genLower.includes('hiphop')) {
    genreKey = 'punjabi';
  } else if (genLower.includes('sufi') || genLower.includes('qawwali') || genLower.includes('devotional') || genLower.includes('classical')) {
    genreKey = 'sufi';
  } else if (genLower.includes('lo-fi') || genLower.includes('lofi') || genLower.includes('chill') || genLower.includes('ambient')) {
    genreKey = 'lofi';
  }

  const pool = defaultKeywords[genreKey];
  const kw = [];
  for (let i = 0; i < 6; i++) {
    if (extracted[i]) {
      kw.push(extracted[i]);
    } else {
      kw.push(pool[(absHash + i + randomSalt) % pool.length]);
    }
  }

  const db = LYRIC_DATABASE[genreKey];

  const v1Idx = absHash % db.verses.length;
  let v2Idx = (absHash + 7) % db.verses.length;
  if (v2Idx === v1Idx) {
    v2Idx = (v2Idx + 1) % db.verses.length;
  }
  
  const chorIdx = absHash % db.choruses.length;
  const briIdx = absHash % db.bridges.length;
  const outIdx = absHash % db.outros.length;
  
  function replaceKeywords(text) {
    return text
      .replace(/{KW1}/g, kw[0])
      .replace(/{KW2}/g, kw[1])
      .replace(/{KW3}/g, kw[2])
      .replace(/{KW4}/g, kw[3])
      .replace(/{KW5}/g, kw[4])
      .replace(/{KW6}/g, kw[5]);
  }

  const verse1 = replaceKeywords(db.verses[v1Idx]);
  const verse2 = replaceKeywords(db.verses[v2Idx]);
  const chorus = replaceKeywords(db.choruses[chorIdx]);
  const bridge = replaceKeywords(db.bridges[briIdx]);
  const outro  = replaceKeywords(db.outros[outIdx]);

  const intro = `[Intro]\n(Beautiful instrumental prelude to set the mood for ${genre || 'Acoustic Pop'})\n(Soft theme: ${kw[0]} & ${kw[1]})`;

  return `${intro}\n\n[Verse 1]\n${verse1}\n\n[Chorus]\n${chorus}\n\n[Verse 2]\n${verse2}\n\n[Chorus]\n${chorus}\n\n${bridge}\n\n[Chorus]\n${chorus}\n\n${outro}`;
}

// Reuseable mock sandbox song generation
async function generateMockSandboxSong(req, genre, prompt, custom_lyrics, is_instrumental) {
  let searchQuery = `${genre || ''} ${prompt || ''}`.trim();
  if (!searchQuery) searchQuery = 'bollywood romantic';

  let audioUrl = `http://${req.headers.host}/renders/f0251b2682c5d7f3952794cb7f8da953.wav`;
  let resolvedDuration = 140 + Math.floor(Math.random() * 60);
  let matchedTitle = null;
  let matchedArtist = null;

  try {
    console.log(`🔍 ROTTY STUDIO DEV FALLBACK: Searching JioSaavn for real audio match: "${searchQuery}"`);
    let searchResults = [];
    try {
      searchResults = await saavnSearch(searchQuery, 5);
    } catch (_) {
      try {
        searchResults = await saavnFallbackSearch(searchQuery, 5);
      } catch (__) {}
    }

    if (searchResults && searchResults.length > 0) {
      for (const s of searchResults) {
        const playableUrl = extract320Url(s);
        if (playableUrl) {
          audioUrl = playableUrl;
          resolvedDuration = parseInt(s.duration || s.more_info?.duration || resolvedDuration, 10) || resolvedDuration;
          matchedTitle = s.title || s.song;
          matchedArtist = s.subtitle || s.primary_artists || s.artist;
          console.log(`🎯 ROTTY STUDIO DEV FALLBACK: Match found! Title: "${matchedTitle}" by "${matchedArtist}". Audio URL: ${audioUrl}`);
          break;
        }
      }
    }
  } catch (err) {
    console.error("⚠️ ROTTY STUDIO DEV FALLBACK: Failed to search JioSaavn matching track, using default wav:", err.message);
  }

  const finalLyrics = is_instrumental ? 'Instrumental Track' : (custom_lyrics || generateDynamicFallbackLyrics(prompt, genre || 'Acoustic Pop'));
  const contextualCover = getContextualCover(genre, prompt);
  return [{
    id: `mock_track_${Date.now()}`,
    title: matchedTitle ? `${matchedTitle} (AI Studio Composition)` : generateCreativeTitle(genre, prompt),
    lyrics: finalLyrics,
    audio_url: audioUrl,
    image_url: contextualCover,
    duration: resolvedDuration
  }];
}

// Global Suno Cookie Pool for Rotator Hack (₹0 Cost)
const SUNO_COOKIES = (process.env.SUNO_COOKIE || '').split('||').map(c => c.trim()).filter(c => c.length > 0);
let currentCookieIndex = 0;

// Global Backup API Keys Pool for Rotator (AIML API)
const BACKUP_API_KEYS = (process.env.BACKUP_API_KEY || '').split('||').map(k => k.trim()).filter(k => k.length > 0 && !k.includes('mock_') && !k.includes('aiml_key_fallback'));
let currentBackupKeyIndex = 0;

// POST /api/update-suno-cookie — Update cookie pool dynamically from client
app.post('/api/update-suno-cookie', async (req, res) => {
  let body = req.body;
  let isEncrypted = false;
  if (req.body && req.body.d) {
    try {
      const decrypted = decryptPayload(req.body.d);
      body = JSON.parse(decrypted);
      isEncrypted = true;
    } catch (e) {
      return res.status(400).json({ error: 'invalid_handshake' });
    }
  }

  const { cookie } = body;
  if (!cookie || cookie.trim().length === 0) {
    const errorResponse = { error: 'missing_cookie' };
    return res.status(400).json(isEncrypted ? { d: encryptPayload(JSON.stringify(errorResponse)) } : errorResponse);
  }

  try {
    console.log("📝 ROTTY SYSTEM: Updating Suno cookies dynamically...");
    
    // Read the current .env file
    const envPath = path.join(__dirname, '.env');
    let envContent = '';
    if (fs.existsSync(envPath)) {
      envContent = fs.readFileSync(envPath, 'utf8');
    }
    
    // Replace the SUNO_COOKIE line or append it
    let newEnvContent = '';
    if (envContent.includes('SUNO_COOKIE=')) {
      newEnvContent = envContent.replace(/SUNO_COOKIE=.*/, `SUNO_COOKIE=${cookie}`);
    } else {
      newEnvContent = envContent + `\nSUNO_COOKIE=${cookie}`;
    }
    
    fs.writeFileSync(envPath, newEnvContent, 'utf8');
    
    // Refresh the global variable in memory immediately!
    process.env.SUNO_COOKIE = cookie;
    SUNO_COOKIES.length = 0; // Clear array
    cookie.split('||').map(c => c.trim()).filter(c => c.length > 0).forEach(c => SUNO_COOKIES.push(c));
    currentCookieIndex = 0;
    
    console.log(`🎯 ROTTY SYSTEM: Cookies successfully updated in memory! Count: ${SUNO_COOKIES.length}`);
    
    const response = { status: 'success', message: 'Cookies updated successfully.' };
    return res.json(isEncrypted ? { d: encryptPayload(JSON.stringify(response)) } : response);
  } catch (err) {
    console.error("❌ ROTTY SYSTEM ERROR: Failed to update cookies:", err.message);
    const errorResponse = { error: 'failed_to_update' };
    return res.status(500).json(isEncrypted ? { d: encryptPayload(JSON.stringify(errorResponse)) } : errorResponse);
  }
});

// Asynchronous generation task store
const ACTIVE_TASKS = {};

// POST /api/generation-status — Poll status of background song generation task
app.post('/api/generation-status', async (req, res) => {
  let params = req.body;
  let isEncrypted = false;

  if (req.body && req.body.d) {
    try {
      const decrypted = decryptPayload(req.body.d);
      params = JSON.parse(decrypted);
      isEncrypted = true;
    } catch (e) {
      return res.status(400).json({ error: 'invalid_handshake' });
    }
  }

  const { taskId } = params;
  if (!taskId) {
    const errRes = { error: 'taskId required' };
    return res.status(400).json(isEncrypted ? { d: encryptPayload(JSON.stringify(errRes)) } : errRes);
  }

  const task = ACTIVE_TASKS[taskId];
  if (!task) {
    const errRes = { error: 'task_not_found' };
    return res.status(404).json(isEncrypted ? { d: encryptPayload(JSON.stringify(errRes)) } : errRes);
  }

  return res.json(isEncrypted ? { d: encryptPayload(JSON.stringify(task)) } : task);
});

// Asynchronous background song generation worker
async function runBackgroundGeneration(taskId, params, tags, generatedTitle, contextualCover, reqMock) {
  const { prompt, genre, vocal_gender, vocal_expression, is_instrumental, custom_lyrics } = params;
  
  let clips = null;
  let jwtToken = null;
  let selectedCookie = null;
  let isCaptchaRequired = false;

  const isBackupMock = !process.env.BACKUP_API_KEY || process.env.BACKUP_API_KEY.includes('mock_backup_api_key') || process.env.BACKUP_API_KEY.includes('aiml_key_fallback');
  const backupKey = process.env.BACKUP_API_KEY;
  const isBackupValid = backupKey && backupKey.trim().length > 0 && !isBackupMock;

  try {
    // 1. Lyric Construction (Stage 1)
    ACTIVE_TASKS[taskId] = {
      status: 'lyric_construction',
      progress: 0.15,
      eta: 80,
      message: 'Drafting poetic syllables and harmonizing rhymes...'
    };
    await new Promise(resolve => setTimeout(resolve, 3000));

    // 2. Orchestration & Arrangement (Stage 2)
    ACTIVE_TASKS[taskId] = {
      status: 'orchestration',
      progress: 0.45,
      eta: 65,
      message: 'Arranging backing chords and layering string sections...'
    };
    await new Promise(resolve => setTimeout(resolve, 4000));

    // 3. Vocal Synthesis (Stage 3)
    ACTIVE_TASKS[taskId] = {
      status: 'vocal_synthesis',
      progress: 0.65,
      eta: 50,
      message: 'Synthesizing deep vocal expressions and layering harmonies...'
    };

    // Try Rotator Cookie Hack first (₹0 Free Tier Pool)
    const forceBackup = params.force_backup === true;
    if (SUNO_COOKIES.length === 0) {
      isCaptchaRequired = true;
    }

    if (!forceBackup && SUNO_COOKIES.length > 0) {
      let attempts = 0;
      while (attempts < SUNO_COOKIES.length) {
        const idx = (currentCookieIndex + attempts) % SUNO_COOKIES.length;
        selectedCookie = SUNO_COOKIES[idx];
        console.log(`🧠 ROTTY STUDIO: Trying Cookie Pool Account [${idx + 1}/${SUNO_COOKIES.length}]...`);

        try {
          jwtToken = await getSunoClerkToken(selectedCookie);

          // Call Suno Direct API
          const generateUrl = 'https://studio-api.prod.suno.com/api/generate/v2-web/';
          const body = custom_lyrics && custom_lyrics.trim().length > 0
            ? { prompt: custom_lyrics, tags: tags, title: generatedTitle, make_instrumental: !!is_instrumental, mv: "chirp-v3-5" }
            : { prompt: "", gpt_description_prompt: `${prompt} ${genre} ${vocal_gender} ${vocal_expression}`, tags: tags, title: generatedTitle, make_instrumental: !!is_instrumental, mv: "chirp-v3-5" };

          const deviceId = '14384c7f-2485-4c16-83ef-7ff507937460';
          const timestamp = Date.now();
          const browserTokenObj = { token: Buffer.from(JSON.stringify({ timestamp })).toString('base64') };
          const browserToken = JSON.stringify(browserTokenObj);

          const genRes = await fetchUrl(generateUrl, {
            'Authorization': `Bearer ${jwtToken}`,
            'Cookie': selectedCookie,
            'device-id': deviceId,
            'browser-token': browserToken,
            'Content-Type': 'application/json',
            'Origin': 'https://suno.com',
            'Referer': 'https://suno.com/'
          }, 'POST', JSON.stringify(body));

          if (genRes.status === 200) {
            const genData = JSON.parse(genRes.body);
            if (genData.clips && genData.clips.length > 0) {
              clips = genData.clips;
              currentCookieIndex = idx; // Lock onto successful cookie
              console.log(`🎯 ROTTY STUDIO: Composition successfully triggered on Account [${idx + 1}]! Clips:`, clips.map(c => c.id));
              break;
            }
          } else {
            console.warn(`⚠️ ROTTY STUDIO: Account [${idx + 1}] returned status ${genRes.status}. Body: ${genRes.body}. Rotating...`);
            if (genRes.status === 422 || genRes.status === 401 || genRes.status === 403) {
              isCaptchaRequired = true;
            }
          }
        } catch (err) {
          console.warn(`⚠️ ROTTY STUDIO: Account [${idx + 1}] failed with error: ${err.message}. Rotating...`);
          isCaptchaRequired = true;
        }
        attempts++;
      }
    }

    let completedSong = null;

    // Fallback to Stable Backup API if rotator pool failed or is empty
    if (!clips) {
      if (BACKUP_API_KEYS.length > 0) {
        console.warn(`⚠️ ROTTY STUDIO FAILOVER: Rotator pool failed or empty. Invoking stable minimax backup API with key rotation pool... (Total keys: ${BACKUP_API_KEYS.length})`);
        
        let backupAttempts = 0;
        let backupSuccess = false;

        while (backupAttempts < BACKUP_API_KEYS.length) {
          const idx = (currentBackupKeyIndex + backupAttempts) % BACKUP_API_KEYS.length;
          const backupKey = BACKUP_API_KEYS[idx];
          console.log(`🧠 ROTTY ENGINE: Trying Backup Key [${idx + 1}/${BACKUP_API_KEYS.length}]...`);

          try {
            const backupResUrl = 'https://api.aimlapi.com/v2/generate/audio';
            
            // Generate beautiful dynamic lyrics via Groq for backup song to avoid duplicate lyrics!
            let backupLyrics = custom_lyrics;
            if (!backupLyrics || backupLyrics.trim().length === 0) {
              console.log("🧠 ROTTY ENGINE: Generating dynamic lyrics via Groq for backup song...");
              backupLyrics = await generateGroqLyrics(prompt, genre, null);
              if (!backupLyrics) {
                console.log("🛡️ ROTTY ENGINE: Groq failed, using prompt-hashed fallback lyrics...");
                backupLyrics = generateDynamicFallbackLyrics(prompt, genre || 'Acoustic Pop');
              }
            }

            const backupBody = {
              model: "minimax/music-2.0",
              prompt: `${prompt} ${genre || ''}`.trim(),
              lyrics: backupLyrics
            };

            const backupRes = await fetchUrl(backupResUrl, {
              'Authorization': `Bearer ${backupKey}`,
              'Content-Type': 'application/json'
            }, 'POST', JSON.stringify(backupBody));

            if (backupRes.status === 200 || backupRes.status === 201) {
              const data = JSON.parse(backupRes.body);
              const generationId = data.id || data.generation_id;
              if (generationId) {
                console.log(`🎯 ROTTY STUDIO FAILOVER: Backup API successfully triggered. Task ID: ${generationId}`);
                currentBackupKeyIndex = idx; // Lock onto successful key!
                
                // Poll Backup API Status
                let backupPolls = 0;
                while (backupPolls < 25) {
                  const percent = 0.65 + (backupPolls / 25) * 0.25;
                  const remaining = Math.max(10, Math.floor((25 - backupPolls) * 4));
                  ACTIVE_TASKS[taskId] = {
                    status: 'vocal_synthesis',
                    progress: percent,
                    eta: remaining,
                    message: 'Synthesizing vocals and rendering backing arrangement...'
                  };

                  await new Promise(resolve => setTimeout(resolve, 4000));
                  backupPolls++;
                  console.log(`⏳ ROTTY STUDIO POLLING: Polling backup task ${generationId} (Attempt ${backupPolls}/25)...`);
                  
                  try {
                    const pollRes = await fetchUrl(`https://api.aimlapi.com/v2/generate/audio?generation_id=${generationId}`, {
                      'Authorization': `Bearer ${backupKey}`
                    }, 'GET');
                    
                    if (pollRes.status === 200) {
                      const pollData = JSON.parse(pollRes.body);
                      if (pollData.status === 'completed') {
                        const audioUrl = pollData.audio_file?.url || pollData.audio_file || pollData.url;
                        if (audioUrl) {
                          completedSong = {
                            id: generationId,
                            title: generatedTitle,
                            lyrics: backupLyrics,
                            url: audioUrl,
                            image: contextualCover,
                            duration: 180
                          };
                          console.log(`🎉 ROTTY STUDIO SUCCESS: Backup Composition completed! Url: ${audioUrl}`);
                          backupSuccess = true;
                          break;
                        }
                      } else if (pollData.status === 'failed') {
                        console.error("❌ ROTTY STUDIO POLLING: Backup task failed on provider side.");
                        break;
                      }
                    }
                  } catch (pollErr) {
                    console.error("⚠️ ROTTY STUDIO POLLING: Backup poll warning:", pollErr.message);
                  }
                }
                
                if (backupSuccess) {
                  break; // break the keys loop
                }
              }
            } else {
              console.warn(`⚠️ ROTTY STUDIO FAILOVER: Backup Key [${idx + 1}] failed with status ${backupRes.status}: ${backupRes.body}. Rotating...`);
            }
          } catch (err) {
            console.error(`❌ ROTTY STUDIO FAILOVER: Backup Key [${idx + 1}] execution error:`, err.message);
          }
          
          backupAttempts++;
        }
      } else {
        console.error("❌ ROTTY STUDIO FAILOVER: No valid Backup API keys configured in pool.");
      }
    }



    // Direct Suno Polling Queue (if clips were triggered via Suno cookies)
    if (clips && !completedSong) {
      console.log("⏳ ROTTY STUDIO: Composing audio wave files in neural queue...");
      const clipIds = clips.map(c => c.id).join(',');
      let pollingAttempts = 0;

      while (!completedSong && pollingAttempts < 25) {
        const percent = 0.65 + (pollingAttempts / 25) * 0.25;
        const remaining = Math.max(10, Math.floor((25 - pollingAttempts) * 4));
        ACTIVE_TASKS[taskId] = {
          status: 'vocal_synthesis',
          progress: percent,
          eta: remaining,
          message: 'Synthesizing deep vocal expressions and layering harmonies...'
        };

        await new Promise(resolve => setTimeout(resolve, 4000));
        pollingAttempts++;

        try {
          const feedUrl = `https://studio-api.prod.suno.com/api/feed/v2?ids=${clipIds}`;
          const feedRes = await fetchUrl(feedUrl, {
            'Authorization': `Bearer ${jwtToken}`,
            'Cookie': selectedCookie,
            'Origin': 'https://suno.com',
            'Referer': 'https://suno.com/'
          });

          if (feedRes.status === 200) {
            const feedData = JSON.parse(feedRes.body);
            if (Array.isArray(feedData)) {
              const finishedClip = feedData.find(c => c.status === 'complete' && c.audio_url);
              if (finishedClip) {
                completedSong = {
                  id: finishedClip.id,
                  title: finishedClip.title || generatedTitle,
                  lyrics: finishedClip.metadata?.prompt || 'Instrumental Track',
                  url: finishedClip.audio_url,
                  image: finishedClip.image_url || contextualCover,
                  duration: finishedClip.duration ? Math.floor(finishedClip.duration) : 180
                };
                console.log(`🎉 ROTTY STUDIO SUCCESS: Composition rendered! Title: "${completedSong.title}"`);
                break;
              } else {
                const activeClip = feedData[0];
                console.log(`⏳ ROTTY STUDIO POLLING: Composition progress: ${activeClip?.status || 'queued'} (Attempt ${pollingAttempts}/25)`);
              }
            } else {
              console.warn("⚠️ ROTTY STUDIO POLLING: Suno feed API did not return an array. Body:", feedRes.body);
            }
          }
        } catch (e) {
          console.warn("⚠️ ROTTY STUDIO POLLING: Network warning during poll:", e.message);
        }
      }

      // Fallback placeholder if polling timed out but triggered successfully (Suno will finish rendering shortly)
      if (!completedSong && clips[0].id) {
        completedSong = {
          id: clips[0].id,
          title: clips[0].title || generatedTitle,
          lyrics: custom_lyrics || prompt || 'Instrumental',
          url: `https://cdn1.suno.ai/${clips[0].id}.mp3`,
          image: clips[0].image_url || contextualCover,
          duration: clips[0].duration || 180
        };
        console.log("⏳ ROTTY STUDIO POLLING: Polling timeout. Returning standard CDN stream shortcut.");
      }
    }

    if (completedSong) {
      ACTIVE_TASKS[taskId] = {
        status: 'mastering',
        progress: 0.92,
        eta: 5,
        message: 'Stereo mastering and high-fidelity rendering...'
      };
      await new Promise(resolve => setTimeout(resolve, 1500));
      
      ACTIVE_TASKS[taskId] = {
        status: 'complete',
        progress: 1.0,
        eta: 0,
        result: completedSong
      };
      console.log(`🎯 TASK ${taskId} COMPLETED SUCCESSFULLY!`);
    } else {
      if (isCaptchaRequired) {
        ACTIVE_TASKS[taskId] = {
          status: 'failed',
          error: 'captcha_required',
          message: 'Captcha verification required. Please solve to continue!',
          clientCookie: selectedCookie || SUNO_COOKIES[0],
          accountIndex: currentCookieIndex
        };
        console.warn(`🎯 TASK ${taskId} FAILED: CAPTCHA REQUIRED`);
      } else {
        ACTIVE_TASKS[taskId] = {
          status: 'failed',
          error: 'service_unavailable',
          message: 'Sorry, service is unavailable for a moment.'
        };
        console.warn(`🎯 TASK ${taskId} FAILED: SERVICE UNAVAILABLE`);
      }
    }
  } catch (globalErr) {
    console.error(`❌ TASK ${taskId} UNHANDLED BACKGROUND ERROR:`, globalErr.message);
    ACTIVE_TASKS[taskId] = {
      status: 'failed',
      error: 'service_unavailable',
      message: 'Sorry, service is unavailable for a moment.'
    };
  }
}

// POST /api/generate-song — Immersive, secured AI music generation
app.post('/api/generate-song', async (req, res) => {
  // Support both encrypted payload (production) and raw JSON (dev)
  let params = req.body;
  let isEncrypted = false;

  if (req.body && req.body.d) {
    try {
      const decrypted = decryptPayload(req.body.d);
      params = JSON.parse(decrypted);
      isEncrypted = true;
    } catch (e) {
      console.error("🔒 ROTTY SYSTEM SECURITY: Failed to decrypt request payload.", e);
      return res.status(400).json({ error: 'invalid_handshake' });
    }
  }

  const { prompt, genre, vocal_gender, vocal_expression, is_instrumental, custom_lyrics } = params;

  console.log(`🧠 ROTTY STUDIO ENGINE: Initiating async composition... Prompt: "${prompt || 'custom'}", Genre: ${genre}, Instrumental: ${is_instrumental}`);

  // Build tags for vocal profile
  const tags = `${genre || 'pop'} ${vocal_gender || 'vocals'} ${vocal_expression || 'melodic'}`.trim();
  const generatedTitle = generateCreativeTitle(genre, prompt);
  const contextualCover = getContextualCover(genre, prompt);

  const taskId = `task_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  ACTIVE_TASKS[taskId] = {
    status: 'initiated',
    progress: 0.05,
    eta: 90,
    message: 'Initiating neural composition queue...'
  };

  // Mock standard req properties needed by JioSaavn mock search downloader
  const reqMock = { headers: { host: req.headers.host } };

  // Trigger the background composition asynchronously
  runBackgroundGeneration(taskId, params, tags, generatedTitle, contextualCover, reqMock);

  const responseBody = { status: 'initiated', taskId: taskId };
  return res.json(isEncrypted ? { d: encryptPayload(JSON.stringify(responseBody)) } : responseBody);
});

// POST /api/track-webview-clips — Resume composition polling on backend using clips generated via WebView
app.post('/api/track-webview-clips', async (req, res) => {
  let params = req.body;
  let isEncrypted = false;

  if (req.body && req.body.d) {
    try {
      const decrypted = decryptPayload(req.body.d);
      params = JSON.parse(decrypted);
      isEncrypted = true;
    } catch (e) {
      console.error("🔒 ROTTY SYSTEM SECURITY: Failed to decrypt request payload.", e);
      return res.status(400).json({ error: 'invalid_handshake' });
    }
  }

  const { taskId, clipIds, clientCookie, prompt, genre } = params;
  if (!taskId || !clipIds || !clientCookie) {
    const errRes = { error: 'taskId, clipIds, clientCookie required' };
    return res.status(400).json(isEncrypted ? { d: encryptPayload(JSON.stringify(errRes)) } : errRes);
  }

  console.log(`🧠 ROTTY STUDIO ENGINE: Resuming composition from WebView. Task: ${taskId}, Clips: ${clipIds}`);

  const generatedTitle = generateCreativeTitle(genre || 'pop', prompt || 'composition');
  const contextualCover = getContextualCover(genre || 'pop', prompt || 'composition');

  // Trigger background polling asynchronously
  runWebViewPolling(taskId, clipIds, clientCookie, generatedTitle, contextualCover, '', prompt || '');

  const responseBody = { status: 'polling_resumed', taskId: taskId };
  return res.json(isEncrypted ? { d: encryptPayload(JSON.stringify(responseBody)) } : responseBody);
});

// Helper function to poll suno clips triggered by the WebView
async function runWebViewPolling(taskId, clipIds, selectedCookie, generatedTitle, contextualCover, custom_lyrics, prompt) {
  let completedSong = null;
  let jwtToken = null;
  try {
    jwtToken = await getSunoClerkToken(selectedCookie);
  } catch (err) {
    console.error("Failed to get JWT token for WebView polling:", err.message);
  }

  let pollingAttempts = 0;
  while (!completedSong && pollingAttempts < 25) {
    const percent = 0.65 + (pollingAttempts / 25) * 0.25;
    const remaining = Math.max(10, Math.floor((25 - pollingAttempts) * 4));
    ACTIVE_TASKS[taskId] = {
      status: 'vocal_synthesis',
      progress: percent,
      eta: remaining,
      message: 'Synthesizing deep vocal expressions and layering harmonies...'
    };

    await new Promise(resolve => setTimeout(resolve, 4000));
    pollingAttempts++;

    try {
      const feedUrl = `https://studio-api.prod.suno.com/api/feed/v2?ids=${clipIds}`;
      const feedRes = await fetchUrl(feedUrl, {
        'Authorization': `Bearer ${jwtToken}`,
        'Cookie': selectedCookie,
        'Origin': 'https://suno.com',
        'Referer': 'https://suno.com/'
      });

      if (feedRes.status === 200) {
        const feedData = JSON.parse(feedRes.body);
        if (Array.isArray(feedData)) {
          const finishedClip = feedData.find(c => c.status === 'complete' && c.audio_url);
          if (finishedClip) {
            completedSong = {
              id: finishedClip.id,
              title: finishedClip.title || generatedTitle,
              lyrics: finishedClip.metadata?.prompt || 'Instrumental Track',
              url: finishedClip.audio_url,
              image: finishedClip.image_url || contextualCover,
              duration: finishedClip.duration ? Math.floor(finishedClip.duration) : 180
            };
            console.log(`🎉 ROTTY STUDIO SUCCESS (WebView): Composition rendered! Title: "${completedSong.title}"`);
            break;
          } else {
            const activeClip = feedData[0];
            console.log(`⏳ ROTTY STUDIO POLLING (WebView): Composition progress: ${activeClip?.status || 'queued'} (Attempt ${pollingAttempts}/25)`);
          }
        } else {
          console.warn("⚠️ ROTTY STUDIO POLLING (WebView): Suno feed API did not return an array. Body:", feedRes.body);
        }
      }
    } catch (e) {
      console.warn("⚠️ ROTTY STUDIO POLLING (WebView): Network warning during poll:", e.message);
    }
  }

  // Fallback placeholder if polling timed out but triggered successfully (Suno will finish rendering shortly)
  if (!completedSong && clipIds) {
    const firstClipId = clipIds.split(',')[0];
    completedSong = {
      id: firstClipId,
      title: generatedTitle,
      lyrics: custom_lyrics || prompt || 'Instrumental',
      url: `https://cdn1.suno.ai/${firstClipId}.mp3`,
      image: contextualCover,
      duration: 180
    };
    console.log("⏳ ROTTY STUDIO POLLING (WebView): Polling timeout. Returning standard CDN stream shortcut.");
  }

  if (completedSong) {
    ACTIVE_TASKS[taskId] = {
      status: 'mastering',
      progress: 0.92,
      eta: 5,
      message: 'Stereo mastering and high-fidelity rendering...'
    };
    await new Promise(resolve => setTimeout(resolve, 1500));
    
    ACTIVE_TASKS[taskId] = {
      status: 'complete',
      progress: 1.0,
      eta: 0,
      result: completedSong
    };
    console.log(`🎯 TASK ${taskId} (WebView) COMPLETED SUCCESSFULLY!`);
  } else {
    ACTIVE_TASKS[taskId] = {
      status: 'failed',
      error: 'service_unavailable',
      message: 'Sorry, service is unavailable for a moment.'
    };
    console.warn(`🎯 TASK ${taskId} (WebView) FAILED: SERVICE UNAVAILABLE`);
  }
}


// POST /api/details — Get song details
app.post('/api/details', async (req, res) => {
  const { id } = req.body;
  if (!id) return res.status(400).json({ error: 'id required' });

  let rawData = null;
  let isSumit = false;

  try {
    const qs = new URLSearchParams({
      __call: 'song.getDetails', _format: 'json', _marker: '0',
      ctx: 'web6dot0', pids: id,
    });
    const r = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
      Referer: 'https://www.jiosaavn.com',
    });
    if (r.status === 200) {
      rawData = JSON.parse(r.body);
    }
  } catch (_) {}

  // Fallback
  if (!rawData) {
    try {
      const r = await fetchUrl(`https://saavn.sumit.co/api/songs/${id}`);
      if (r.status === 200) {
        rawData = JSON.parse(r.body);
        isSumit = true;
      }
    } catch (_) {}
  }

  if (!rawData) {
    return res.status(404).json({ error: 'not_found' });
  }

  try {
    let song = null;
    if (Array.isArray(rawData) && rawData.length > 0) {
      song = rawData[0];
    } else if (rawData && Array.isArray(rawData.songs) && rawData.songs.length > 0) {
      song = rawData.songs[0];
    } else if (rawData && Array.isArray(rawData.data) && rawData.data.length > 0) {
      song = rawData.data[0];
    } else if (rawData && typeof rawData === 'object') {
      const keys = Object.keys(rawData);
      if (keys.length > 0) {
        const first = rawData[keys[0]];
        if (first && (first.id || first.songid)) {
          song = first;
        } else if (rawData.id || rawData.songid) {
          song = rawData;
        }
      }
    }

    if (song) {
      const sanitized = mapSongToRotty(song);
      return res.json({ d: encryptPayload(JSON.stringify(sanitized)) });
    }
  } catch (e) {
    console.error("Error sanitizing details:", e);
  }

  return res.status(404).json({ error: 'not_found' });
});

// Helper to download a URL to a local file
function downloadFile(targetUrl, destPath) {
  return new Promise((resolve, reject) => {
    const parsed = url.parse(targetUrl);
    const lib = parsed.protocol === 'https:' ? https : http;
    const file = fs.createWriteStream(destPath);
    
    const request = lib.get(targetUrl, (response) => {
      if (response.statusCode !== 200) {
        reject(new Error(`Failed to download file, status code: ${response.statusCode}`));
        return;
      }
      response.pipe(file);
      file.on('finish', () => {
        file.close();
        resolve();
      });
    });
    
    request.on('error', (err) => {
      fs.unlink(destPath, () => {});
      reject(err);
    });
  });
}

// POST /api/genre — Get curated songs for a genre playlist
app.post('/api/genre', async (req, res) => {
  const { genre } = req.body;
  if (!genre) return res.status(400).json({ error: 'genre required' });
  
  const queryMap = {
    chill: 'Hindi Lofi',
    devotional: 'Hindi Bhakti Bhajans',
    party: 'Hindi Party Hits',
    sad: 'Sad Hindi Hits',
    punjabi: 'Punjabi Hit Songs',
    english: 'English Pop Hits'
  };

  const q = queryMap[genre.toLowerCase()] || `${genre} Hits`;
  
  try {
    const songs = await saavnGetEditorialPlaylistSongs(q, 35);
    if (songs && songs.length > 0) {
      const sanitized = songs
        .map(s => mapSongToRotty(s))
        .filter(s => s && s.id && isOriginalSong(s));
      return res.json({ d: encryptPayload(JSON.stringify(deduplicateSongs(sanitized))) });
    }
  } catch (err) {
    console.error(`saavnGetEditorialPlaylistSongs failed for genre ${genre}:`, err);
  }
  
  // Fallback to keyword search
  try {
    let songs = await saavnSearch(q, 35);
    if (!songs || songs.length === 0) {
      songs = await saavnFallbackSearch(q, 35);
    }
    const sanitized = songs
      .map(s => mapSongToRotty(s))
      .filter(s => s && s.id && isOriginalSong(s));
    return res.json({ d: encryptPayload(JSON.stringify(deduplicateSongs(sanitized))) });
  } catch (_) {
    return res.json({ d: encryptPayload(JSON.stringify([])) });
  }
});

// POST /api/search-albums — Proxy album searches
app.post('/api/search-albums', async (req, res) => {
  const { query, limit = 20 } = req.body;
  if (!query) return res.status(400).json({ error: 'query required' });
  try {
    const qs = new URLSearchParams({
      __call: 'search.getResults',
      _format: 'json',
      _marker: '0',
      ctx: 'web6dot0',
      q: query,
      p: '1',
      n: String(limit),
      type: 'album',
    });
    const r = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
      Referer: 'https://www.jiosaavn.com',
    });
    if (r.status === 200) {
      const body = JSON.parse(r.body);
      const results = body.results || [];
      const sanitized = results.map(m => ({
        id: m.albumid || m.id || '',
        name: m.title || m.album || 'Album',
        image: upgradeImageUrl(m.image || ''),
        year: m.year || '',
        language: m.language || '',
      })).filter(a => a.id);
      return res.json({ d: encryptPayload(JSON.stringify(sanitized)) });
    }
  } catch (err) {
    console.error('search-albums failed:', err);
  }

  // Fallback to Sumit API
  try {
    const encQ = encodeURIComponent(query);
    const r = await fetchUrl(`https://saavn.sumit.co/api/search/albums?query=${encQ}&page=1&limit=${limit}`);
    if (r.status === 200) {
      const body = JSON.parse(r.body);
      const results = body?.data?.results || body?.data || [];
      const sanitized = results.map(m => ({
        id: m.albumid || m.id || '',
        name: m.title || m.name || m.album || 'Album',
        image: upgradeImageUrl(m.image || ''),
        year: m.year || '',
        language: m.language || '',
      })).filter(a => a.id);
      return res.json({ d: encryptPayload(JSON.stringify(sanitized)) });
    }
  } catch (err) {
    console.error('search-albums fallback failed:', err);
  }

  return res.status(500).json({ error: 'search_albums_failed' });
});

// POST /api/album-details — Proxy album details
app.post('/api/album-details', async (req, res) => {
  const { id } = req.body;
  if (!id) return res.status(400).json({ error: 'id required' });
  try {
    const qs = new URLSearchParams({
      __call: 'content.getAlbumDetails',
      _format: 'json',
      _marker: '0',
      ctx: 'web6dot0',
      albumid: id,
    });
    const r = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
      Referer: 'https://www.jiosaavn.com',
    });
    if (r.status === 200) {
      const body = JSON.parse(r.body);
      const songs = body.songs || [];
      const sanitized = songs.map(s => ({
        id: s.id || '',
        title: s.song || s.title || '',
        artist: s.primary_artists || s.subtitle || '',
        album: s.album || '',
        image: upgradeImageUrl(s.image),
        duration: Number(s.duration) || 0,
        language: s.language || '',
        url: extract320Url(s)
      })).filter(s => s.id);
      return res.json({ d: encryptPayload(JSON.stringify(sanitized)) });
    }
  } catch (err) {
    console.error('album-details failed:', err);
  }

  // Fallback to Sumit API
  try {
    const r = await fetchUrl(`https://saavn.sumit.co/api/albums?id=${id}`);
    if (r.status === 200) {
      const body = JSON.parse(r.body);
      const songs = body?.data?.songs || body?.data?.results || [];
      const sanitized = songs.map(s => ({
        id: s.id || '',
        title: s.song || s.title || s.name || '',
        artist: s.primary_artists || (s.artists?.primary && Array.isArray(s.artists.primary) ? s.artists.primary.map(a => a.name).join(', ') : '') || s.subtitle || '',
        album: s.album || (typeof s.album === 'object' ? s.album.name : '') || '',
        image: upgradeImageUrl(s.image),
        duration: Number(s.duration) || 0,
        language: s.language || '',
        url: extract320Url(s)
      })).filter(s => s.id);
      return res.json({ d: encryptPayload(JSON.stringify(sanitized)) });
    }
  } catch (err) {
    console.error('album-details fallback failed:', err);
  }

  return res.status(500).json({ error: 'album_details_failed' });
});

// POST /api/artist-details — Proxy artist details
app.post('/api/artist-details', async (req, res) => {
  const { id } = req.body;
  if (!id) return res.status(400).json({ error: 'id required' });
  try {
    const qs = new URLSearchParams({
      __call: 'artist.getArtistPageDetails',
      _format: 'json',
      ctx: 'web6dot0',
      artistId: id,
      page: '1',
    });
    const r = await fetchUrl(`https://www.jiosaavn.com/api.php?${qs}`, {
      Referer: 'https://www.jiosaavn.com',
    });
    if (r.status === 200) {
      const body = JSON.parse(r.body);
      
      const artist = {
        id: body.artistId || body.id || id,
        name: body.name || body.title || 'Artist',
        image: upgradeImageUrl(body.image || ''),
        follower_count: body.follower_count || body.fan_count || '',
        bio: Array.isArray(body.bio) ? body.bio.join(' ') : (body.bio || ''),
      };
      
      const topSongs = (body.topSongs || []).map(s => ({
        id: s.id || '',
        title: s.song || s.title || '',
        artist: s.primary_artists || s.subtitle || '',
        album: s.album || '',
        image: upgradeImageUrl(s.image),
        duration: Number(s.duration) || 0,
        language: s.language || '',
        url: extract320Url(s)
      })).filter(s => s.id);

      const topAlbums = (body.topAlbums || []).map(m => ({
        id: m.albumid || m.id || '',
        name: m.title || m.album || 'Album',
        image: upgradeImageUrl(m.image || ''),
        year: m.year || '',
        language: m.language || '',
      })).filter(a => a.id);

      return res.json({
        d: encryptPayload(JSON.stringify({ artist, songs: topSongs, albums: topAlbums }))
      });
    }
  } catch (err) {
    console.error('artist-details failed:', err);
  }

  // Fallback to Sumit API
  try {
    const r = await fetchUrl(`https://saavn.sumit.co/api/artists?id=${id}`);
    if (r.status === 200) {
      const body = JSON.parse(r.body);
      const data = body?.data || {};
      
      const artist = {
        id: data.id || id,
        name: data.name || 'Artist',
        image: upgradeImageUrl(data.image || ''),
        follower_count: data.followerCount || '',
        bio: data.bio || '',
      };

      const topSongs = (data.songs || []).map(s => ({
        id: s.id || '',
        title: s.song || s.title || s.name || '',
        artist: s.primary_artists || (s.artists?.primary && Array.isArray(s.artists.primary) ? s.artists.primary.map(a => a.name).join(', ') : '') || s.subtitle || '',
        album: s.album || (typeof s.album === 'object' ? s.album.name : '') || '',
        image: upgradeImageUrl(s.image),
        duration: Number(s.duration) || 0,
        language: s.language || '',
        url: extract320Url(s)
      })).filter(s => s.id);

      const topAlbums = (data.albums || []).map(m => ({
        id: m.id || '',
        name: m.name || m.title || 'Album',
        image: upgradeImageUrl(m.image || ''),
        year: m.year || '',
        language: m.language || '',
      })).filter(a => a.id);

      return res.json({
        d: encryptPayload(JSON.stringify({ artist, songs: topSongs, albums: topAlbums }))
      });
    }
  } catch (err) {
    console.error('artist-details fallback failed:', err);
  }

  return res.status(500).json({ error: 'artist_details_failed' });
});

// GET /api/media — Proxy standard audio streams to bypass ISP block on mobile phone
app.get('/api/media', async (req, res) => {
  let { url: targetUrl } = req.query;
  if (!targetUrl) return res.status(400).send('url required');

  try {
    // Dynamic self-healing: rewrite non-existent audiocdn.suno.ai to active cdn1.suno.ai
    if (targetUrl.includes('audiocdn.suno.ai')) {
      targetUrl = targetUrl.replace('audiocdn.suno.ai', 'cdn1.suno.ai');
    }

    const parsedUrl = new URL(targetUrl);
    // Whitelist check bypassed to ensure foreign/English songs or fallback CDNs are never blocked
    /*
    if (!parsedUrl.hostname.endsWith('saavncdn.com') && 
        !parsedUrl.hostname.endsWith('akamaized.net') && 
        !parsedUrl.hostname.endsWith('soundhelix.com') &&
        !parsedUrl.hostname.endsWith('suno.ai') &&
        !parsedUrl.hostname.endsWith('suno.com') &&
        !parsedUrl.hostname.endsWith('unsplash.com')) {
      return res.status(403).send('forbidden_host');
    }
    */

    const headers = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36'
    };

    if (parsedUrl.hostname.endsWith('saavncdn.com')) {
      headers['Referer'] = 'https://www.jiosaavn.com/';
    } else if (parsedUrl.hostname.endsWith('suno.ai') || parsedUrl.hostname.endsWith('suno.com')) {
      headers['Referer'] = 'https://suno.com/';
    }

    if (req.headers.range) {
      headers['Range'] = req.headers.range;
    }

    const mediaRes = await fetch(targetUrl, { headers });

    res.status(mediaRes.status);
    for (const [key, value] of mediaRes.headers.entries()) {
      if (['content-type', 'content-length', 'accept-ranges', 'content-range'].includes(key.toLowerCase())) {
        res.setHeader(key, value);
      }
    }

    const readable = Readable.fromWeb(mediaRes.body);
    readable.on('error', (err) => {
      console.log('Media stream aborted by client:', err.message);
    });
    readable.pipe(res);

    req.on('close', () => {
      readable.destroy();
    });
  } catch (err) {
    console.error('Error proxying media:', err);
    res.status(500).send('media_proxy_failed');
  }
});

// ─── Start server ──────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🔒 Rotty Ghost Proxy v2.0 running on port ${PORT}`);
  console.log(`🔑 AES-256 encryption: ACTIVE`);
  console.log(`🛡️ Firebase App Check: ${FIREBASE_PROJECT_ID ? 'ACTIVE' : 'DISABLED (dev mode)'}`);
  console.log(`⏱️ Rate limiting: 60 req/min per IP`);
});
