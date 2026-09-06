# 🎧 Echo Music (`EchoMusicApp/Echo-Music`) — Comprehensive Forensic Architecture & Engineering Analysis

A deep-dive technical research report analyzing the complete source code, reverse-engineered InnerTube streaming pipeline, lyrics engine, and UI/UX design system of **Echo Music** ([GitHub: EchoMusicApp/Echo-Music](https://github.com/EchoMusicApp/Echo-Music)), one of the most advanced open-source YouTube Music clients on Android.

---

## 📑 Executive Summary

| Attribute | Details |
| :--- | :--- |
| **Repository** | `EchoMusicApp/Echo-Music` (930+ Stars, 100+ Forks) |
| **Primary Language** | Kotlin 2.0+ & Jetpack Compose (Skia 120Hz pipeline) |
| **Audio Engine** | Android Media3 `ExoPlayer` with `ResolvingDataSource` & `CacheDataSource` |
| **Streaming Mechanism** | YouTube InnerTube `POST /player` with `VISIONOS` & `ANDROID_VR 1.65.10` cascade |
| **Lyrics Subsystem** | Multi-source engine: `BetterLyrics` (TTML word-by-word), `Lrclib`, `Kugou`, `Paxsenix` |
| **Visuals & Motion** | Apple Music Motion Canvas (`editorialVideo` HLS looping video), Material 3 Expressive Carousel |
| **Smart Features** | "Echo Brain" on-device recommendation momentum, "Echo Find" audio fingerprinting |

---

## 🔬 1. The Core Streaming Architecture & The "1 MiB 403 Stutter" Fix

### 🚨 The 1 MiB Audio Stall Mystery Uncovered
In most standard YouTube Music open-source apps (and previous implementations), audio playback dies after **30 to 70 seconds**. Echo Music's engineering team performed binary search network probes to uncover the root cause:
- YouTube's CDN (`googlevideo.com`) deliberately returns a **1 MiB stream preview** for standard clients (`IOS`, `IPADOS`, older `ANDROID_VR 1.43.32`).
- As soon as the client requests bytes beyond the 1 MiB boundary (`bytes=1048576-...`), Google Video returns **`HTTP 403 Forbidden`**.

```
Video ID       itag 251 Last Readable Byte   Duration of Playable Audio
--------------------------------------------------------------------
Rr1Cdli5nE8    1040807 bytes                 ~61s (out of 268s)
phLb_SoPBlA    1049091 bytes                 ~61s (out of 274s)
UbX5Yns8fHk    1019638 bytes                 ~67s (out of 159s)
```

### 💡 Echo Music's Breakthrough Solution: The Client Cascade
Echo Music identified two specific client identities that return **100% direct-URL, unthrottled, whole-file audio streams without signature cipher**:

```kotlin
val STREAM_FALLBACK_CLIENTS: Array<YouTubeClient> = arrayOf(
    VISIONOS,            // clientName: "VISIONOS", clientVersion: "0.1", clientId: "101" -> 100% whole-file
    ANDROID_VR_1_65_10,  // Oculus Quest 3 pinned version -> 100% whole-file direct URLs
    TVHTML5,             // Smart TV fallback for uploaded tracks
    WEB_CREATOR          // Required for explicit / age-restricted content
)
```

1. **`VISIONOS` (Apple Vision Pro)**:
   - `clientName = "VISIONOS"`
   - `clientVersion = "0.1"`
   - `clientId = "101"`
   - `userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"`
   - `osName = "visionOS"`, `osVersion = "1.3.21O771"`, `deviceMake = "Apple"`, `deviceModel = "RealityDevice14,1"`
   - **Tested behavior**: Streams full 4.5 MB+ files start-to-finish without 403 errors!

2. **`ANDROID_VR_1_65_10` (Oculus Quest 3)**:
   - `clientName = "ANDROID_VR"`, `clientVersion = "1.65.10"`, `clientId = "28"`
   - `userAgent = "com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip"`
   - Returns unencrypted direct URLs (`itag 251` Opus & `itag 140` AAC) without signature transformations.

---

## 🎵 2. Synchronized Lyrics Engine (`BetterLyrics` & TTML)

Echo Music does not rely solely on standard line-by-line LRC files. It integrates a dedicated multi-provider architecture:

1. **`BetterLyrics` Module (`echo.music.iad1tya.betterlyrics`)**:
   - Provider: `https://lyrics-api.boidu.dev/getLyrics`
   - Parameters: `s={title}`, `a={artist}`, `d={duration}`, `al={album}`
   - Returns **TTML (Timed Text Markup Language)** containing precise millisecond timestamps for each individual word/syllable.
2. **`TTMLParser`**:
   - Parses `<span begin="00:01.250" end="00:01.650">Word</span>` into active lyric tokens.
   - Provides karaoke-style active glow word highlighting as the song progresses.
3. **Fallback Cascade**:
   - If TTML is unavailable, it cascades to **LRCLIB** (`https://lrclib.net/api/get`), **Kugou**, and **Paxsenix**.

---

## 🎨 3. Apple Music Animated Motion Canvas (`AppleMusicCanvasProvider`)

One of Echo Music's standout visual features is animated album artwork:
- **Strategy**: Queries `https://itunes.apple.com/search` to match the album and artist, then queries Apple Music AMP API (`https://amp-api.music.apple.com`) with `?extend=editorialVideo`.
- **Playback**: If an album features Apple Motion artwork, it extracts the HLS video stream and loops it silently behind the player UI, providing the identical aesthetic to the Apple Music app!
- **Caching**: Motion artwork URLs are cached in memory for 24 hours to reduce latency and data consumption.

---

## 📱 4. UI/UX Design System & Polish (`DESIGN.md` Guidelines)

From `DESIGN.md` in Echo Music:
1. **Liquid Glass & Translucency**:
   - Never use solid M3 surface colors.
   - Cards and containers use `surfaceVariant.copy(alpha = 0.3f)` with frosted background blur (`Modifier.blur(20.dp)` or backdrop filter).
   - Card shapes: `RoundedCornerShape(24.dp)` or `28.dp`.
2. **Floating Bottom Navigation**:
   - Replaces traditional bottom navigation bars with an iOS-style floating pill tab bar (`ui/component/floatingtabbar/`).
3. **Dynamic Accent Canvas**:
   - Uses Palette API to extract dominant and vibrant colors from the album cover, generating a living gradient backdrop that breathes with music changes.

---

## 🧠 5. "Echo Brain" On-Device Momentum Recommendations

- **Concept**: Rather than generating static "Up Next" queues, Echo Brain runs an on-device recommendation graph that monitors user behavior:
  - If a user skips early (<15s), track genre weights are deprioritized.
  - If a user completes a track or loops it, momentum weights boost similar tracks from related YouTube Music radios.
  - Dynamically auto-injects tracks into the queue ahead of time so playback never ends.

---

## 🚀 6. Actionable Takeaways for Rotty Music (Web & Desktop)

| Echo Music Feature | How We Apply It to Rotty Music |
| :--- | :--- |
| **`VISIONOS` / `ANDROID_VR` Innertube Client Cascade** | Incorporate into our Hugging Face / backend proxy resolver so YouTube audio streams never hit the 1 MiB 403 block. |
| **TTML Word-by-Word Karaoke Engine** | Hook `https://lyrics-api.boidu.dev` into our `NowPlayingPanel.tsx` & Kotlin `LyricsScreen.kt` for per-word lyric illumination. |
| **Apple Motion Canvas Artwork** | Add optional Apple Music Motion video loop backdrop in the fullscreen Now Playing view using `itunes.apple.com/search`. |
| **Translucent Glass Cards (24dp)** | Align with our existing Liquid Glass design tokens across both the Web Vite App and Kotlin Desktop app. |
