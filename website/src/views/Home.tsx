import React, { useEffect, useState } from 'react';
import { MusicApi } from '../services/api';
import type { Song } from '../services/api';
import { useAudio } from '../context/AudioContext';
import { StorageService } from '../services/storage';
import { SongRow } from '../components/SongRow';
import { SongOptionsMenu } from '../components/SongOptionsMenu';
import { 
  Play, Pause, Search, Flame, Sparkles, ChevronRight, 
  Moon, Mic, FlaskConical, BarChart2, Car, X, Disc, 
  CloudRain, Coffee, Wind, ShieldAlert, Music, MoreVertical
} from 'lucide-react';

interface HomeProps {
  setActiveTab: (index: number) => void;
}

interface Station {
  name: string;
  query: string;
  color: string;
}

export const Home: React.FC<HomeProps> = ({ setActiveTab }) => {
  const { playSong, isPlaying, togglePlay, currentSong, isAutoplay, toggleAutoplay } = useAudio();

  // Component state
  const [sections, setSections] = useState<Record<string, Song[]>>({});
  const [recentSongs, setRecentSongs] = useState<Song[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  
  // Storage profile state
  const [profileName, setProfileName] = useState<string>('');
  const [isSupporter, setIsSupporter] = useState<boolean>(false);
  const [streakCount, setStreakCount] = useState<number>(0);
  const [hasListenedToday, setHasListenedToday] = useState<boolean>(false);

  // Overlay panels state
  const [selectedStation, setSelectedStation] = useState<Station | null>(null);
  const [stationSongs, setStationSongs] = useState<Song[]>([]);
  const [stationLoading, setStationLoading] = useState<boolean>(false);

  const [activeModal, setActiveModal] = useState<'scenes' | 'concert' | 'wrapped' | 'drive' | null>(null);
  const [modalSongs, setModalSongs] = useState<Song[]>([]);
  const [modalLoading, setModalLoading] = useState<boolean>(false);
  const [isMobile, setIsMobile] = useState<boolean>(window.innerWidth <= 768);

  // Resize listener
  useEffect(() => {
    const handleResize = () => setIsMobile(window.innerWidth <= 768);
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // 1. Load home API feeds ONCE on mount
  useEffect(() => {
    MusicApi.getHomeSections()
      .then((data) => {
        setSections(data);
      })
      .catch((err) => {
        console.error('Failed to load home sections:', err);
      })
      .finally(() => {
        setLoading(false);
      });
  }, []);

  // 2. Load profile and local history on mount, currentSong change, & library updates
  useEffect(() => {
    const handleUpdate = () => {
      setProfileName(StorageService.getProfileName());
      setIsSupporter(StorageService.isSupporter());
      setStreakCount(StorageService.getStreakCount());
      setHasListenedToday(StorageService.hasListenedToday());
      setRecentSongs(StorageService.getRecentSongs());
    };
    handleUpdate();
    window.addEventListener('library-update', handleUpdate);
    return () => window.removeEventListener('library-update', handleUpdate);
  }, [currentSong]);

  const getTimeGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  };

  // Switch to search query for Quick Actions or Genres
  const handleOpenStation = async (station: Station) => {
    setSelectedStation(station);
    setStationLoading(true);
    setStationSongs([]);
    try {
      const results = await MusicApi.searchSongs(station.query, 25);
      setStationSongs(results);
    } catch (e) {
      console.error(e);
    } finally {
      setStationLoading(false);
    }
  };

  // Switch to scene/concert queries
  const handleOpenModal = async (type: 'scenes' | 'concert' | 'wrapped' | 'drive') => {
    setActiveModal(type);
    if (type === 'scenes') {
      // Load standard rain sound by default
      setModalLoading(true);
      try {
        const results = await MusicApi.searchSongs('Rain Sound Sleep', 15);
        setModalSongs(results);
      } catch (e) {
        console.error(e);
      } finally {
        setModalLoading(false);
      }
    } else if (type === 'concert') {
      setModalLoading(true);
      try {
        const results = await MusicApi.searchSongs('Arijit Singh live concert hits', 20);
        setModalSongs(results);
      } catch (e) {
        console.error(e);
      } finally {
        setModalLoading(false);
      }
    }
  };

  const handleSelectScene = async (query: string) => {
    setModalLoading(true);
    try {
      const results = await MusicApi.searchSongs(query, 15);
      setModalSongs(results);
    } catch (e) {
      console.error(e);
    } finally {
      setModalLoading(false);
    }
  };

  if (loading) {
    const SkeletonBlock: React.FC<{ width: string; height: string; borderRadius?: string }> = ({ width, height, borderRadius = '8px' }) => (
      <div 
        className="shimmer-box" 
        style={{ 
          width, 
          height, 
          borderRadius, 
          background: 'rgba(255, 255, 255, 0.02)', 
          border: '1px solid rgba(255, 255, 255, 0.04)' 
        }} 
      />
    );

    return (
      <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflowY: 'hidden', paddingBottom: '32px', gap: '24px' }}>
        {/* 1. Header Skeleton */}
        <div style={{ display: 'flex', alignItems: 'center', padding: '24px 24px 8px 24px', gap: '16px' }}>
          <SkeletonBlock width="44px" height="44px" borderRadius="12px" />
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', flex: 1 }}>
            <SkeletonBlock width="140px" height="12px" />
            <SkeletonBlock width="200px" height="28px" borderRadius="6px" />
          </div>
        </div>

        {/* 2. Search Bar Skeleton */}
        <div style={{ padding: '0 24px' }}>
          <SkeletonBlock width="100%" height="48px" borderRadius="14px" />
        </div>

        {/* 3. Quick Actions Skeleton */}
        <div style={{ display: 'flex', gap: '10px', padding: '0 24px' }}>
          {[1, 2, 3, 4, 5].map((i) => (
            <SkeletonBlock key={i} width="88px" height="76px" borderRadius="14px" />
          ))}
        </div>

        {/* 4. Mood/Genres Grid Skeleton */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', padding: '0 24px' }}>
          <SkeletonBlock width="120px" height="18px" />
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(130px, 1fr))', gap: '10px' }}>
            {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => (
              <SkeletonBlock key={i} width="100%" height="56px" borderRadius="12px" />
            ))}
          </div>
        </div>

        {/* 5. Horizontal Cards Section Skeleton */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', padding: '0 24px' }}>
          <SkeletonBlock width="180px" height="18px" />
          <div style={{ display: 'flex', gap: '14px', overflowX: 'hidden' }}>
            {[1, 2, 3, 4, 5, 6].map((i) => (
              <div key={i} style={{ display: 'flex', flexDirection: 'column', gap: '8px', width: '148px', flexShrink: 0 }}>
                <SkeletonBlock width="148px" height="148px" borderRadius="14px" />
                <SkeletonBlock width="120px" height="12px" />
                <SkeletonBlock width="80px" height="10px" />
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  // Quick action items definition
  const quickActions = [
    { label: 'Scenes', icon: Moon, type: 'scenes', color: '#7B61FF' },
    { label: 'Concert', icon: Mic, type: 'concert', color: '#FF6482' },
    { label: 'Labs', icon: FlaskConical, type: 'labs', color: '#00D4FF' },
    { label: 'Wrapped', icon: BarChart2, type: 'wrapped', color: '#F97316' },
    { label: 'Drive', icon: Car, type: 'drive', color: '#6366F1' },
  ];

  // Mood/genres items definition
  const genres = [
    { name: 'Love', query: 'Hindi Romantic', color: 'linear-gradient(to right, #FF416C, #FF4B2B)' },
    { name: 'Devotional', query: 'Hindi Bhajans', color: 'linear-gradient(to right, #F12711, #F5AF19)' },
    { name: 'Party', query: 'Hindi Party', color: 'linear-gradient(to right, #11998E, #38EF7D)' },
    { name: 'Workout', query: 'Workout Hindi', color: 'linear-gradient(to right, #FC4A1A, #F7B733)' },
    { name: 'Chill', query: 'Hindi Lofi Chill', color: 'linear-gradient(to right, #00B4DB, #0083B0)' },
    { name: 'Sad', query: 'Sad Hindi', color: 'linear-gradient(to right, #3A6073, #3A6073)' },
    { name: 'Punjabi', query: 'Punjabi Hits', color: 'linear-gradient(to right, #7F00FF, #E100FF)' },
    { name: 'English', query: 'English Pop Hits', color: 'linear-gradient(to right, #ED213A, #93291E)' },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflowY: 'auto', paddingBottom: '32px', position: 'relative' }}>
      
      {/* ─── 1. Header (Greetings row) ─── */}
      <div style={{ display: 'flex', alignItems: 'center', padding: '24px 24px 8px 24px', gap: '16px' }}>
        <div
          className="shimmer-box"
          style={{
            width: '44px',
            height: '44px',
            borderRadius: '12px',
            background: isSupporter 
              ? 'linear-gradient(135deg, #ec4899 0%, #a855f7 100%)' 
              : 'linear-gradient(135deg, var(--accent) 0%, var(--accent-alt) 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: '0 4px 14px rgba(250, 45, 72, 0.3)',
            color: '#fff'
          }}
        >
          <Music size={20} />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ fontSize: '13px', color: 'var(--text-secondary)', fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {getTimeGreeting()}{profileName ? `, ${profileName}` : ''}
            </span>
            {isSupporter && (
              <span
                style={{
                  fontSize: '8px',
                  fontWeight: 900,
                  color: '#ec4899',
                  backgroundColor: 'rgba(236, 72, 153, 0.12)',
                  border: '1px solid rgba(236, 72, 153, 0.3)',
                  borderRadius: '6px',
                  padding: '2px 6px',
                  letterSpacing: '0.5px'
                }}
              >
                SUPPORTER 💖
              </span>
            )}
          </div>
          <h1 style={{ fontSize: '28px', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.5px', marginTop: '2px' }}>
            Listen Now
          </h1>
        </div>
      </div>

      {/* ─── 2. Search Bar Redirect ─── */}
      <div style={{ padding: '8px 24px 16px 24px' }}>
        <div
          onClick={() => setActiveTab(1)}
          className="liquid-glass"
          style={{
            height: '48px',
            borderRadius: '14px',
            display: 'flex',
            alignItems: 'center',
            padding: '0 16px',
            gap: '12px',
            cursor: 'pointer',
            border: '1px solid rgba(255, 255, 255, 0.06)'
          }}
        >
          <Search size={18} style={{ color: 'var(--text-secondary)' }} />
          <span style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>Songs, albums, artists</span>
        </div>
      </div>

      {/* ─── 3. Quick Actions Grid (Wrapping for desktop accessibility) ─── */}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px', padding: '0 24px 16px 24px' }}>
        {quickActions.map((action) => {
          const Icon = action.icon;
          return (
            <div
              key={action.label}
              onClick={() => {
                if (action.type === 'labs') {
                  setActiveTab(3);
                } else {
                  handleOpenModal(action.type as any);
                }
              }}
              className="liquid-glass liquid-glass-interactive"
              style={{
                flexShrink: 0,
                width: '88px',
                height: '76px',
                borderRadius: '14px',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px',
                border: '1px solid rgba(255, 255, 255, 0.05)',
                boxShadow: `0 4px 16px ${action.color}15`
              }}
            >
              <Icon size={24} style={{ color: action.color }} />
              <span style={{ fontSize: '11px', fontWeight: 600, color: 'var(--text-primary)' }}>{action.label}</span>
            </div>
          );
        })}
      </div>

      {/* ─── 4. Explore Genres & Moods ─── */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', padding: '8px 0 16px 0' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 800, padding: '0 24px', letterSpacing: '-0.5px' }}>
          Explore Genres & Moods
        </h2>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', padding: '0 24px' }}>
          {genres.map((genre) => (
            <div
              key={genre.name}
              onClick={() => handleOpenStation(genre)}
              className="liquid-glass liquid-glass-interactive"
              style={{
                flexShrink: 0,
                padding: '10px 16px',
                borderRadius: '14px',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                border: '1px solid rgba(255, 255, 255, 0.06)'
              }}
            >
              <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: genre.color }} />
              <span style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-primary)' }}>{genre.name}</span>
            </div>
          ))}
        </div>
      </div>

      {/* ─── 5. AI DJ switch toggle card ─── */}
      <div style={{ padding: '0 24px 12px 24px' }}>
        <div
          className="liquid-glass"
          style={{
            padding: '12px 16px',
            borderRadius: '14px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            border: '1px solid rgba(250, 45, 72, 0.15)'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div
              style={{
                width: '36px',
                height: '36px',
                borderRadius: '10px',
                background: 'linear-gradient(135deg, var(--accent) 0%, var(--accent-soft) 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#fff'
              }}
            >
              <Sparkles size={18} />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <span style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-primary)' }}>AI DJ</span>
              <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Smart queue from your vibe</span>
            </div>
          </div>
          <button
            onClick={toggleAutoplay}
            style={{
              width: '46px',
              height: '24px',
              borderRadius: '12px',
              backgroundColor: isAutoplay ? 'var(--accent)' : 'rgba(255, 255, 255, 0.08)',
              border: 'none',
              position: 'relative',
              cursor: 'pointer',
              transition: 'background-color 0.2s'
            }}
          >
            <div
              style={{
                width: '18px',
                height: '18px',
                borderRadius: '50%',
                backgroundColor: '#fff',
                position: 'absolute',
                top: '3px',
                left: isAutoplay ? '25px' : '3px',
                transition: 'left 0.2s cubic-bezier(0.2, 0.8, 0.2, 1)'
              }}
            />
          </button>
        </div>
      </div>

      {/* ─── 6. Streak Chip ─── */}
      {(streakCount > 0 || !hasListenedToday) && (
        <div style={{ padding: '0 24px 16px 24px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Flame size={18} style={{ color: 'var(--accent)' }} />
            <span style={{ fontSize: '12px', fontWeight: 600, color: '#fff' }}>
              {streakCount > 0 ? `${streakCount} day streak` : 'Start your streak today'}
            </span>
            {hasListenedToday && (
              <span style={{ fontSize: '11px', color: 'var(--text-tertiary)', marginLeft: '4px' }}>✓ today</span>
            )}
          </div>
        </div>
      )}

      {/* ─── 7. ROTTY Labs Banner Card ─── */}
      <div style={{ padding: '0 24px 16px 24px' }}>
        <div
          onClick={() => setActiveTab(3)}
          className="liquid-glass liquid-glass-interactive"
          style={{
            padding: '16px',
            borderRadius: '14px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            border: '1px solid rgba(255, 255, 255, 0.06)'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
            <div
              style={{
                width: '48px',
                height: '48px',
                borderRadius: '12px',
                background: 'linear-gradient(135deg, #7B61FF 0%, #00D4FF 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#fff'
              }}
            >
              <FlaskConical size={24} />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <span style={{ fontSize: '16px', fontWeight: 700, color: 'var(--text-primary)' }}>ROTTY Labs</span>
              <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Aura • Cinema • Shake • Drive +</span>
            </div>
          </div>
          <ChevronRight size={20} style={{ color: 'var(--text-secondary)' }} />
        </div>
      </div>

      {/* ─── 8. Continue Listening (Recent History) ─── */}
      {recentSongs.length > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', padding: '12px 0' }}>
          <h2 style={{ fontSize: '20px', fontWeight: 700, padding: '0 24px' }}>
            Continue Listening
          </h2>
          <div style={{ overflowX: 'auto', display: 'flex', gap: '14px', padding: '0 24px 8px 24px', scrollbarWidth: 'none' }} className="no-scrollbar">
            {recentSongs.slice(0, 10).map((song, idx) => (
              <div
                key={`${song.id}-${idx}`}
                onClick={() => playSong(song, recentSongs)}
                style={{ position: 'relative', width: '148px', flexShrink: 0, cursor: 'pointer', display: 'flex', flexDirection: 'column', gap: '8px' }}
              >
                <div style={{ position: 'relative', width: '100%', aspectRatio: '1/1', borderRadius: '14px', overflow: 'hidden', border: '1px solid rgba(255,255,255,0.08)', boxShadow: '0 4px 12px rgba(0,0,0,0.3)' }}>
                  <img src={song.image} alt={song.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  <div className="play-overlay" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <div className="play-overlay-button" style={{ transform: 'none' }}>
                      <Play size={18} fill="currentColor" style={{ marginLeft: '2px' }} />
                    </div>
                  </div>
                </div>
                {/* Floating Action Menu */}
                <div 
                  style={{ position: 'absolute', top: '8px', right: '8px', zIndex: 30 }}
                  onClick={(e) => e.stopPropagation()}
                >
                  <SongOptionsMenu 
                    song={song} 
                    align="right"
                    trigger={
                      <button
                        style={{
                          background: 'rgba(5, 5, 8, 0.7)',
                          backdropFilter: 'blur(10px)',
                          border: '1px solid rgba(255, 255, 255, 0.1)',
                          color: '#fff',
                          width: '28px',
                          height: '28px',
                          borderRadius: '50%',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          cursor: 'pointer',
                          boxShadow: '0 2px 8px rgba(0,0,0,0.3)'
                        }}
                      >
                        <MoreVertical size={13} />
                      </button>
                    }
                  />
                </div>
                <div className="liquid-glass" style={{ padding: '6px 8px', borderRadius: '8px', border: '1px solid rgba(255,255,255,0.05)', display: 'flex', flexDirection: 'column', gap: '2px', overflow: 'hidden' }}>
                  <span style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {song.title}
                  </span>
                  <span style={{ fontSize: '10px', color: 'var(--text-secondary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {song.artist}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ─── 9. API Playlists (Horizontal lists) ─── */}
      {Object.entries(sections).map(([title, songs]) => (
        <div key={title} style={{ display: 'flex', flexDirection: 'column', gap: '12px', padding: '12px 0' }}>
          <h2 style={{ fontSize: '20px', fontWeight: 700, padding: '0 24px' }}>
            {title}
          </h2>
          <div style={{ overflowX: 'auto', display: 'flex', gap: '14px', padding: '0 24px 8px 24px', scrollbarWidth: 'none' }} className="no-scrollbar">
            {songs.map((song, idx) => (
              <div
                key={`${song.id}-${idx}`}
                onClick={() => playSong(song, songs)}
                style={{ position: 'relative', width: '148px', flexShrink: 0, cursor: 'pointer', display: 'flex', flexDirection: 'column', gap: '8px' }}
              >
                <div style={{ position: 'relative', width: '100%', aspectRatio: '1/1', borderRadius: '14px', overflow: 'hidden', border: '1px solid rgba(255,255,255,0.08)', boxShadow: '0 4px 12px rgba(0,0,0,0.3)' }}>
                  <img src={song.image} alt={song.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  <div className="play-overlay" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <div className="play-overlay-button" style={{ transform: 'none' }}>
                      <Play size={18} fill="currentColor" style={{ marginLeft: '2px' }} />
                    </div>
                  </div>
                </div>
                {/* Floating Action Menu */}
                <div 
                  style={{ position: 'absolute', top: '8px', right: '8px', zIndex: 30 }}
                  onClick={(e) => e.stopPropagation()}
                >
                  <SongOptionsMenu 
                    song={song} 
                    align="right"
                    trigger={
                      <button
                        style={{
                          background: 'rgba(5, 5, 8, 0.7)',
                          backdropFilter: 'blur(10px)',
                          border: '1px solid rgba(255, 255, 255, 0.1)',
                          color: '#fff',
                          width: '28px',
                          height: '28px',
                          borderRadius: '50%',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          cursor: 'pointer',
                          boxShadow: '0 2px 8px rgba(0,0,0,0.3)'
                        }}
                      >
                        <MoreVertical size={13} />
                      </button>
                    }
                  />
                </div>
                <div className="liquid-glass" style={{ padding: '6px 8px', borderRadius: '8px', border: '1px solid rgba(255,255,255,0.05)', display: 'flex', flexDirection: 'column', gap: '2px', overflow: 'hidden' }}>
                  <span style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {song.title}
                  </span>
                  <span style={{ fontSize: '10px', color: 'var(--text-secondary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {song.artist}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}


      {/* ─── STATION MODAL (DRAWER) ─── */}
      {selectedStation && (
        <div
          style={{
            position: isMobile ? 'fixed' : 'absolute',
            top: 0,
            left: 0,
            width: isMobile ? '100vw' : '100%',
            height: isMobile ? '100vh' : '100%',
            zIndex: 110,
            background: 'rgba(5, 5, 8, 0.95)',
            display: 'flex',
            flexDirection: 'column',
            animation: 'fadeIn 0.2s ease-out'
          }}
        >
          {/* Drawer Header */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '24px 20px', borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: selectedStation.color }} />
              <h2 style={{ fontSize: '20px', fontWeight: 800 }}>{selectedStation.name} Station</h2>
            </div>
            <button
              onClick={() => setSelectedStation(null)}
              style={{ background: 'rgba(255,255,255,0.06)', border: 'none', color: '#fff', padding: '8px', borderRadius: '50%', cursor: 'pointer' }}
            >
              <X size={20} />
            </button>
          </div>

          {/* Drawer Content */}
          <div style={{ flex: 1, overflowY: 'auto', padding: '20px' }}>
            {stationLoading ? (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', gap: '12px' }}>
                <Disc size={36} className="spin-animation" style={{ color: 'var(--accent)' }} />
                <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Tuning into station radio...</span>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <button
                  onClick={() => stationSongs.length > 0 && playSong(stationSongs[0], stationSongs)}
                  className="liquid-glass"
                  style={{
                    width: '100%',
                    padding: '14px',
                    borderRadius: '12px',
                    background: 'var(--accent)',
                    border: 'none',
                    color: '#fff',
                    fontWeight: 700,
                    fontSize: '15px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '8px',
                    cursor: 'pointer',
                    boxShadow: '0 4px 16px rgba(250, 45, 72, 0.4)'
                  }}
                >
                  <Play size={18} fill="currentColor" /> Play Station Radio
                </button>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginTop: '8px' }}>
                  {stationSongs.map((song, i) => (
                    <SongRow
                      key={`${song.id}-${i}`}
                      song={song}
                      index={i}
                      customQueue={stationSongs}
                    />
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      )}


      {/* ─── QUICK ACTION SPECIFIC MODALS ─── */}
      {activeModal === 'scenes' && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            width: '100vw',
            height: '100vh',
            zIndex: 110,
            background: 'rgba(5, 5, 8, 0.96)',
            display: 'flex',
            flexDirection: 'column'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '24px 20px', borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <Moon size={22} style={{ color: '#7B61FF' }} />
              <h2 style={{ fontSize: '20px', fontWeight: 800 }}>Scenic Soundscapes</h2>
            </div>
            <button
              onClick={() => setActiveModal(null)}
              style={{ background: 'rgba(255,255,255,0.06)', border: 'none', color: '#fff', padding: '8px', borderRadius: '50%', cursor: 'pointer' }}
            >
              <X size={20} />
            </button>
          </div>

          <div style={{ flex: 1, overflowY: 'auto', padding: '20px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <span style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: '1.4' }}>
              Select a natural backdrop scene to filter out surrounding noise, boost focus, or help you wind down.
            </span>

            {/* Scenes selectors */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '12px' }}>
              {[
                { name: 'Rainstorm', query: 'Rain Sound Sleep', icon: CloudRain, color: '#00D4FF' },
                { name: 'Cozy Cafe', query: 'Cafe Ambient Jazz', icon: Coffee, color: '#F97316' },
                { name: 'Forest Breeze', query: 'Forest Wind Whispers', icon: Wind, color: '#38EF7D' },
                { name: 'Deep Space', query: 'Deep Space Binaural Beats', icon: Moon, color: '#7B61FF' }
              ].map((scene) => {
                const SceneIcon = scene.icon;
                return (
                  <div
                    key={scene.name}
                    onClick={() => handleSelectScene(scene.query)}
                    className="liquid-glass liquid-glass-interactive"
                    style={{
                      padding: '16px',
                      borderRadius: '14px',
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      gap: '8px',
                      border: '1px solid rgba(255,255,255,0.06)',
                      textAlign: 'center'
                    }}
                  >
                    <SceneIcon size={28} style={{ color: scene.color }} />
                    <span style={{ fontSize: '13px', fontWeight: 700, color: '#fff' }}>{scene.name}</span>
                  </div>
                );
              })}
            </div>

            {/* Dynamic scenes songlist */}
            <div style={{ marginTop: '12px' }}>
              <h3 style={{ fontSize: '14px', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: '12px' }}>Scene Audio Tracks</h3>
              
              {modalLoading ? (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '40px 0' }}>
                  <Disc size={28} className="spin-animation" style={{ color: 'var(--accent)' }} />
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  {modalSongs.map((song, idx) => (
                    <div
                      key={`${song.id}-${idx}`}
                      onClick={() => playSong(song, modalSongs)}
                      className="liquid-glass liquid-glass-interactive"
                      style={{
                        padding: '10px 12px',
                        borderRadius: '12px',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '12px',
                        border: '1px solid rgba(255,255,255,0.04)'
                      }}
                    >
                      <img src={song.image} alt="" style={{ width: '40px', height: '40px', borderRadius: '6px', objectFit: 'cover' }} />
                      <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minWidth: 0 }}>
                        <span style={{ fontSize: '13px', fontWeight: 600, color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {song.title}
                        </span>
                        <span style={{ fontSize: '11px', color: 'var(--text-secondary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {song.artist}
                        </span>
                      </div>
                      <Play size={14} style={{ color: 'var(--text-secondary)' }} />
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {activeModal === 'concert' && (
        <div
          style={{
            position: isMobile ? 'fixed' : 'absolute',
            top: 0,
            left: 0,
            width: isMobile ? '100vw' : '100%',
            height: isMobile ? '100vh' : '100%',
            zIndex: 110,
            background: 'rgba(5, 5, 8, 0.96)',
            display: 'flex',
            flexDirection: 'column'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '24px 20px', borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <Mic size={22} style={{ color: '#FF6482' }} />
              <h2 style={{ fontSize: '20px', fontWeight: 800 }}>Concert Arena</h2>
            </div>
            <button
              onClick={() => setActiveModal(null)}
              style={{ background: 'rgba(255,255,255,0.06)', border: 'none', color: '#fff', padding: '8px', borderRadius: '50%', cursor: 'pointer' }}
            >
              <X size={20} />
            </button>
          </div>

          <div style={{ flex: 1, overflowY: 'auto', padding: '20px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <span style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: '1.4' }}>
              Listen to standard live recordings, unplugged concerts, and electric arena music.
            </span>

            {modalLoading ? (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '60%', gap: '12px' }}>
                <Disc size={36} className="spin-animation" style={{ color: 'var(--accent)' }} />
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                {modalSongs.map((song, i) => (
                  <SongRow
                    key={`${song.id}-${i}`}
                    song={song}
                    index={i}
                    customQueue={modalSongs}
                  />
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {activeModal === 'wrapped' && (
        <div
          style={{
            position: isMobile ? 'fixed' : 'absolute',
            top: 0,
            left: 0,
            width: isMobile ? '100vw' : '100%',
            height: isMobile ? '100vh' : '100%',
            zIndex: 110,
            background: 'rgba(5, 5, 8, 0.96)',
            display: 'flex',
            flexDirection: 'column'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '24px 20px', borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <BarChart2 size={22} style={{ color: '#F97316' }} />
              <h2 style={{ fontSize: '20px', fontWeight: 800 }}>Rotty Wrapped Stats</h2>
            </div>
            <button
              onClick={() => setActiveModal(null)}
              style={{ background: 'rgba(255,255,255,0.06)', border: 'none', color: '#fff', padding: '8px', borderRadius: '50%', cursor: 'pointer' }}
            >
              <X size={20} />
            </button>
          </div>

          <div style={{ flex: 1, overflowY: 'auto', padding: '20px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <div
              className="liquid-glass"
              style={{
                padding: '24px',
                borderRadius: '16px',
                background: 'linear-gradient(135deg, rgba(249, 115, 22, 0.15) 0%, rgba(250, 45, 72, 0.05) 100%)',
                textAlign: 'center',
                border: '1px solid rgba(249, 115, 22, 0.3)'
              }}
            >
              <span style={{ fontSize: '11px', color: '#F97316', fontWeight: 800, letterSpacing: '2px', textTransform: 'uppercase' }}>
                Your Listening Persona
              </span>
              <h3 style={{ fontSize: '24px', fontWeight: 800, marginTop: '8px' }}>
                {streakCount > 5 ? 'Loyal Audiophile 🎧' : 'Music Adventurer 🚀'}
              </h3>
              <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginTop: '8px' }}>
                You have streamed {recentSongs.length || 0} unique tracks on this PWA workspace! Keep rocking your streak.
              </p>
            </div>

            {/* Metrics cards */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '12px' }}>
              <div className="liquid-glass" style={{ padding: '16px', borderRadius: '12px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Listening Streak</span>
                <span style={{ fontSize: '20px', fontWeight: 800, color: 'var(--accent)' }}>{streakCount} Days</span>
              </div>
              <div className="liquid-glass" style={{ padding: '16px', borderRadius: '12px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Liked Tracks</span>
                <span style={{ fontSize: '20px', fontWeight: 800, color: '#ec4899' }}>{StorageService.getLikedSongs().length} Songs</span>
              </div>
            </div>

            {/* Personal top tracks list */}
            <div>
              <h3 style={{ fontSize: '14px', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: '12px' }}>Your Recently Streamed Hits</h3>
              {recentSongs.length === 0 ? (
                <div style={{ padding: '24px', textAlign: 'center', color: 'var(--text-tertiary)', fontSize: '13px' }}>
                  No play history yet. Start playing songs to compile stats!
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  {recentSongs.slice(0, 10).map((song, i) => (
                    <SongRow
                      key={`${song.id}-${i}`}
                      song={song}
                      index={i}
                      customQueue={recentSongs}
                    />
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {activeModal === 'drive' && (
        <div
          style={{
            position: isMobile ? 'fixed' : 'absolute',
            top: 0,
            left: 0,
            width: isMobile ? '100vw' : '100%',
            height: isMobile ? '100vh' : '100%',
            zIndex: 120,
            background: '#07070a',
            display: 'flex',
            flexDirection: 'column',
            padding: '24px 20px',
            animation: 'fadeIn 0.25s ease-out'
          }}
        >
          {/* Header */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '40px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Car size={20} style={{ color: '#6366F1' }} />
              <span style={{ fontSize: '13px', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '1.5px', color: 'var(--text-secondary)' }}>
                Drive Mode
              </span>
            </div>
            <button
              onClick={() => setActiveModal(null)}
              style={{
                background: 'rgba(255,255,255,0.08)',
                border: 'none',
                color: '#fff',
                padding: '8px 16px',
                borderRadius: '20px',
                fontSize: '12px',
                fontWeight: 700,
                cursor: 'pointer'
              }}
            >
              Exit
            </button>
          </div>

          {currentSong ? (
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', gap: '40px', textAlign: 'center' }}>
              {/* Huge album art circle */}
              <div
                style={{
                  width: '200px',
                  height: '200px',
                  borderRadius: '50%',
                  overflow: 'hidden',
                  boxShadow: '0 20px 50px rgba(99, 102, 241, 0.25)',
                  border: '4px solid rgba(255, 255, 255, 0.08)',
                  animation: isPlaying ? 'spin 12s linear infinite' : 'none'
                }}
              >
                <img src={currentSong.image} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              </div>

              {/* Large Metadata */}
              <div style={{ width: '100%', overflow: 'hidden', padding: '0 20px' }}>
                <h2 style={{ fontSize: '28px', fontWeight: 900, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', color: '#fff' }}>
                  {currentSong.title}
                </h2>
                <p style={{ fontSize: '18px', color: 'var(--text-secondary)', marginTop: '6px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {currentSong.artist}
                </p>
              </div>

              {/* Distraction-free giant playback controller */}
              <button
                onClick={togglePlay}
                style={{
                  width: '110px',
                  height: '110px',
                  borderRadius: '50%',
                  background: 'var(--accent)',
                  color: '#fff',
                  border: 'none',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  boxShadow: '0 8px 32px rgba(250, 45, 72, 0.4)',
                  cursor: 'pointer'
                }}
              >
                {isPlaying ? <Pause size={48} fill="currentColor" /> : <Play size={48} fill="currentColor" style={{ marginLeft: '6px' }} />}
              </button>
            </div>
          ) : (
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '16px', color: 'var(--text-secondary)' }}>
              <ShieldAlert size={48} />
              <span>Select a song first to enter Drive controls.</span>
            </div>
          )}
        </div>
      )}

    </div>
  );
};
