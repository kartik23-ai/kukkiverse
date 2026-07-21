import React, { useState, useEffect, useRef } from 'react';
import { ThemeProvider } from './context/ThemeContext';
import { AudioProvider, useAudio } from './context/AudioContext';
import { AuroraBackground } from './components/AuroraBackground';
import { Sidebar } from './components/Sidebar';
import { PlayerBar } from './components/PlayerBar';
import { NowPlayingPanel, LyricsPane, QueuePane, ConnectPane } from './components/NowPlayingPanel';
import { AuthModal } from './components/AuthModal';
import { LibrarySyncService } from './services/librarySync';
import { SongOptionsMenu } from './components/SongOptionsMenu';
import { PwaInstallPrompt } from './components/PwaInstallPrompt';


// Views
import { Home } from './views/Home';
import { Search } from './views/Search';
import { Library } from './views/Library';
import { Labs } from './views/Labs';
import { Settings } from './views/Settings';
import { Support } from './views/Support';

import { 
  Home as HomeIcon, Search as SearchIcon, Library as LibIcon, 
  Sliders as LabIcon, Settings as SetIcon, ChevronDown, 
  Play, Pause, SkipForward, SkipBack, Shuffle, Repeat, Heart,
  Music2, Sparkles, AlignLeft, ListMusic, Wifi, ArrowLeft
} from 'lucide-react';
import { StorageService } from './services/storage';

const AppContent: React.FC = () => {
  const [activeTab, setActiveTab] = useState<number>(0);
  const [isPanelOpen, setIsPanelOpen] = useState<boolean>(true);
  const [isAuthOpen, setIsAuthOpen] = useState<boolean>(false);
  const [isMobile, setIsMobile] = useState<boolean>(window.innerWidth <= 768);
  const [isMobilePlayerOpen, setIsMobilePlayerOpen] = useState<boolean>(false);
  const [mobilePlayerView, setMobilePlayerView] = useState<'player' | 'lyrics' | 'queue' | 'connect'>('player');
  const [userUid, setUserUid] = useState<string | null>(localStorage.getItem('rotty_user_uid'));

  useEffect(() => {
    const handleAuthCheck = () => {
      setUserUid(localStorage.getItem('rotty_user_uid'));
    };
    window.addEventListener('library-update', handleAuthCheck);
    return () => window.removeEventListener('library-update', handleAuthCheck);
  }, []);

  // Reset view state to player when mobile sheet closes
  useEffect(() => {
    if (!isMobilePlayerOpen) {
      setMobilePlayerView('player');
    }
  }, [isMobilePlayerOpen]);

  // Dynamically transition theme colors on active tab change
  useEffect(() => {
    const root = document.documentElement;
    const palettes = [
      { accent: '#FA2D48', soft: '#FF6482', alt: '#5E5CE6' }, // 0: Home -> Crimson Red
      { accent: '#7B61FF', soft: '#A291FF', alt: '#00D4FF' }, // 1: Search -> Indigo/Purple
      { accent: '#00D4FF', soft: '#6BE8FF', alt: '#FA2D48' }, // 2: Library -> Cyan/Teal
      { accent: '#10B981', soft: '#34D399', alt: '#7B61FF' }, // 3: Rotty Labs -> Emerald Green
      { accent: '#F59E0B', soft: '#FBBF24', alt: '#00D4FF' }, // 4: Settings -> Sunset Amber/Orange
      { accent: '#FF2E93', soft: '#FF6EB4', alt: '#A259FF' }  // 5: Support -> Supporter Hot-Pink
    ];

    const currentPalette = palettes[activeTab] || palettes[0];
    root.style.setProperty('--accent', currentPalette.accent);
    root.style.setProperty('--accent-soft', currentPalette.soft);
    root.style.setProperty('--accent-alt', currentPalette.alt);
  }, [activeTab]);

  // Splash & Guest Prompt States
  const [showSplash, setShowSplash] = useState<boolean>(true);
  const [showGuestPrompt, setShowGuestPrompt] = useState<boolean>(false);
  const [guestName, setGuestName] = useState<string>('');

  const { 
    currentSong, isPlaying, togglePlay, nextSong, prevSong, 
    currentTime, duration, seek,
    isShuffle, toggleShuffle, isLoop, toggleLoop 
  } = useAudio();

  const [isLiked, setIsLiked] = useState<boolean>(false);

  // Splash timeout and Guest name check
  useEffect(() => {
    const timer = setTimeout(() => {
      const storedName = StorageService.getProfileName();
      if (!storedName) {
        setShowGuestPrompt(true);
      } else {
        setShowSplash(false);
      }
    }, 2200);
    return () => clearTimeout(timer);
  }, []);

  // Background Library Sync on App Startup
  useEffect(() => {
    const uid = localStorage.getItem('rotty_user_uid');
    if (uid) {
      LibrarySyncService.syncAll(uid);
    }
  }, []);

  const handleSaveGuestName = () => {
    const trimmed = guestName.trim();
    if (!trimmed) return;
    StorageService.setProfileName(trimmed);
    setShowGuestPrompt(false);
    setShowSplash(false);
  };

  useEffect(() => {
    if (currentSong) {
      setIsLiked(StorageService.isSongLiked(currentSong.id));
    }
  }, [currentSong]);

  // Global Keyboard Shortcuts (Space to play/pause, Arrow keys to seek)
  const togglePlayRef = useRef(togglePlay);
  const seekRef = useRef(seek);
  const currentTimeRef = useRef(currentTime);
  const durationRef = useRef(duration);
  const currentSongRef = useRef(currentSong);

  useEffect(() => {
    togglePlayRef.current = togglePlay;
    seekRef.current = seek;
    currentTimeRef.current = currentTime;
    durationRef.current = duration;
    currentSongRef.current = currentSong;
  }); // updates refs on every render

  useEffect(() => {
    const handleGlobalKeyDown = (e: KeyboardEvent) => {
      const activeEl = document.activeElement;
      if (
        activeEl && 
        (activeEl.tagName === 'INPUT' || 
         activeEl.tagName === 'TEXTAREA' || 
         activeEl.getAttribute('contenteditable') === 'true')
      ) {
        return;
      }

      if (e.code === 'Space' || e.key === ' ') {
        e.preventDefault();
        e.stopPropagation();
        togglePlayRef.current();
      }

      if (e.code === 'ArrowLeft' && currentSongRef.current) {
        e.preventDefault();
        seekRef.current(Math.max(0, currentTimeRef.current - 5));
      }

      if (e.code === 'ArrowRight' && currentSongRef.current) {
        e.preventDefault();
        seekRef.current(Math.min(durationRef.current, currentTimeRef.current + 5));
      }
    };

    window.addEventListener('keydown', handleGlobalKeyDown, true); // capture phase
    return () => {
      window.removeEventListener('keydown', handleGlobalKeyDown, true);
    };
  }, []);

  const handleLike = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (!currentSong) return;
    const liked = StorageService.toggleLikeSong(currentSong);
    setIsLiked(liked);
  };

  // Monitor screen resizing
  useEffect(() => {
    const handleResize = () => {
      const mobile = window.innerWidth <= 768;
      setIsMobile(mobile);
      if (mobile) {
        setIsPanelOpen(false); 
      }
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const renderActiveView = () => {
    switch (activeTab) {
      case 0:
        return <Home setActiveTab={setActiveTab} />;
      case 1:
        return <Search />;
      case 2:
        return <Library />;
      case 3:
        return <Labs />;
      case 4:
        return <Settings onOpenAuth={() => setIsAuthOpen(true)} setActiveTab={setActiveTab} />;
      case 5:
        return <Support />;
      default:
        return <Home setActiveTab={setActiveTab} />;
    }
  };

  const formatTime = (seconds: number) => {
    if (isNaN(seconds)) return '0:00';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  };

  if (showSplash) {
    return (
      <div
        style={{
          width: '100vw',
          height: '100vh',
          backgroundColor: '#050508',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          position: 'fixed',
          top: 0,
          left: 0,
          zIndex: 1000,
          overflow: 'hidden'
        }}
      >
        <AuroraBackground />
        
        {showGuestPrompt ? (
          <div
            className="liquid-glass"
            style={{
              padding: '32px',
              borderRadius: '28px',
              border: '1px solid rgba(255, 255, 255, 0.08)',
              width: '90%',
              maxWidth: '400px',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              boxShadow: '0 8px 32px 0 rgba(250, 45, 72, 0.15)',
              textAlign: 'center',
              gap: '24px'
            }}
          >
            <div
              style={{
                width: '72px',
                height: '72px',
                borderRadius: '50%',
                background: 'linear-gradient(135deg, #FA2D48 0%, #7B61FF 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 4px 20px rgba(250, 45, 72, 0.3)',
                color: '#fff'
              }}
            >
              <Sparkles size={36} />
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <h3 style={{ fontSize: '22px', fontWeight: 900, color: '#fff', letterSpacing: '0.5px' }}>
                Welcome to Rotty! 🎵
              </h3>
              <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
                What should we call you?
              </p>
            </div>

            <input
              type="text"
              placeholder="Enter your name..."
              value={guestName}
              onChange={(e) => setGuestName(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleSaveGuestName()}
              style={{
                width: '100%',
                fontWeight: 600,
                textAlign: 'center'
              }}
              autoFocus
            />

            <button
              onClick={handleSaveGuestName}
              className="liquid-glass-interactive"
              style={{
                width: '100%',
                height: '48px',
                background: 'var(--accent)',
                border: 'none',
                borderRadius: '14px',
                color: 'var(--bg-deep)',
                fontWeight: 800,
                fontSize: '13px',
                letterSpacing: '1px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px',
                boxShadow: '0 4px 12px rgba(250, 45, 72, 0.25)'
              }}
            >
              <span>LET'S GO</span>
              <SkipForward size={14} fill="currentColor" />
            </button>
          </div>
        ) : (
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center'
            }}
          >
            <div
              className="shimmer-box"
              style={{
                width: '100px',
                height: '100px',
                borderRadius: '24px',
                background: 'linear-gradient(135deg, #FA2D48 0%, #7B61FF 50%, #00D4FF 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 8px 40px rgba(250, 45, 72, 0.5), 0 12px 60px rgba(123, 97, 255, 0.3)',
                color: '#fff'
              }}
            >
              <Music2 size={52} />
            </div>

            <div style={{ marginTop: '32px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <h2
                className="shimmer-text"
                style={{
                  fontSize: '44px',
                  fontWeight: 900,
                  letterSpacing: '10px',
                  paddingLeft: '10px'
                }}
              >
                ROTTY
              </h2>
              <span
                style={{
                  fontSize: '14px',
                  fontWeight: 600,
                  color: 'var(--accent)',
                  letterSpacing: '14px',
                  marginTop: '8px',
                  paddingLeft: '14px'
                }}
              >
                MUSIC
              </span>
              <span style={{ fontSize: '13px', color: 'var(--text-secondary)', letterSpacing: '2px', marginTop: '24px' }}>
                Feel The Future
              </span>
            </div>

            <div style={{
              marginTop: '40px',
              width: '180px',
              height: '4px',
              backgroundColor: 'rgba(255, 255, 255, 0.05)',
              borderRadius: '2px',
              overflow: 'hidden',
              position: 'relative'
            }}>
              <div style={{
                position: 'absolute',
                top: 0,
                left: 0,
                height: '100%',
                width: '60%',
                background: 'linear-gradient(90deg, transparent, var(--accent), transparent)',
                animation: 'loading-pulse 1.5s infinite ease-in-out'
              }} />
            </div>
          </div>
        )}
      </div>
    );
  }

  if (!userUid) {
    return (
      <AuthModal 
        isOpen={true} 
        isForced={true} 
        onClose={() => setUserUid(localStorage.getItem('rotty_user_uid'))} 
      />
    );
  }

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        width: '100%',
        height: '100vh',
        overflow: 'hidden',
        position: 'relative'
      }}
    >
      <AuroraBackground />

      <div
        style={{
          display: 'flex',
          flex: 1,
          width: '100%',
          overflow: 'hidden',
          position: 'relative'
        }}
      >
        {!isMobile && (
          <Sidebar 
            activeTab={activeTab} 
            setActiveTab={setActiveTab} 
            onOpenAuth={() => setIsAuthOpen(true)} 
          />
        )}
        
        <main
          style={{
            flex: 1,
            height: '100%',
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column',
            paddingBottom: isMobile && currentSong ? '132px' : isMobile ? '72px' : '0'
          }}
        >
          {renderActiveView()}
        </main>

        {!isMobile && isPanelOpen && (
          <NowPlayingPanel onOpenAuth={() => setIsAuthOpen(true)} />
        )}
      </div>

      {isMobile ? (
        <>
          {currentSong && (
            <div
              onClick={() => setIsMobilePlayerOpen(true)}
              className="liquid-glass"
              style={{
                position: 'fixed',
                bottom: '76px',
                left: '12px',
                right: '12px',
                height: '60px',
                borderRadius: '12px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '0 16px',
                cursor: 'pointer',
                zIndex: 50,
                boxShadow: '0 8px 24px rgba(0, 0, 0, 0.4)'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', overflow: 'hidden', flex: 1 }}>
                <img 
                  src={currentSong.image} 
                  alt="" 
                  style={{ width: '40px', height: '40px', borderRadius: '6px', objectFit: 'cover' }} 
                />
                <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
                  <span style={{ fontSize: '13px', fontWeight: 600, color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {currentSong.title}
                  </span>
                  <span style={{ fontSize: '11px', color: 'var(--text-secondary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {currentSong.artist}
                  </span>
                </div>
              </div>
              
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }} onClick={e => e.stopPropagation()}>
                <button
                  onClick={handleLike}
                  style={{ background: 'transparent', border: 'none', color: isLiked ? 'var(--accent)' : 'var(--text-secondary)' }}
                >
                  <Heart size={18} fill={isLiked ? 'var(--accent)' : 'transparent'} />
                </button>
                <button
                  onClick={togglePlay}
                  style={{
                    background: 'transparent',
                    border: 'none',
                    color: '#fff',
                    cursor: 'pointer',
                    width: '36px',
                    height: '36px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center'
                  }}
                >
                  {isPlaying ? <Pause size={20} fill="#fff" /> : <Play size={20} fill="#fff" />}
                </button>
              </div>
            </div>
          )}

          <nav
            className="liquid-glass"
            style={{
              position: 'fixed',
              bottom: 0,
              left: 0,
              width: '100%',
              height: '64px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-around',
              borderRadius: '16px 16px 0 0',
              zIndex: 49,
              padding: '0 8px',
              borderTop: '1px solid rgba(255, 255, 255, 0.05)'
            }}
          >
            {[
              { icon: HomeIcon, label: 'Home', index: 0 },
              { icon: SearchIcon, label: 'Search', index: 1 },
              { icon: LibIcon, label: 'Library', index: 2 },
              { icon: LabIcon, label: 'Labs', index: 3 },
              { icon: SetIcon, label: 'Settings', index: 4 }
            ].map((tab) => {
              const Icon = tab.icon;
              const isActive = activeTab === tab.index;
              return (
                <button
                  key={tab.index}
                  onClick={() => setActiveTab(tab.index)}
                  style={{
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    gap: '4px',
                    background: 'transparent',
                    border: 'none',
                    color: isActive ? 'var(--accent)' : 'var(--text-secondary)',
                    cursor: 'pointer',
                    flex: 1,
                    padding: '8px 0'
                  }}
                >
                  <Icon size={18} style={{ strokeWidth: isActive ? 2.5 : 2 }} />
                  <span style={{ fontSize: '9px', fontWeight: isActive ? 700 : 500 }}>
                    {tab.label}
                  </span>
                </button>
              );
            })}
          </nav>
        </>
      ) : (
        <PlayerBar isPanelOpen={isPanelOpen} setIsPanelOpen={setIsPanelOpen} />
      )}

      {isMobile && isMobilePlayerOpen && currentSong && (
        <div
          className="liquid-glass"
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            width: '100vw',
            height: '100vh',
            zIndex: 100,
            display: 'flex',
            flexDirection: 'column',
            background: 'rgba(5, 5, 8, 0.98)',
            boxShadow: '0 0 50px rgba(0,0,0,0.9)',
            overflow: 'hidden'
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 20px', borderBottom: '1px solid rgba(255, 255, 255, 0.03)' }}>
            <button
              onClick={() => {
                if (mobilePlayerView !== 'player') {
                  setMobilePlayerView('player');
                } else {
                  setIsMobilePlayerOpen(false);
                }
              }}
              style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer', padding: '4px', display: 'flex', alignItems: 'center' }}
            >
              {mobilePlayerView !== 'player' ? <ArrowLeft size={24} /> : <ChevronDown size={28} />}
            </button>
            <span style={{ fontSize: '11px', fontWeight: 800, letterSpacing: '2px', textTransform: 'uppercase', color: 'var(--text-secondary)' }}>
              {mobilePlayerView === 'player' && 'Now Playing'}
              {mobilePlayerView === 'lyrics' && 'Lyrics'}
              {mobilePlayerView === 'queue' && 'Play Queue'}
              {mobilePlayerView === 'connect' && 'Rotty Connect'}
            </span>
            {mobilePlayerView === 'player' ? (
              <button
                onClick={() => setMobilePlayerView('queue')}
                style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer', padding: '4px' }}
              >
                <ListMusic size={22} />
              </button>
            ) : (
              <div style={{ width: '30px' }} />
            )}
          </div>

          {mobilePlayerView === 'player' ? (
            <div 
              style={{ 
                flex: 1, 
                overflowY: 'auto', 
                padding: '20px 20px 40px 20px',
                display: 'flex',
                flexDirection: 'column',
                gap: '24px',
                scrollbarWidth: 'none',
                msOverflowStyle: 'none'
              }}
              className="no-scrollbar"
            >
              <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', width: '100%' }}>
                <img 
                  src={currentSong.image} 
                  alt={currentSong.title} 
                  style={{ 
                    width: '80vw', 
                    maxWidth: '280px', 
                    aspectRatio: '1/1', 
                    borderRadius: '24px', 
                    objectFit: 'cover',
                    boxShadow: isPlaying 
                      ? '0 16px 40px rgba(0, 0, 0, 0.6), 0 0 30px rgba(250, 45, 72, 0.15)'
                      : '0 8px 24px rgba(0, 0, 0, 0.4)',
                    transform: isPlaying ? 'scale(1)' : 'scale(0.92)',
                    transition: 'transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1), box-shadow 0.4s ease'
                  }} 
                />
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', overflow: 'hidden', marginRight: '16px', flex: 1 }}>
                  <h2 style={{ fontSize: '20px', fontWeight: 900, color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', letterSpacing: '-0.5px' }}>
                    {currentSong.title}
                  </h2>
                  <span style={{ fontSize: '14px', fontWeight: 500, color: 'var(--text-secondary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {currentSong.artist}
                  </span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <button
                    onClick={handleLike}
                    style={{ 
                      background: 'transparent', 
                      border: 'none', 
                      color: isLiked ? 'var(--accent)' : 'var(--text-secondary)', 
                      padding: '8px',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      transition: 'transform 0.2s'
                    }}
                    onMouseDown={(e) => e.currentTarget.style.transform = 'scale(0.8)'}
                    onMouseUp={(e) => e.currentTarget.style.transform = 'scale(1)'}
                  >
                    <Heart size={22} fill={isLiked ? 'var(--accent)' : 'transparent'} />
                  </button>
                  <SongOptionsMenu song={currentSong} align="right" />
                </div>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <input
                  type="range"
                  className="custom-slider"
                  min={0}
                  max={duration || 100}
                  step={0.1}
                  value={currentTime}
                  onChange={(e) => seek(parseFloat(e.target.value))}
                  style={{
                    background: `linear-gradient(to right, var(--accent) 0%, var(--accent) ${(currentTime / (duration || 1)) * 100}%, rgba(255, 255, 255, 0.08) ${(currentTime / (duration || 1)) * 100}%, rgba(255, 255, 255, 0.08) 100%)`
                  }}
                />
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', fontWeight: 600, color: 'var(--text-tertiary)' }}>
                  <span>{formatTime(currentTime)}</span>
                  <span>{formatTime(duration)}</span>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-around', alignItems: 'center' }}>
                <button
                  onClick={toggleShuffle}
                  style={{ background: 'transparent', border: 'none', color: isShuffle ? 'var(--accent)' : 'var(--text-secondary)', cursor: 'pointer' }}
                >
                  <Shuffle size={20} />
                </button>
                <button
                  onClick={prevSong}
                  style={{ background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer' }}
                >
                  <SkipBack size={28} fill="currentColor" />
                </button>
                <button
                  onClick={togglePlay}
                  style={{
                    background: '#fff',
                    border: 'none',
                    color: 'var(--bg-deep)',
                    width: '64px',
                    height: '64px',
                    borderRadius: '50%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    boxShadow: '0 8px 20px rgba(255,255,255,0.2), 0 0 0 1px rgba(255,255,255,0.1)',
                    cursor: 'pointer',
                    transition: 'all 0.2s'
                  }}
                  onMouseDown={(e) => e.currentTarget.style.transform = 'scale(0.92)'}
                  onMouseUp={(e) => e.currentTarget.style.transform = 'scale(1)'}
                >
                  {isPlaying ? <Pause size={28} fill="currentColor" /> : <Play size={28} fill="currentColor" style={{ marginLeft: '4px' }} />}
                </button>
                <button
                  onClick={nextSong}
                  style={{ background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer' }}
                >
                  <SkipForward size={28} fill="currentColor" />
                </button>
                <button
                  onClick={toggleLoop}
                  style={{ background: 'transparent', border: 'none', color: isLoop !== 'none' ? 'var(--accent)' : 'var(--text-secondary)', position: 'relative', cursor: 'pointer' }}
                >
                  <Repeat size={20} />
                  {isLoop === 'one' && <span style={{ position: 'absolute', top: '-6px', right: '-8px', fontSize: '9px', fontWeight: 900, color: 'var(--accent)', background: 'var(--bg-deep)', padding: '0 2px', borderRadius: '4px' }}>1</span>}
                </button>
              </div>

              <div 
                style={{ 
                  display: 'flex', 
                  justifyContent: 'center', 
                  gap: '10px', 
                  marginTop: '12px',
                  padding: '12px 6px',
                  borderRadius: '16px',
                  background: 'rgba(255, 255, 255, 0.02)',
                  border: '1px solid rgba(255, 255, 255, 0.05)'
                }}
              >
                <button
                  onClick={() => setMobilePlayerView('lyrics')}
                  className="liquid-glass-interactive"
                  style={{
                    flex: 1,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '6px',
                    padding: '8px 12px',
                    borderRadius: '12px',
                    background: 'rgba(255, 255, 255, 0.03)',
                    border: '1px solid rgba(255, 255, 255, 0.05)',
                    color: 'var(--text-primary)',
                    fontSize: '12px',
                    fontWeight: 600,
                    cursor: 'pointer'
                  }}
                >
                  <AlignLeft size={14} />
                  <span>Lyrics</span>
                </button>
                <button
                  onClick={() => setMobilePlayerView('queue')}
                  className="liquid-glass-interactive"
                  style={{
                    flex: 1,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '6px',
                    padding: '8px 12px',
                    borderRadius: '12px',
                    background: 'rgba(255, 255, 255, 0.03)',
                    border: '1px solid rgba(255, 255, 255, 0.05)',
                    color: 'var(--text-primary)',
                    fontSize: '12px',
                    fontWeight: 600,
                    cursor: 'pointer'
                  }}
                >
                  <ListMusic size={14} />
                  <span>Queue</span>
                </button>
                <button
                  onClick={() => setMobilePlayerView('connect')}
                  className="liquid-glass-interactive"
                  style={{
                    flex: 1,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '6px',
                    padding: '8px 12px',
                    borderRadius: '12px',
                    background: 'rgba(255, 255, 255, 0.03)',
                    border: '1px solid rgba(255, 255, 255, 0.05)',
                    color: 'var(--text-primary)',
                    fontSize: '12px',
                    fontWeight: 600,
                    cursor: 'pointer'
                  }}
                >
                  <Wifi size={14} />
                  <span>Connect</span>
                </button>
              </div>
            </div>
          ) : (
            <div 
              style={{ 
                flex: 1, 
                display: 'flex', 
                flexDirection: 'column', 
                padding: '16px 20px 24px 20px', 
                overflow: 'hidden',
                position: 'relative'
              }}
            >
              <div style={{ flex: 1, overflowY: 'auto', marginBottom: '16px', display: 'flex', width: '100%' }}>
                {mobilePlayerView === 'lyrics' && <LyricsPane />}
                {mobilePlayerView === 'queue' && <QueuePane />}
                {mobilePlayerView === 'connect' && <ConnectPane onOpenAuth={() => setIsAuthOpen(true)} />}
              </div>

              <div
                className="liquid-glass"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '10px 14px',
                  borderRadius: '14px',
                  border: '1px solid rgba(255, 255, 255, 0.06)',
                  boxShadow: '0 8px 32px 0 rgba(0, 0, 0, 0.3)',
                  backgroundColor: 'rgba(255, 255, 255, 0.01)',
                  backdropFilter: 'blur(20px)'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', overflow: 'hidden', flex: 1, marginRight: '12px' }}>
                  <img src={currentSong.image} alt="" style={{ width: '32px', height: '32px', borderRadius: '4px', objectFit: 'cover' }} />
                  <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
                    <span style={{ fontSize: '12px', fontWeight: 600, color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{currentSong.title}</span>
                    <span style={{ fontSize: '10px', color: 'var(--text-secondary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{currentSong.artist}</span>
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <button onClick={prevSong} style={{ background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer', padding: '4px' }}>
                    <SkipBack size={14} fill="currentColor" />
                  </button>
                  <button 
                    onClick={togglePlay} 
                    style={{ 
                      background: '#fff', 
                      border: 'none', 
                      color: 'var(--bg-deep)', 
                      width: '28px', 
                      height: '28px', 
                      borderRadius: '50%', 
                      display: 'flex', 
                      alignItems: 'center', 
                      justifyContent: 'center',
                      cursor: 'pointer'
                    }}
                  >
                    {isPlaying ? <Pause size={12} fill="currentColor" /> : <Play size={12} fill="currentColor" style={{ marginLeft: '1px' }} />}
                  </button>
                  <button onClick={nextSong} style={{ background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer', padding: '4px' }}>
                    <SkipForward size={14} fill="currentColor" />
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {isAuthOpen && <AuthModal isOpen={isAuthOpen} onClose={() => setIsAuthOpen(false)} />}
      <PwaInstallPrompt />
    </div>

  );
};

export const App: React.FC = () => {
  return (
    <ThemeProvider>
      <AudioProvider>
        <AppContent />
      </AudioProvider>
    </ThemeProvider>
  );
};

export default App;
