import React, { createContext, useContext, useState, useEffect, useRef } from 'react';
import type { Song } from '../services/api';
import { MusicApi } from '../services/api';
import { StorageService } from '../services/storage';
import { RottyConnectService } from '../services/rottyConnect';
import type { SyncDevice, PlaybackState } from '../services/rottyConnect';
import { SupabaseService } from '../services/supabase';
import type { PartyRoom } from '../services/supabase';
import {
  getCachedVideoObjectUrl,
  invalidateCachedVideo,
  prefetchCachedVideo,
  releaseCachedVideoObjectUrl
} from '../services/videoCache';

type LoopMode = 'none' | 'one' | 'all';

const getSongFingerprint = (s: Song) => {
  if (!s || !s.title) return '';
  let title = s.title.toLowerCase();
  title = title.replace(/\([^)]*\)/g, '').replace(/\[[^\]]*\]/g, '');
  title = title.replace(/\b(lofi|remix|acoustic|reprise|cover|radio|edit|slowed|reverb|version|mix|original)\b/g, '');
  const cleanTitle = title.replace(/[^a-z0-9]/g, '');
  
  const cleanArtist = (s.artist || '').toLowerCase()
    .split(',')[0]
    .trim()
    .replace(/\b(feat|ft|featuring)\b.*/gi, '')
    .replace(/[^a-z0-9]/g, '');
    
  return `${cleanTitle}|${cleanArtist}`;
};

const getLanguageFallbackQuery = (seed: Song, isSecondary = false): string => {
  if (!seed) return 'trending hindi';
  const lang = (seed.language || '').toLowerCase().trim();
  const artist = (seed.artist || '').split(',')[0].trim();
  
  if (isSecondary) {
    if (lang === 'english') return 'trending english';
    if (lang === 'punjabi') return 'trending punjabi';
    if (lang === 'telugu') return 'trending telugu';
    if (lang === 'tamil') return 'trending tamil';
    return 'trending hindi';
  }
  
  if (artist && artist !== 'Artist') {
    return `${artist} songs`;
  }
  
  if (lang === 'english') return 'trending english';
  if (lang === 'punjabi') return 'trending punjabi';
  if (lang === 'telugu') return 'trending telugu';
  if (lang === 'tamil') return 'trending tamil';
  return 'trending hindi';
};

interface AudioContextType {
  currentSong: Song | null;
  isPlaying: boolean;
  currentTime: number;
  duration: number;
  volume: number;
  youtubeVideoId: string | null;
  videoUrl: string | null;
  isVideoMode: boolean;
  isResolvingVideo: boolean;
  toggleVideoMode: () => void;
  onYoutubeVideoError: () => void;
  queue: Song[];
  queueIndex: number;
  isShuffle: boolean;
  isLoop: LoopMode;
  
  // Rotty Labs EQ / Effects
  bassBoost: number; // 0 to 12 dB
  vocalForward: boolean;
  is8DActive: boolean;

  // Autoplay & Sync
  isAutoplay: boolean;
  toggleAutoplay: () => void;
  triggerAiRefill: () => Promise<void>;
  isSyncControlled: boolean;
  setIsSyncControlled: (controlled: boolean) => void;
  syncPlaybackState: PlaybackState | null;
  syncDevices: SyncDevice[];
  refreshSyncDevices: () => Promise<void>;

  // Party Sync
  partyCode: string | null;
  partyRoom: PartyRoom | null;
  isPartyHost: boolean;
  createPartyRoom: () => Promise<string>;
  joinPartyRoom: (code: string) => Promise<void>;
  leavePartyRoom: () => Promise<void>;
  kickPartyMember: (uid: string) => Promise<void>;

  playSong: (song: Song, customQueue?: Song[]) => void;
  togglePlay: () => void;
  nextSong: () => void;
  prevSong: () => void;
  seek: (time: number) => void;
  setVolume: (vol: number) => void;
  toggleShuffle: () => void;
  toggleLoop: () => void;
  setBassBoost: (boost: number) => void;
  setVocalForward: (active: boolean) => void;
  set8DActive: (active: boolean) => void;
  addToQueue: (song: Song) => void;
  playNext: (song: Song) => void;
  removeFromQueue: (songId: string) => void;
  clearQueue: () => void;
  moveQueueItem: (fromIndex: number, toIndex: number) => void;
}

const AudioContext = createContext<AudioContextType | undefined>(undefined);

export const AudioProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [currentSong, setCurrentSong] = useState<Song | null>(null);
  const [isPlaying, setIsPlaying] = useState<boolean>(false);
  const [currentTime, setCurrentTime] = useState<number>(0);
  const [duration, setDuration] = useState<number>(0);
  const [volume, setVolumeState] = useState<number>(() => StorageService.getVolume());
  const [queue, setQueue] = useState<Song[]>([]);
  const [queueIndex, setQueueIndex] = useState<number>(-1);
  const [isShuffle, setIsShuffle] = useState<boolean>(false);
  const [isLoop, setIsLoop] = useState<LoopMode>('none');
  
  // Effects states
  const [bassBoost, setBassBoostState] = useState<number>(0);
  const [vocalForward, setVocalForwardState] = useState<boolean>(false);
  const [is8DActive, set8DActiveState] = useState<boolean>(false);

  // Autoplay & Sync States
  const [isAutoplay, setIsAutoplay] = useState<boolean>(() => localStorage.getItem('rotty_autoplay') !== 'false');
  const [isSyncControlled, setIsSyncControlled] = useState<boolean>(false);
  const [syncPlaybackState, setSyncPlaybackState] = useState<PlaybackState | null>(null);
  const [syncDevices, setSyncDevices] = useState<SyncDevice[]>([]);

  // Party Sync States
  const [partyCode, setPartyCode] = useState<string | null>(null);
  const [partyRoom, setPartyRoom] = useState<PartyRoom | null>(null);
  const [isPartyHost, setIsPartyHost] = useState<boolean>(false);
  const partyWatcherRef = useRef<(() => void) | null>(null);
  const isSyncingFromPartyRef = useRef<boolean>(false);
  const prefetchedForSongIdRef = useRef<string>('');
  const prefetchedStreamForSongIdRef = useRef<string>('');
  const triggerAiRef = useRef<() => Promise<void>>(() => Promise.resolve());
  const togglePlayHandlerRef = useRef<() => void>(() => {});
  const nextSongHandlerRef = useRef<() => void>(() => {});
  const prevSongHandlerRef = useRef<() => void>(() => {});
  const seekHandlerRef = useRef<(time: number) => void>(() => {});

  // Refs for audio engine
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const originalQueueRef = useRef<Song[]>([]);
  const [youtubeVideoId, setYoutubeVideoId] = useState<string | null>(null);
  const [videoUrl, setVideoUrl] = useState<string | null>(null);
  const [isVideoMode, setIsVideoMode] = useState<boolean>(false);
  const [isResolvingVideo, setIsResolvingVideo] = useState<boolean>(false);
  const activeVideoIdRef = useRef<string | null>(null);
  const videoAbortRef = useRef<AbortController | null>(null);
  const prefetchedVideoForSongIdRef = useRef<string>('');

  // Web Audio EQ Node references
  const audioCtxRef = useRef<AudioContext | null>(null);
  const sourceNodeRef = useRef<MediaElementAudioSourceNode | null>(null);
  const bassFilterRef = useRef<BiquadFilterNode | null>(null);
  const vocalFilterRef = useRef<BiquadFilterNode | null>(null);
  const pannerNodeRef = useRef<StereoPannerNode | null>(null);
  const orbitIntervalRef = useRef<number | null>(null);

  const handleSongEndedRef = useRef<() => void>(() => {});
  const handleSongErrorRef = useRef<() => void>(() => {});
  const isRecoveringRef = useRef<string | null>(null);
  const retryCountRef = useRef<Record<string, number>>({});
  const playbackRequestRef = useRef<number>(0);
  const videoRequestRef = useRef<number>(0);

  // 1. Initialize HTML5 Audio instance
  useEffect(() => {
    const audio = document.createElement('audio');
    audio.preload = 'auto';
    audio.setAttribute('playsinline', 'true');
    audio.setAttribute('data-rotty-audio-engine', 'true');
    audio.setAttribute('aria-hidden', 'true');
    audio.style.position = 'fixed';
    audio.style.left = '-10000px';
    audio.style.width = '1px';
    audio.style.height = '1px';
    audio.style.opacity = '0';
    audio.style.pointerEvents = 'none';
    document.body.appendChild(audio);
    audioRef.current = audio;

    const onTimeUpdate = () => {
      setCurrentTime(audio.currentTime);
    };

    const onDurationChange = () => {
      setDuration(audio.duration || 0);
    };

    const onEnded = () => {
      handleSongEndedRef.current();
    };

    const onError = () => {
      if (audio.src && audio.src !== window.location.href && audio.src !== 'about:blank') {
        handleSongErrorRef.current();
      }
    };

    audio.addEventListener('timeupdate', onTimeUpdate);
    audio.addEventListener('durationchange', onDurationChange);
    audio.addEventListener('ended', onEnded);
    audio.addEventListener('error', onError);

    // Load volume from cache
    audio.volume = StorageService.getVolume();

    return () => {
      audio.removeEventListener('timeupdate', onTimeUpdate);
      audio.removeEventListener('durationchange', onDurationChange);
      audio.removeEventListener('ended', onEnded);
      audio.removeEventListener('error', onError);
      audio.pause();
      audio.remove();
      if (orbitIntervalRef.current) clearInterval(orbitIntervalRef.current);
    };
  }, []);

  useEffect(() => () => {
    videoAbortRef.current?.abort();
    if (activeVideoIdRef.current) releaseCachedVideoObjectUrl(activeVideoIdRef.current);
  }, []);

  useEffect(() => {
    if (audioRef.current) audioRef.current.volume = volume;
  }, [volume]);

  // Cleanup party sync watcher on unmount
  useEffect(() => {
    return () => {
      if (partyWatcherRef.current) {
        partyWatcherRef.current();
      }
    };
  }, []);

  // Background pre-fetching when approaching the end of the queue
  useEffect(() => {
    if (!isAutoplay || !currentSong || queue.length === 0 || duration <= 0) return;
    
    if (queueIndex === queue.length - 1) {
      const timeRemaining = duration - currentTime;
      if (timeRemaining < 25 && prefetchedForSongIdRef.current !== currentSong.id) {
        prefetchedForSongIdRef.current = currentSong.id;
        triggerAiRef.current();
      }
    }
  }, [currentTime, duration, isAutoplay, queueIndex, queue, currentSong]);

  // Resolve the next YouTube audio URL in the background so clicking Next is instant.
  useEffect(() => {
    const nextSong = queue[queueIndex + 1];
    if (!nextSong || nextSong.url) return;
    const isYoutube = Boolean(nextSong.source === 'youtube' || nextSong.youtubeVideoId || nextSong.id.startsWith('youtube_'));
    if (!isYoutube || prefetchedStreamForSongIdRef.current === nextSong.id) return;

    prefetchedStreamForSongIdRef.current = nextSong.id;
    MusicApi.resolveSong(nextSong)
      .then((freshSong) => {
        if (!freshSong.url) return;
        setQueue((previousQueue) => previousQueue.map((item) => item.id === freshSong.id ? freshSong : item));
        originalQueueRef.current = originalQueueRef.current.map((item) => item.id === freshSong.id ? freshSong : item);
      })
      .catch(() => {
        prefetchedStreamForSongIdRef.current = '';
      });
  }, [queue, queueIndex]);

  // Cache the next music video only when it is close enough to be useful. The
  // current video remains the single source of truth while the next one warms
  // the bounded browser cache in the background.
  useEffect(() => {
    const nextSong = queue[queueIndex + 1];
    const isNextYoutube = Boolean(nextSong && (
      nextSong.source === 'youtube' || nextSong.youtubeVideoId || nextSong.id.startsWith('youtube_')
    ));
    const secondsRemaining = duration > 0 ? duration - currentTime : Number.POSITIVE_INFINITY;
    if (!nextSong || !isNextYoutube || !isPlaying || (!isVideoMode && secondsRemaining > 30)) return;
    if (prefetchedVideoForSongIdRef.current === nextSong.id) return;

    const videoId = nextSong.youtubeVideoId || (nextSong.id.startsWith('youtube_') ? nextSong.id.slice('youtube_'.length) : '');
    if (!videoId) return;
    prefetchedVideoForSongIdRef.current = nextSong.id;
    const controller = new AbortController();
    MusicApi.resolveVideo(nextSong, controller.signal)
      .then((resolution) => prefetchCachedVideo(videoId, resolution.url, controller.signal))
      .catch(() => {
        if (!controller.signal.aborted) prefetchedVideoForSongIdRef.current = '';
      });

    return () => controller.abort();
  }, [currentTime, duration, isPlaying, isVideoMode, queue, queueIndex]);

  // 2. Initialize Web Audio API nodes (Runs on first user play interaction to comply with browser safety)
  const initWebAudio = () => {
    if (!audioRef.current || audioCtxRef.current) return;

    try {
      const AudioCtxClass = window.AudioContext || (window as any).webkitAudioContext;
      const audioCtx = new AudioCtxClass();
      audioCtxRef.current = audioCtx;

      const sourceNode = audioCtx.createMediaElementSource(audioRef.current);
      sourceNodeRef.current = sourceNode;

      // Low shelf filter for Bass Boost (Frequency = 80Hz)
      const bassFilter = audioCtx.createBiquadFilter();
      bassFilter.type = 'lowshelf';
      bassFilter.frequency.value = 80;
      bassFilter.gain.value = bassBoost;
      bassFilterRef.current = bassFilter;

      // Peaking filter for Vocal Forward (Center frequency = 2500Hz)
      const vocalFilter = audioCtx.createBiquadFilter();
      vocalFilter.type = 'peaking';
      vocalFilter.frequency.value = 2500;
      vocalFilter.Q.value = 1.0;
      vocalFilter.gain.value = vocalForward ? 6 : 0;
      vocalFilterRef.current = vocalFilter;

      // Stereo panner for 8D orbit simulation
      const pannerNode = audioCtx.createStereoPanner();
      pannerNode.pan.value = 0;
      pannerNodeRef.current = pannerNode;

      // Route nodes: Source -> Bass Filter -> Vocal Filter -> 8D Panner -> Speakers
      sourceNode.connect(bassFilter);
      bassFilter.connect(vocalFilter);
      vocalFilter.connect(pannerNode);
      pannerNode.connect(audioCtx.destination);
    } catch (e) {
      console.warn('Failed to initialize Web Audio effects node:', e);
    }
  };

  // 3. 8D Panner Orbiting Thread
  useEffect(() => {
    if (orbitIntervalRef.current) {
      clearInterval(orbitIntervalRef.current);
      orbitIntervalRef.current = null;
    }

    if (is8DActive && pannerNodeRef.current && audioCtxRef.current) {
      let pan = 0;
      let direction = 1;
      
      // Swirl sound between ears every 30ms
      orbitIntervalRef.current = window.setInterval(() => {
        pan += 0.015 * direction;
        if (pan >= 0.85) {
          pan = 0.85;
          direction = -1;
        } else if (pan <= -0.85) {
          pan = -0.85;
          direction = 1;
        }
        if (pannerNodeRef.current) {
          pannerNodeRef.current.pan.value = pan;
        }
      }, 35);
    } else {
      if (pannerNodeRef.current) {
        pannerNodeRef.current.pan.value = 0; // Center audio
      }
    }

    return () => {
      if (orbitIntervalRef.current) clearInterval(orbitIntervalRef.current);
    };
  }, [is8DActive]);

  // 4. Update filters values when states change
  useEffect(() => {
    if (bassFilterRef.current) {
      bassFilterRef.current.gain.value = bassBoost;
    }
  }, [bassBoost]);

  useEffect(() => {
    if (vocalFilterRef.current) {
      vocalFilterRef.current.gain.value = vocalForward ? 6 : 0;
    }
  }, [vocalForward]);

  // 5. Browser Media Session API Integration for system media controls
  useEffect(() => {
    if (!currentSong || !navigator.mediaSession) return;

    navigator.mediaSession.metadata = new MediaMetadata({
      title: currentSong.title,
      artist: currentSong.artist,
      album: currentSong.album,
      artwork: [
        { src: currentSong.image, sizes: '500x500', type: 'image/jpeg' }
      ]
    });

    navigator.mediaSession.setActionHandler('play', () => togglePlayHandlerRef.current());
    navigator.mediaSession.setActionHandler('pause', () => togglePlayHandlerRef.current());
    navigator.mediaSession.setActionHandler('nexttrack', () => nextSongHandlerRef.current());
    navigator.mediaSession.setActionHandler('previoustrack', () => prevSongHandlerRef.current());
    navigator.mediaSession.setActionHandler('seekto', (details) => {
      if (details.seekTime !== undefined) seekHandlerRef.current(details.seekTime);
    });

    return () => {
      if (navigator.mediaSession) {
        navigator.mediaSession.setActionHandler('play', null);
        navigator.mediaSession.setActionHandler('pause', null);
        navigator.mediaSession.setActionHandler('nexttrack', null);
        navigator.mediaSession.setActionHandler('previoustrack', null);
      }
    };
  }, [currentSong, queueIndex, queue]);

  // 6. Playback triggers
  const isYoutubeSong = (song: Song) => Boolean(
    song.source === 'youtube' || song.youtubeVideoId || song.id.startsWith('youtube_')
  );

  const getYoutubeVideoId = (song: Song): string => song.youtubeVideoId
    || (song.id.startsWith('youtube_') ? song.id.slice('youtube_'.length) : '');

  const clearVideoState = () => {
    videoRequestRef.current += 1;
    videoAbortRef.current?.abort();
    videoAbortRef.current = null;
    if (activeVideoIdRef.current) releaseCachedVideoObjectUrl(activeVideoIdRef.current);
    activeVideoIdRef.current = null;
    setVideoUrl(null);
    setIsVideoMode(false);
    setIsResolvingVideo(false);
  };

  const cacheCurrentVideo = async (song: Song, force = false): Promise<void> => {
    const videoId = getYoutubeVideoId(song);
    if (!videoId) throw new Error('missing_video_id');

    videoAbortRef.current?.abort();
    const controller = new AbortController();
    videoAbortRef.current = controller;
    const requestId = ++videoRequestRef.current;
    setIsResolvingVideo(true);

    try {
      const resolution = await MusicApi.resolveVideo(song, controller.signal, force);
      const objectUrl = await getCachedVideoObjectUrl(videoId, resolution.url, controller.signal);
      if (requestId !== videoRequestRef.current || controller.signal.aborted) {
        releaseCachedVideoObjectUrl(videoId);
        return;
      }
      if (activeVideoIdRef.current && activeVideoIdRef.current !== videoId) {
        releaseCachedVideoObjectUrl(activeVideoIdRef.current);
      }
      activeVideoIdRef.current = videoId;
      setVideoUrl(objectUrl);
      setIsVideoMode(true);
    } finally {
      if (requestId === videoRequestRef.current) setIsResolvingVideo(false);
    }
  };

  const onYoutubeVideoError = () => {
    if (!currentSong || !isYoutubeSong(currentSong)) return;
    const videoId = getYoutubeVideoId(currentSong);
    if (!videoId) return;
    void invalidateCachedVideo(videoId)
      .catch(() => undefined)
      .finally(() => {
        void cacheCurrentVideo(currentSong, true).catch(() => {
          if (videoRequestRef.current > 0) setIsVideoMode(false);
        });
      });
  };

  const playSong = (song: Song, customQueue?: Song[]) => {
    if (!audioRef.current) return;
    const requestId = ++playbackRequestRef.current;

    // Lazy load Web Audio Nodes
    if (!isYoutubeSong(song)) initWebAudio();
    if (audioCtxRef.current?.state === 'suspended') {
      audioCtxRef.current.resume();
    }

    // Synchronously play & pause to unlock HTML5 Audio in browsers (prevents async click-to-play blocking)
    if (audioRef.current && (song.id.startsWith('spotify_track_') || !song.url)) {
      audioRef.current.play().catch(() => {});
      audioRef.current.pause();
    }

    let activeQueue: Song[] = [];
    let index = -1;

    if (customQueue) {
      activeQueue = [...customQueue];
      originalQueueRef.current = [...customQueue];
      setQueue(activeQueue);
      index = activeQueue.findIndex((s) => s.id === song.id);
    } else {
      // If no custom queue is passed, check if the song is already in the current queue
      const existingIdx = queue.findIndex((s) => s.id === song.id);
      if (existingIdx !== -1) {
        // Jump to the existing song in the current queue
        activeQueue = queue;
        index = existingIdx;
      } else {
        // Reset the queue to just this song, letting the AI DJ build a cohesive queue around it!
        activeQueue = [song];
        originalQueueRef.current = [song];
        setQueue(activeQueue);
        index = 0;
      }
    }

    if (index === -1) {
      // Fallback if the song was not found in the customQueue
      activeQueue = [song, ...activeQueue];
      originalQueueRef.current = [song, ...originalQueueRef.current];
      setQueue(activeQueue);
      index = 0;
    }

    const startPlayback = (targetSong: Song) => {
      if (isYoutubeSong(targetSong) && !targetSong.url) {
        setIsPlaying(false);
        return;
      }
      clearVideoState();
      setYoutubeVideoId(isYoutubeSong(targetSong) ? getYoutubeVideoId(targetSong) || null : null);
      setCurrentSong(targetSong);
      setQueueIndex(index);

      if (audioRef.current) {
        audioRef.current.src = targetSong.url;
        audioRef.current.load();
        audioRef.current.play()
          .then(() => {
            setIsPlaying(true);
            delete retryCountRef.current[targetSong.id];
            isRecoveringRef.current = null;
            StorageService.addRecentSong(targetSong);
            StorageService.recordStreakDay();

            // Sync party room playback if host
            if (partyCode && isPartyHost && !isSyncingFromPartyRef.current) {
              SupabaseService.updatePartyPlayback(partyCode, targetSong, true);
            }
          })
          .catch((err) => {
            console.warn('Playback trigger blocked or source error, attempting auto-recovery:', err);
            handleSongErrorRef.current();
          });
      }
    };

    if (isYoutubeSong(song)) {
      setIsPlaying(false);
      MusicApi.resolveSong(song)
        .then((freshSong) => {
          if (requestId !== playbackRequestRef.current) return;
          if (freshSong.url) {
            setQueue((previousQueue) => previousQueue.map((item) => item.id === song.id ? freshSong : item));
            startPlayback(freshSong);
          } else setIsPlaying(false);
        })
        .catch(() => {
          if (requestId !== playbackRequestRef.current) return;
          MusicApi.resolveSong({ ...song, url: '' })
            .then((retrySong) => {
              if (requestId !== playbackRequestRef.current || !retrySong.url) {
                setIsPlaying(false);
                return;
              }
              setQueue((previousQueue) => previousQueue.map((item) => item.id === song.id ? retrySong : item));
              startPlayback(retrySong);
            })
            .catch(() => setIsPlaying(false));
        });
    } else if (song.id.startsWith('spotify_track_') || !song.url) {
      // Fetch details immediately (resolving Spotify tracks if necessary)
      MusicApi.resolveSong(song).then((freshSong) => {
        if (requestId !== playbackRequestRef.current) return;
        if (freshSong && freshSong.url) {
          // Update queue state with resolved URL
          setQueue((prevQueue) => {
            const qIdx = prevQueue.findIndex((s) => s.id === song.id);
            if (qIdx !== -1) {
              const updated = [...prevQueue];
              updated[qIdx] = freshSong;
              return updated;
            }
            return prevQueue;
          });
          startPlayback(freshSong);
        } else {
          console.error('Could not resolve url for song:', song.id);
          setIsPlaying(false);
          nextSong();
        }
      }).catch((error) => {
        console.warn('[AudioContext] Native stream resolution failed:', error);
        setIsPlaying(false);
      });
    } else {
      startPlayback(song);
    }
  };

  const togglePlay = () => {
    if (isSyncControlled) {
      const nextPlaying = syncPlaybackState ? !syncPlaybackState.isPlaying : true;
      RottyConnectService.sendCommand(nextPlaying ? 'play' : 'pause');
      return;
    }

    if (!audioRef.current || !currentSong) return;

    if (audioCtxRef.current?.state === 'suspended') {
      audioCtxRef.current.resume();
    }

    if (isPlaying) {
      audioRef.current.pause();
      setIsPlaying(false);
      
      if (partyCode && isPartyHost && !isSyncingFromPartyRef.current) {
        SupabaseService.updatePartyPlayback(partyCode, currentSong, false);
      }
    } else {
      audioRef.current.play()
        .then(() => {
          setIsPlaying(true);
          if (partyCode && isPartyHost && !isSyncingFromPartyRef.current) {
            SupabaseService.updatePartyPlayback(partyCode, currentSong, true);
          }
        })
        .catch(() => setIsPlaying(false));
    }
  };

  // Autoplay Queue Refill logic (Spotify-like vibe matching)
  const handleAutoplayRefill = async (currentQueue: Song[], currentIndex: number) => {
    const songToMatch = currentSong || (currentQueue.length > 0 ? currentQueue[currentQueue.length - 1] : null);
    if (!songToMatch) {
      setIsPlaying(false);
      setCurrentTime(0);
      return;
    }

    try {
      console.log('[Autoplay] Refilling queue based on vibe seed:', songToMatch.title);
      
      // 1. Fetch suggestions for seed song
      const primaryRecs = await MusicApi.getRecommendations(songToMatch.id, songToMatch, 10);
      
      // 2. Fetch suggestions for a random recently played song to personalize the experience
      let personalizedRecs: Song[] = [];
      const recents = StorageService.getRecentSongs().filter(s => s.id !== songToMatch.id);
      if (recents.length > 0) {
        const randomSeed = recents[Math.floor(Math.random() * Math.min(5, recents.length))];
        personalizedRecs = await MusicApi.getRecommendations(randomSeed.id, randomSeed, 6);
      }

      // 3. Interleave/Blend recommendations
      const combined = [...primaryRecs];
      for (let i = 0; i < personalizedRecs.length; i++) {
        const targetIndex = Math.min(combined.length, (i * 2) + 1);
        combined.splice(targetIndex, 0, personalizedRecs[i]);
      }

      // 4. Filter duplicates (already in queue or currently playing)
      const existingIds = new Set(currentQueue.map(s => s.id));
      if (currentSong) existingIds.add(currentSong.id);
      
      const existingFingerprints = new Set(currentQueue.map(getSongFingerprint));
      if (currentSong) existingFingerprints.add(getSongFingerprint(currentSong));

      const isFilterOk = (s: Song) => {
        if (!s || !s.id) return false;
        if (existingIds.has(s.id)) return false;
        const fp = getSongFingerprint(s);
        if (!fp || existingFingerprints.has(fp)) return false;
        
        // Add to seen sets dynamically to filter subsequent duplicates in the same batch
        existingIds.add(s.id);
        existingFingerprints.add(fp);
        return true;
      };

      let newSongs = combined.filter(isFilterOk);

      // 5. Robust multi-level fallback if suggestions are empty or blocked
      if (newSongs.length === 0) {
        console.log('[Autoplay] handleAutoplayRefill empty. Executing robust fallbacks...');
        const fallbackQuery = getLanguageFallbackQuery(songToMatch, false);
        const fallbackSongs = await MusicApi.searchSongs(fallbackQuery, 12);
        newSongs = fallbackSongs.filter(isFilterOk);
        
        if (newSongs.length === 0) {
          const secondaryQuery = getLanguageFallbackQuery(songToMatch, true);
          const trendingSongs = await MusicApi.searchSongs(secondaryQuery, 12);
          newSongs = trendingSongs.filter(isFilterOk);
        }
      }

      if (newSongs.length > 0) {
        const updatedQueue = [...currentQueue, ...newSongs];
        setQueue(updatedQueue);
        originalQueueRef.current = [...originalQueueRef.current, ...newSongs];
        
        // Push updated queue to Party Sync if Host
        if (partyCode && isPartyHost) {
          SupabaseService.pushPartyQueue(partyCode, updatedQueue);
        }

        const nextIndex = currentIndex + 1;
        if (nextIndex < updatedQueue.length) {
          playSong(updatedQueue[nextIndex], updatedQueue);
        } else {
          setIsPlaying(false);
        }
      } else {
        setIsPlaying(false);
        setCurrentTime(0);
      }
    } catch (e) {
      console.error('[Autoplay] Refill failed:', e);
      setIsPlaying(false);
      setCurrentTime(0);
    }
  };

  const triggerAiRefill = async () => {
    const songToMatch = currentSong || (queue.length > 0 ? queue[queue.length - 1] : null);
    if (!songToMatch) return;
    try {
      console.log('[Autoplay] Pre-fetching recommendations in background...');
      const primaryRecs = await MusicApi.getRecommendations(songToMatch.id, songToMatch, 10);
      
      let personalizedRecs: Song[] = [];
      const recents = StorageService.getRecentSongs().filter(s => s.id !== songToMatch.id);
      if (recents.length > 0) {
        const randomSeed = recents[Math.floor(Math.random() * Math.min(5, recents.length))];
        personalizedRecs = await MusicApi.getRecommendations(randomSeed.id, randomSeed, 6);
      }

      const combined = [...primaryRecs];
      for (let i = 0; i < personalizedRecs.length; i++) {
        const targetIndex = Math.min(combined.length, (i * 2) + 1);
        combined.splice(targetIndex, 0, personalizedRecs[i]);
      }

      const existingIds = new Set(queue.map(s => s.id));
      if (currentSong) existingIds.add(currentSong.id);
      
      const existingFingerprints = new Set(queue.map(getSongFingerprint));
      if (currentSong) existingFingerprints.add(getSongFingerprint(currentSong));

      const isFilterOk = (s: Song) => {
        if (!s || !s.id) return false;
        if (existingIds.has(s.id)) return false;
        const fp = getSongFingerprint(s);
        if (!fp || existingFingerprints.has(fp)) return false;
        
        // Add to seen sets dynamically to filter subsequent duplicates in the same batch
        existingIds.add(s.id);
        existingFingerprints.add(fp);
        return true;
      };

      let newSongs = combined.filter(isFilterOk);

      // Robust multi-level fallback if background recommendations are empty
      if (newSongs.length === 0) {
        console.log('[Autoplay] triggerAiRefill empty. Executing robust fallbacks...');
        const fallbackQuery = getLanguageFallbackQuery(songToMatch, false);
        const fallbackSongs = await MusicApi.searchSongs(fallbackQuery, 12);
        newSongs = fallbackSongs.filter(isFilterOk);
        
        if (newSongs.length === 0) {
          const secondaryQuery = getLanguageFallbackQuery(songToMatch, true);
          const trendingSongs = await MusicApi.searchSongs(secondaryQuery, 12);
          newSongs = trendingSongs.filter(isFilterOk);
        }
      }

      if (newSongs.length > 0) {
        setQueue(prev => {
          const updated = [...prev, ...newSongs];
          originalQueueRef.current = [...originalQueueRef.current, ...newSongs];
          if (partyCode && isPartyHost) {
            SupabaseService.pushPartyQueue(partyCode, updated);
          }
          return updated;
        });
      }
    } catch (e) {
      console.error('[Autoplay] Background pre-fetch failed:', e);
    }
  };

  const nextSong = () => {
    if (isSyncControlled) {
      RottyConnectService.sendCommand('next');
      return;
    }

    if (queue.length === 0) return;
    let nextIndex = queueIndex + 1;
    
    if (nextIndex >= queue.length) {
      if (isLoop === 'all') {
        nextIndex = 0;
      } else if (isAutoplay) {
        handleAutoplayRefill(queue, queueIndex);
        return;
      } else {
        nextIndex = -1;
      }
    }
    
    if (nextIndex >= 0) {
      playSong(queue[nextIndex]);
    } else {
      setIsPlaying(false);
      setCurrentTime(0);
      if (audioRef.current) audioRef.current.currentTime = 0;
      if (partyCode && isPartyHost) {
        SupabaseService.updatePartyPlayback(partyCode, null, false);
      }
    }
  };

  const prevSong = () => {
    if (isSyncControlled) {
      RottyConnectService.sendCommand('prev');
      return;
    }

    if (queue.length === 0) return;
    
    // Restart song if it has played more than 3 seconds
    if (currentTime > 3) {
      seek(0);
      return;
    }

    let prevIndex = queueIndex - 1;
    if (prevIndex < 0) {
      prevIndex = isLoop === 'all' ? queue.length - 1 : 0;
    }

    playSong(queue[prevIndex]);
  };

  const seek = (time: number) => {
    if (isSyncControlled) {
      RottyConnectService.sendCommand('seekTo', Math.floor(time));
      return;
    }

    const safeTime = Math.max(0, Number.isFinite(time) ? time : 0);
    if (!audioRef.current) return;
    audioRef.current.currentTime = safeTime;
    setCurrentTime(safeTime);
  };

  useEffect(() => {
    triggerAiRef.current = triggerAiRefill;
  }, [triggerAiRefill]);

  const setVolume = (vol: number) => {
    if (isSyncControlled) {
      RottyConnectService.sendCommand('volume', Math.floor(vol * 100));
      setVolumeState(vol);
      return;
    }

    const safeVol = Math.max(0, Math.min(1, vol));
    if (audioRef.current) {
      audioRef.current.volume = safeVol;
    }
    setVolumeState(safeVol);
    StorageService.setVolume(safeVol);
  };

  useEffect(() => {
    togglePlayHandlerRef.current = togglePlay;
    nextSongHandlerRef.current = nextSong;
    prevSongHandlerRef.current = prevSong;
    seekHandlerRef.current = seek;
  }, [nextSong, prevSong, seek, togglePlay]);

  const toggleVideoMode = () => {
    if (!currentSong || !isYoutubeSong(currentSong)) return;
    if (isResolvingVideo) return;
    if (isVideoMode) {
      setIsVideoMode(false);
      return;
    }

    if (videoUrl) {
      setIsVideoMode(true);
      return;
    }

    void cacheCurrentVideo(currentSong).catch(() => setIsVideoMode(false));
  };

  const toggleShuffle = () => {
    if (isShuffle) {
      // Restore original queue order
      const current = currentSong;
      setQueue(originalQueueRef.current);
      if (current) {
        setQueueIndex(originalQueueRef.current.findIndex((s) => s.id === current.id));
      }
      setIsShuffle(false);
    } else {
      // Shuffle queue
      if (queue.length > 0) {
        const shuffled = [...queue];
        const current = currentSong;
        
        // Fisher-Yates shuffle
        for (let i = shuffled.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
        }

        // Put currently playing song at index 0 of the shuffled queue
        if (current) {
          const cIndex = shuffled.findIndex((s) => s.id === current.id);
          if (cIndex !== -1) {
            shuffled.splice(cIndex, 1);
            shuffled.unshift(current);
          }
        }

        setQueue(shuffled);
        setQueueIndex(0);
      }
      setIsShuffle(true);
    }
  };

  const toggleLoop = () => {
    setIsLoop((prev) => {
      if (prev === 'none') return 'all';
      if (prev === 'all') return 'one';
      return 'none';
    });
  };

  const handleSongEnded = () => {
    if (isLoop === 'one') {
      if (audioRef.current) {
        audioRef.current.currentTime = 0;
        audioRef.current.play()
          .then(() => setIsPlaying(true))
          .catch(() => setIsPlaying(false));
      }
    } else {
      nextSong();
    }
  };

  const handleSongError = () => {
    if (!currentSong) return;
    const songId = currentSong.id;

    if (isRecoveringRef.current === songId) {
      return; // Already recovering this song
    }
    
    const retries = retryCountRef.current[songId] || 0;
    if (retries >= 2) {
      console.warn(`[AudioContext] Playback paused after recovery attempts for ${currentSong.title}. User can retry or skip manually.`);
      isRecoveringRef.current = null;
      setIsPlaying(false);
      return;
    }
    
    isRecoveringRef.current = songId;
    retryCountRef.current[songId] = retries + 1;
    console.log(`[AudioContext] Playback failed for ${currentSong.title}. Attempting auto-recovery with fresh URL...`);
    
    MusicApi.resolveSong({ ...currentSong, url: '' }, undefined, true).then((freshSong) => {
      isRecoveringRef.current = null;
      if (freshSong && freshSong.url) {
        // Update queue state with resolved URL
        setQueue((prevQueue) => {
          const qIdx = prevQueue.findIndex((s) => s.id === songId);
          if (qIdx !== -1) {
            const updated = [...prevQueue];
            updated[qIdx] = freshSong;
            return updated;
          }
          return prevQueue;
        });
        
        setCurrentSong(freshSong);
        if (audioRef.current) {
          audioRef.current.src = freshSong.url;
          audioRef.current.load();
          audioRef.current.play()
            .then(() => {
              setIsPlaying(true);
              delete retryCountRef.current[songId];
            })
          .catch((err) => {
              console.error('[AudioContext] Auto-recovery playback failed on retry:', err);
              setIsPlaying(false);
            });
        }
      } else {
        setIsPlaying(false);
      }
    }).catch(() => {
      isRecoveringRef.current = null;
      setIsPlaying(false);
    });
  };

  useEffect(() => {
    handleSongEndedRef.current = handleSongEnded;
    handleSongErrorRef.current = handleSongError;
  }, [handleSongEnded, handleSongError]);

  const setBassBoost = (boost: number) => {
    setBassBoostState(boost);
  };

  const setVocalForward = (active: boolean) => {
    setVocalForwardState(active);
  };

  const set8DActive = (active: boolean) => {
    set8DActiveState(active);
  };

  // Party Sync operations
  const createPartyRoom = async (): Promise<string> => {
    const uid = localStorage.getItem('rotty_user_uid') || 'guest_' + Math.random().toString(36).substring(7);
    const name = StorageService.getProfileName() || 'Guest';
    try {
      const code = await SupabaseService.createPartyRoom(uid, name);
      setPartyCode(code);
      setIsPartyHost(true);
      
      if (partyWatcherRef.current) partyWatcherRef.current();
      partyWatcherRef.current = SupabaseService.watchPartyRoom(code, (roomState) => {
        setPartyRoom(roomState);
      });
      
      return code;
    } catch (e) {
      console.error('Failed to create party room:', e);
      throw e;
    }
  };

  const joinPartyRoom = async (code: string): Promise<void> => {
    const uid = localStorage.getItem('rotty_user_uid') || 'guest_' + Math.random().toString(36).substring(7);
    const name = StorageService.getProfileName() || 'Guest';
    try {
      await SupabaseService.joinPartyRoom(code, uid, name);
      setPartyCode(code);
      setIsPartyHost(false);

      if (partyWatcherRef.current) partyWatcherRef.current();
      partyWatcherRef.current = SupabaseService.watchPartyRoom(code, (roomState) => {
        if (!roomState) return;
        setPartyRoom(roomState);

        isSyncingFromPartyRef.current = true;
        
        if (roomState.queue) {
          setQueue(roomState.queue);
          originalQueueRef.current = roomState.queue;
        }

        if (roomState.nowPlaying) {
          if (!currentSong || currentSong.id !== roomState.nowPlaying.id) {
            playSong(roomState.nowPlaying, roomState.queue);
          }
        }

        if (audioRef.current) {
          if (roomState.isPlaying && audioRef.current.paused) {
            audioRef.current.play().then(() => setIsPlaying(true)).catch(() => {});
          } else if (!roomState.isPlaying && !audioRef.current.paused) {
            audioRef.current.pause();
            setIsPlaying(false);
          }
        }

        isSyncingFromPartyRef.current = false;
      });
    } catch (e) {
      console.error('Failed to join party room:', e);
      throw e;
    }
  };

  const leavePartyRoom = async (): Promise<void> => {
    if (!partyCode) return;
    const uid = localStorage.getItem('rotty_user_uid') || '';
    try {
      if (partyWatcherRef.current) {
        partyWatcherRef.current();
        partyWatcherRef.current = null;
      }
      await SupabaseService.leavePartyRoom(partyCode, uid);
      setPartyCode(null);
      setPartyRoom(null);
      setIsPartyHost(false);
    } catch (e) {
      console.error('Failed to leave party room:', e);
    }
  };

  const kickPartyMember = async (uid: string): Promise<void> => {
    if (!partyCode || !isPartyHost) return;
    try {
      await SupabaseService.kickMember(partyCode, uid);
    } catch (e) {
      console.error('Failed to kick member:', e);
    }
  };

  const addToQueue = (song: Song) => {
    if (partyCode && !isPartyHost) return;
    const targetFp = getSongFingerprint(song);
    if (queue.some((s) => s.id === song.id || getSongFingerprint(s) === targetFp)) return;
    const updated = [...queue, song];
    setQueue(updated);
    originalQueueRef.current.push(song);
    
    if (partyCode && isPartyHost) {
      SupabaseService.pushPartyQueue(partyCode, updated);
    }
  };

  const playNext = (song: Song) => {
    if (partyCode && !isPartyHost) return;
    
    const targetFp = getSongFingerprint(song);
    // Filter out the song from current queue if it exists (by ID or fingerprint)
    const filteredQueue = queue.filter((s) => s.id !== song.id && getSongFingerprint(s) !== targetFp);
    
    // Determine target index (right after the currently playing song)
    let currentIdx = currentSong ? filteredQueue.findIndex((s) => s.id === currentSong.id) : queueIndex;
    if (currentIdx === -1 && currentSong) {
      currentIdx = queueIndex;
    }
    
    const insertIdx = Math.max(0, currentIdx + 1);
    const updated = [...filteredQueue];
    updated.splice(insertIdx, 0, song);
    
    setQueue(updated);
    if (currentSong) {
      setQueueIndex(currentIdx);
    }
    
    // Update original queue too
    originalQueueRef.current = originalQueueRef.current.filter((s) => s.id !== song.id && getSongFingerprint(s) !== targetFp);
    const origInsertIdx = currentSong ? originalQueueRef.current.findIndex((s) => s.id === currentSong.id) + 1 : originalQueueRef.current.length;
    originalQueueRef.current.splice(origInsertIdx, 0, song);
    
    if (partyCode && isPartyHost) {
      SupabaseService.pushPartyQueue(partyCode, updated);
    }
  };

  const removeFromQueue = (songId: string) => {
    if (partyCode && !isPartyHost) return;
    const updated = queue.filter((s) => s.id !== songId);
    setQueue(updated);
    originalQueueRef.current = originalQueueRef.current.filter((s) => s.id !== songId);
    
    if (partyCode && isPartyHost) {
      SupabaseService.pushPartyQueue(partyCode, updated);
    }

    if (currentSong?.id === songId) {
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current.src = '';
      }
      setCurrentSong(null);
      setYoutubeVideoId(null);
      setVideoUrl(null);
      setIsVideoMode(false);
      setIsPlaying(false);
      setQueueIndex(-1);
      
      if (partyCode && isPartyHost) {
        SupabaseService.updatePartyPlayback(partyCode, null, false);
      }
    } else if (currentSong) {
      setQueueIndex(updated.findIndex((s) => s.id === currentSong.id));
    }
  };

  const clearQueue = () => {
    if (partyCode && !isPartyHost) return;
    setQueue([]);
    originalQueueRef.current = [];
    setQueueIndex(-1);
    setCurrentSong(null);
    setYoutubeVideoId(null);
    setVideoUrl(null);
    setIsVideoMode(false);
    setIsPlaying(false);
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = '';
    }
    if (partyCode && isPartyHost) {
      SupabaseService.pushPartyQueue(partyCode, []);
      SupabaseService.updatePartyPlayback(partyCode, null, false);
    }
  };

  const moveQueueItem = (fromIndex: number, toIndex: number) => {
    if (partyCode && !isPartyHost) return;
    if (fromIndex < 0 || fromIndex >= queue.length || toIndex < 0 || toIndex >= queue.length) return;
    const updated = [...queue];
    const [moved] = updated.splice(fromIndex, 1);
    updated.splice(toIndex, 0, moved);
    setQueue(updated);
    
    if (partyCode && isPartyHost) {
      SupabaseService.pushPartyQueue(partyCode, updated);
    }

    if (currentSong) {
      setQueueIndex(updated.findIndex((s) => s.id === currentSong.id));
    }
  };

  const toggleAutoplay = () => {
    setIsAutoplay(prev => {
      const next = !prev;
      localStorage.setItem('rotty_autoplay', String(next));
      return next;
    });
  };

  const refreshSyncDevices = async () => {
    if (!RottyConnectService.userId) return;
    const devices = await RottyConnectService.getDevices();
    setSyncDevices(devices);
  };

  // Effect: Heartbeat & Command listener initialization
  useEffect(() => {
    const uid = localStorage.getItem('rotty_user_uid');
    if (uid) {
      RottyConnectService.init(uid).then(() => {
        RottyConnectService.listenForCommands((action, value) => {
          console.log('[RottyConnect] Received remote command:', action, value);
          switch (action) {
            case 'play':
              if (!isPlaying && audioRef.current && currentSong) {
                audioRef.current.play()
                  .then(() => setIsPlaying(true))
                  .catch(() => setIsPlaying(false));
              }
              break;
            case 'pause':
              if (isPlaying && audioRef.current) {
                audioRef.current.pause();
                setIsPlaying(false);
              }
              break;
            case 'next':
              nextSong();
              break;
            case 'prev':
              prevSong();
              break;
            case 'seekTo':
              if (value !== undefined) seek(value);
              break;
            case 'volume':
              if (value !== undefined) setVolume(value / 100);
              break;
          }
        });
      });
    }

    return () => {
      RottyConnectService.dispose();
    };
  }, [currentSong, isPlaying]);

  // Effect: Continuous playback sync updater
  useEffect(() => {
    if (isSyncControlled || !RottyConnectService.userId) return;
    
    const lastUpdate = { time: 0, songId: '' };
    
    const syncInterval = setInterval(() => {
      const now = Date.now();
      const songId = currentSong ? currentSong.id : '';
      
      const shouldUpdate = 
        songId !== lastUpdate.songId || 
        Math.abs(now - lastUpdate.time) > 8000;
        
      if (shouldUpdate) {
        RottyConnectService.updatePlayback(currentSong, isPlaying, currentTime);
        lastUpdate.time = now;
        lastUpdate.songId = songId;
      }
    }, 2000);

    return () => clearInterval(syncInterval);
  }, [currentSong, isPlaying, currentTime, isSyncControlled]);

  // Effect: Poll remote playback state when sync controlled
  useEffect(() => {
    if (!isSyncControlled || !RottyConnectService.userId) {
      setSyncPlaybackState(null);
      return;
    }

    const syncPollInterval = setInterval(async () => {
      const state = await RottyConnectService.watchPlayback();
      setSyncPlaybackState(state);
    }, 2000);

    return () => clearInterval(syncPollInterval);
  }, [isSyncControlled]);

  return (
    <AudioContext.Provider
      value={{
        currentSong,
        isPlaying,
        currentTime,
        duration,
        volume,
        youtubeVideoId,
        videoUrl,
        isVideoMode,
        isResolvingVideo,
        toggleVideoMode,
        onYoutubeVideoError,
        queue,
        queueIndex,
        isShuffle,
        isLoop,
        bassBoost,
        vocalForward,
        is8DActive,
        isAutoplay,
        toggleAutoplay,
        triggerAiRefill,
        isSyncControlled,
        setIsSyncControlled,
        syncPlaybackState,
        syncDevices,
        refreshSyncDevices,
        
        // Party Sync
        partyCode,
        partyRoom,
        isPartyHost,
        createPartyRoom,
        joinPartyRoom,
        leavePartyRoom,
        kickPartyMember,

        playSong,
        togglePlay,
        nextSong,
        prevSong,
        seek,
        setVolume,
        toggleShuffle,
        toggleLoop,
        setBassBoost,
        setVocalForward,
        set8DActive,
        addToQueue,
        playNext,
        removeFromQueue,
        clearQueue,
        moveQueueItem
      }}
    >
      {children}
    </AudioContext.Provider>
  );
};

export const useAudio = () => {
  const context = useContext(AudioContext);
  if (!context) {
    throw new Error('useAudio must be used within an AudioProvider');
  }
  return context;
};
