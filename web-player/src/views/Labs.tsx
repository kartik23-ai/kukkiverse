import React, { useState, useEffect } from 'react';
import { useAudio } from '../context/AudioContext';
import { Sliders, Moon, Timer, Play, Pause, RotateCcw } from 'lucide-react';

export const Labs: React.FC = () => {
  const {
    isPlaying,
    togglePlay,
    bassBoost,
    setBassBoost,
    vocalForward,
    setVocalForward,
    is8DActive,
    set8DActive,
    isAutoplay,
    toggleAutoplay
  } = useAudio();

  // Sleep Timer States
  const [sleepTimeRemaining, setSleepTimeRemaining] = useState<number>(0); // in seconds
  const [sleepTimerActive, setSleepTimerActive] = useState<boolean>(false);

  // Focus Timer States (Pomodoro)
  const [focusTimeRemaining, setFocusTimeRemaining] = useState<number>(1500); // 25 mins
  const [focusTimerActive, setFocusTimerActive] = useState<boolean>(false);
  const [focusMode, setFocusMode] = useState<'focus' | 'break'>('focus');

  // 1. Sleep Timer effect loop
  useEffect(() => {
    let timer: number | null = null;
    if (sleepTimerActive && sleepTimeRemaining > 0) {
      timer = window.setInterval(() => {
        setSleepTimeRemaining((prev) => {
          if (prev <= 1) {
            // Trigger sleep timer: Pause music
            if (isPlaying) togglePlay();
            setSleepTimerActive(false);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    }
    return () => {
      if (timer) clearInterval(timer);
    };
  }, [sleepTimerActive, sleepTimeRemaining, isPlaying]);

  // 2. Focus Timer effect loop
  useEffect(() => {
    let timer: number | null = null;
    if (focusTimerActive && focusTimeRemaining > 0) {
      timer = window.setInterval(() => {
        setFocusTimeRemaining((prev) => {
          if (prev <= 1) {
            // Switch mode
            if (focusMode === 'focus') {
              setFocusMode('break');
              // Auto-pause or chime
              if (isPlaying) togglePlay();
              return 300; // 5 mins break
            } else {
              setFocusMode('focus');
              return 1500; // 25 mins focus
            }
          }
          return prev - 1;
        });
      }, 1000);
    }
    return () => {
      if (timer) clearInterval(timer);
    };
  }, [focusTimerActive, focusTimeRemaining, focusMode, isPlaying]);

  // Helpers
  const formatSeconds = (totalSecs: number) => {
    const mins = Math.floor(totalSecs / 60);
    const secs = totalSecs % 60;
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  };

  const startSleepTimer = (mins: number) => {
    if (mins === 0) {
      setSleepTimerActive(false);
      setSleepTimeRemaining(0);
      return;
    }
    setSleepTimeRemaining(mins * 60);
    setSleepTimerActive(true);
  };

  return (
    <div style={{ padding: '32px', display: 'flex', flexDirection: 'column', gap: '32px', overflowY: 'auto', height: '100%' }}>
      
      {/* Page Header */}
      <div>
        <h1 style={{ fontSize: '28px', fontWeight: 800 }}>Rotty Labs</h1>
        <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
          Experimental audio tools and productivity utility features.
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '24px' }}>
        
        {/* Lab 1: Studio EQ */}
        <div className="liquid-glass" style={{ padding: '24px', borderRadius: '14px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <Sliders size={20} style={{ color: 'var(--accent)' }} />
            <h2 style={{ fontSize: '18px', fontWeight: 700 }}>Studio EQ Lab</h2>
          </div>
          <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
            Adjust real-time Web Audio filters to tune the sound signature.
          </p>

          {/* Bass Boost Slider */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
              <span style={{ fontWeight: 600 }}>Bass Boost</span>
              <span style={{ color: 'var(--accent)', fontWeight: 700 }}>{bassBoost} dB</span>
            </div>
            <input
              type="range"
              className="custom-slider"
              min={0}
              max={12}
              step={1}
              value={bassBoost}
              onChange={(e) => setBassBoost(parseInt(e.target.value))}
            />
          </div>

          {/* Vocal Forward Toggle */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 0', borderBottom: '1px solid rgba(255, 255, 255, 0.05)' }}>
            <div>
              <span style={{ fontSize: '14px', fontWeight: 600, display: 'block' }}>Vocal Forward</span>
              <span style={{ fontSize: '11px', color: 'var(--text-tertiary)' }}>Brings mid-frequencies forward for crisp vocals</span>
            </div>
            <input
              type="checkbox"
              checked={vocalForward}
              onChange={(e) => setVocalForward(e.target.checked)}
              style={{
                width: '36px',
                height: '18px',
                accentColor: 'var(--accent)',
                cursor: 'pointer'
              }}
            />
          </div>

          {/* 8D Space Orbit Toggle */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 0' }}>
            <div>
              <span style={{ fontSize: '14px', fontWeight: 600, display: 'block' }}>8D Orbiting</span>
              <span style={{ fontSize: '11px', color: 'var(--text-tertiary)' }}>Slow spatial stereo panning simulation</span>
            </div>
            <input
              type="checkbox"
              checked={is8DActive}
              onChange={(e) => set8DActive(e.target.checked)}
              style={{
                width: '36px',
                height: '18px',
                accentColor: 'var(--accent)',
                cursor: 'pointer'
              }}
            />
          </div>
        </div>

        {/* Lab 2: Sleep Oracle */}
        <div className="liquid-glass" style={{ padding: '24px', borderRadius: '14px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <Moon size={20} style={{ color: 'var(--accent)' }} />
            <h2 style={{ fontSize: '18px', fontWeight: 700 }}>Sleep Oracle</h2>
          </div>
          <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
            Schedule a timer to automatically pause playback and help you fall asleep.
          </p>

          {/* Time Countdown clock */}
          {sleepTimerActive ? (
            <div style={{ textAlign: 'center', padding: '20px 0' }}>
              <span style={{ fontSize: '32px', fontFamily: 'var(--font-heading)', fontWeight: 800, color: 'var(--accent)' }}>
                {formatSeconds(sleepTimeRemaining)}
              </span>
              <p style={{ fontSize: '12px', color: 'var(--text-tertiary)', marginTop: '8px' }}>
                Music will pause in {Math.ceil(sleepTimeRemaining / 60)} minutes
              </p>
              <button
                onClick={() => startSleepTimer(0)}
                className="liquid-glass-interactive"
                style={{
                  background: 'rgba(255, 255, 255, 0.05)',
                  border: 'none',
                  borderRadius: '20px',
                  padding: '8px 16px',
                  color: '#fa2d48',
                  fontSize: '12px',
                  fontWeight: 600,
                  marginTop: '12px',
                  cursor: 'pointer'
                }}
              >
                Cancel Timer
              </button>
            </div>
          ) : (
            /* Presets grid */
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px' }}>
              {[5, 15, 30, 45, 60, 90].map((mins) => (
                <button
                  key={mins}
                  onClick={() => startSleepTimer(mins)}
                  className="liquid-glass-interactive"
                  style={{
                    background: 'rgba(255, 255, 255, 0.02)',
                    border: '1px solid rgba(255, 255, 255, 0.04)',
                    borderRadius: '8px',
                    padding: '12px',
                    color: 'var(--text-primary)',
                    fontWeight: 600,
                    fontSize: '13px',
                    cursor: 'pointer'
                  }}
                >
                  {mins} min
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Lab 3: Focus Lock */}
        <div className="liquid-glass" style={{ padding: '24px', borderRadius: '14px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <Timer size={20} style={{ color: 'var(--accent)' }} />
            <h2 style={{ fontSize: '18px', fontWeight: 700 }}>Focus Lock</h2>
          </div>
          <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
            Pomodoro block tool. Music helps you focus, and pauses during breaks.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '16px', padding: '10px 0' }}>
            <div style={{ textAlign: 'center' }}>
              <span style={{ fontSize: '11px', color: 'var(--accent-alt)', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '1.5px' }}>
                {focusMode === 'focus' ? 'Focus Interval' : 'Rest Interval'}
              </span>
              <div style={{ fontSize: '36px', fontFamily: 'var(--font-heading)', fontWeight: 900, color: 'var(--text-primary)', marginTop: '4px' }}>
                {formatSeconds(focusTimeRemaining)}
              </div>
            </div>

            {/* Timers controls */}
            <div style={{ display: 'flex', gap: '12px' }}>
              <button
                onClick={() => setFocusTimerActive(!focusTimerActive)}
                style={{
                  background: 'var(--accent)',
                  border: 'none',
                  color: 'var(--bg-deep)',
                  width: '36px',
                  height: '36px',
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer'
                }}
              >
                {focusTimerActive ? <Pause size={16} fill="currentColor" /> : <Play size={16} fill="currentColor" />}
              </button>
              <button
                onClick={() => {
                  setFocusTimerActive(false);
                  setFocusMode('focus');
                  setFocusTimeRemaining(1500);
                }}
                style={{
                  background: 'rgba(255, 255, 255, 0.05)',
                  border: 'none',
                  color: 'var(--text-primary)',
                  width: '36px',
                  height: '36px',
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer'
                }}
              >
                <RotateCcw size={16} />
              </button>
            </div>
          </div>
        </div>

        {/* Lab 4: AI DJ Autoplay */}
        <div className="liquid-glass" style={{ padding: '24px', borderRadius: '14px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <Sliders size={20} style={{ color: 'var(--accent)' }} />
            <h2 style={{ fontSize: '18px', fontWeight: 700 }}>Smart Queue Autoplay</h2>
          </div>
          <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
            Automatically refill the queue with similar songs matching active taste and session mood when queue ends.
          </p>

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 0' }}>
            <div>
              <span style={{ fontSize: '14px', fontWeight: 600, display: 'block' }}>Autoplay Recommendations</span>
              <span style={{ fontSize: '11px', color: 'var(--text-tertiary)' }}>Fetches similar artists from public nodes</span>
            </div>
            <input
              type="checkbox"
              checked={isAutoplay}
              onChange={toggleAutoplay}
              style={{
                width: '36px',
                height: '18px',
                accentColor: 'var(--accent)',
                cursor: 'pointer'
              }}
            />
          </div>
        </div>

      </div>
    </div>
  );
};
