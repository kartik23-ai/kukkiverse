import React, { useState, useEffect, useRef } from 'react';
import { useAudio } from '../context/AudioContext';
import { MusicApi } from '../services/api';
import { SongOptionsMenu } from './SongOptionsMenu';
import { 
  ListMusic, AlignLeft, ChevronUp, ChevronDown, X, 
  Wifi, Laptop, Smartphone, RefreshCw, Sparkles, AlertCircle, CloudLightning,
  Crown, LogOut, Radio, Copy
} from 'lucide-react';

interface LrcLine {
  time: number;
  text: string;
}

export interface NowPlayingPanelProps {
  onOpenAuth: () => void;
}

// LRC Synced Lyrics parser
function parseLrc(lrcText: string): LrcLine[] {
  if (!lrcText) return [];
  const lines = lrcText.split('\n');
  const result: LrcLine[] = [];
  const timeRegex = /\[(\d{2}):(\d{2})\.(\d{2,3})\]/;

  for (const line of lines) {
    const match = timeRegex.exec(line);
    if (match) {
      const minutes = parseInt(match[1], 10);
      const seconds = parseInt(match[2], 10);
      const milliseconds = parseInt(match[3], 10);
      
      // Calculate float time in seconds
      const time = minutes * 60 + seconds + (milliseconds / (match[3].length === 3 ? 1000 : 100));
      const text = line.replace(timeRegex, '').trim();
      
      result.push({ time, text });
    }
  }

  return result.sort((a, b) => a.time - b.time);
}

// ──────────────────────────────────────────────────────────────────
// 1. REUSABLE LYRICS PANEL
// ──────────────────────────────────────────────────────────────────
export const LyricsPane: React.FC = () => {
  const { currentSong, currentTime } = useAudio();
  const [lyricsText, setLyricsText] = useState<string | null>(null);
  const [syncedLines, setSyncedLines] = useState<LrcLine[]>([]);
  const [loadingLyrics, setLoadingLyrics] = useState<boolean>(false);
  const [activeIndex, setActiveIndex] = useState<number>(-1);
  const listContainerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!currentSong) return;
    
    setLyricsText(null);
    setSyncedLines([]);
    setActiveIndex(-1);
    setLoadingLyrics(true);

    MusicApi.getLyrics(currentSong)
      .then((lyrics) => {
        setLyricsText(lyrics);
        if (lyrics) {
          const parsed = parseLrc(lyrics);
          setSyncedLines(parsed);
        }
      })
      .catch(() => {
        setLyricsText('Could not load lyrics for this track.');
      })
      .finally(() => {
        setLoadingLyrics(false);
      });
  }, [currentSong]);

  useEffect(() => {
    if (syncedLines.length === 0) return;

    let index = -1;
    for (let i = 0; i < syncedLines.length; i++) {
      if (currentTime >= syncedLines[i].time) {
        index = i;
      } else {
        break;
      }
    }

    if (index !== activeIndex) {
      setActiveIndex(index);
      
      // Smooth scroll the active line to center
      if (index >= 0) {
        const lineElement = document.getElementById(`lyrics-line-${index}`);
        if (lineElement && listContainerRef.current) {
          lineElement.scrollIntoView({
            behavior: 'smooth',
            block: 'center'
          });
        }
      }
    }
  }, [currentTime, syncedLines, activeIndex]);

  if (loadingLyrics) {
    return (
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '16px', width: '100%', padding: '20px 0', overflow: 'hidden' }}>
        {[
          { width: '60%' },
          { width: '80%' },
          { width: '45%' },
          { width: '70%' },
          { width: '55%' },
          { width: '85%' },
          { width: '40%' },
          { width: '65%' },
          { width: '50%' }
        ].map((line, idx) => (
          <div 
            key={idx} 
            className="shimmer-box" 
            style={{ 
              width: line.width, 
              height: '24px', 
              borderRadius: '8px', 
              alignSelf: 'center',
              background: 'rgba(255, 255, 255, 0.02)', 
              border: '1px solid rgba(255, 255, 255, 0.03)' 
            }} 
          />
        ))}
      </div>
    );
  }

  return (
    <div 
      ref={listContainerRef} 
      style={{ 
        flex: 1, 
        overflowY: 'auto', 
        display: 'flex', 
        flexDirection: 'column', 
        gap: '12px',
        width: '100%',
        scrollbarWidth: 'none',
        msOverflowStyle: 'none'
      }}
      className="no-scrollbar"
    >
      {syncedLines.length > 0 ? (
        syncedLines.map((line, idx) => {
          const isActive = idx === activeIndex;
          const distance = Math.abs(idx - activeIndex);
          const opacity = isActive ? 1 : Math.max(0.2, 1 - distance * 0.15);
          
          return (
            <p
              key={idx}
              id={`lyrics-line-${idx}`}
              style={{
                fontSize: isActive ? '20px' : '16px',
                fontWeight: isActive ? 800 : 500,
                lineHeight: '1.4',
                color: isActive ? 'var(--text-primary)' : 'var(--text-tertiary)',
                padding: '8px 12px',
                borderRadius: '8px',
                backgroundColor: isActive ? 'rgba(255, 255, 255, 0.04)' : 'transparent',
                textShadow: isActive ? '0 0 10px rgba(255, 255, 255, 0.15)' : 'none',
                transition: 'all 0.25s ease',
                transform: isActive ? 'scale(1.02)' : 'scale(1)',
                opacity: opacity,
                textAlign: 'center'
              }}
            >
              {line.text}
            </p>
          );
        })
      ) : lyricsText ? (
        <div style={{ whiteSpace: 'pre-wrap', fontSize: '15px', lineHeight: '1.6', color: 'var(--text-secondary)', textAlign: 'center', padding: '10px' }}>
          {lyricsText}
        </div>
      ) : (
        <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-tertiary)', fontSize: '13px', textAlign: 'center', padding: '40px 0' }}>
          Lyrics not found for this track.
        </div>
      )}
    </div>
  );
};

// ──────────────────────────────────────────────────────────────────
// 2. REUSABLE QUEUE PANEL
// ──────────────────────────────────────────────────────────────────
export const QueuePane: React.FC = () => {
  const { queue, currentSong, playSong, removeFromQueue, clearQueue, moveQueueItem, triggerAiRefill } = useAudio();

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', width: '100%' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
        <h4 style={{ fontSize: '11px', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '1px' }}>
          Play Queue ({queue.length})
        </h4>
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          <button
            onClick={triggerAiRefill}
            className="liquid-glass-interactive"
            style={{
              background: 'rgba(250, 45, 72, 0.08)',
              border: '1px solid rgba(250, 45, 72, 0.25)',
              color: 'var(--accent)',
              fontSize: '11px',
              fontWeight: 600,
              cursor: 'pointer',
              padding: '3px 8px',
              borderRadius: '4px',
              display: 'flex',
              alignItems: 'center',
              gap: '4px'
            }}
          >
            <Sparkles size={10} />
            <span>AI Refill</span>
          </button>
          {queue.length > 0 && (
            <button
              onClick={clearQueue}
              style={{
                background: 'transparent',
                border: 'none',
                color: 'var(--text-secondary)',
                fontSize: '11px',
                fontWeight: 600,
                cursor: 'pointer',
                padding: '3px 8px',
                borderRadius: '4px'
              }}
            >
              Clear
            </button>
          )}
        </div>
      </div>

      {queue.length === 0 ? (
        <div style={{ padding: '40px 0', textAlign: 'center', color: 'var(--text-tertiary)', fontSize: '12px' }}>
          Queue is empty. Select tracks to play.
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
          {queue.map((song, idx) => {
            const isCurrent = currentSong && song.id === currentSong.id;
            return (
              <div
                key={song.id + '-' + idx}
                onClick={() => playSong(song)}
                className="liquid-glass-interactive"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  padding: '8px',
                  borderRadius: '8px',
                  background: isCurrent ? 'rgba(255, 255, 255, 0.04)' : 'transparent',
                  borderLeft: isCurrent ? '3px solid var(--accent)' : '3px solid transparent',
                  cursor: 'pointer',
                  position: 'relative'
                }}
              >
                <img src={song.image} alt={song.title} style={{ width: '36px', height: '36px', borderRadius: '4px', objectFit: 'cover' }} />
                <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden', flex: 1 }}>
                  <span style={{ fontSize: '12px', fontWeight: isCurrent ? 600 : 500, color: isCurrent ? 'var(--accent)' : 'var(--text-primary)', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>
                    {song.title}
                  </span>
                  <span style={{ fontSize: '10px', color: 'var(--text-secondary)', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>
                    {song.artist}
                  </span>
                </div>
                
                {/* Hover action items (re-order, delete) */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '2px' }} onClick={(e) => e.stopPropagation()}>
                  <button
                    disabled={idx === 0}
                    onClick={() => moveQueueItem(idx, idx - 1)}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      color: 'var(--text-tertiary)',
                      cursor: idx === 0 ? 'not-allowed' : 'pointer',
                      padding: '2px',
                      opacity: idx === 0 ? 0.3 : 1
                    }}
                  >
                    <ChevronUp size={14} />
                  </button>
                  <button
                    disabled={idx === queue.length - 1}
                    onClick={() => moveQueueItem(idx, idx + 1)}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      color: 'var(--text-tertiary)',
                      cursor: idx === queue.length - 1 ? 'not-allowed' : 'pointer',
                      padding: '2px',
                      opacity: idx === queue.length - 1 ? 0.3 : 1
                    }}
                  >
                    <ChevronDown size={14} />
                  </button>
                  <button
                    onClick={() => removeFromQueue(song.id)}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      color: 'var(--text-tertiary)',
                      cursor: 'pointer',
                      padding: '2px',
                      marginLeft: '4px'
                    }}
                  >
                    <X size={14} />
                  </button>
                  <SongOptionsMenu song={song} align="right" />
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

// ──────────────────────────────────────────────────────────────────
// 3. REUSABLE CONNECT PANEL
// ──────────────────────────────────────────────────────────────────
interface ConnectPaneProps {
  onOpenAuth: () => void;
}

export const ConnectPane: React.FC<ConnectPaneProps> = ({ onOpenAuth }) => {
  const {
    isSyncControlled,
    setIsSyncControlled,
    syncPlaybackState,
    syncDevices,
    refreshSyncDevices,
    partyCode,
    partyRoom,
    isPartyHost,
    createPartyRoom,
    joinPartyRoom,
    leavePartyRoom,
    kickPartyMember
  } = useAudio();

  const [joinCodeInput, setJoinCodeInput] = useState<string>('');
  const [partyError, setPartyError] = useState<string | null>(null);
  const [partySuccess, setPartySuccess] = useState<string | null>(null);
  const [loadingDevices, setLoadingDevices] = useState<boolean>(false);
  
  const isLoggedIn = !!localStorage.getItem('rotty_user_uid');

  const handleRefreshDevices = async () => {
    setLoadingDevices(true);
    await refreshSyncDevices();
    setLoadingDevices(false);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', width: '100%' }}>
      {/* PART 1: PARTY SYNC (LISTEN TOGETHER) */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', borderBottom: '1px solid rgba(255, 255, 255, 0.05)', paddingBottom: '20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <Radio size={16} style={{ color: 'var(--accent)' }} />
          <h4 style={{ fontSize: '11px', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '1px' }}>
            Party Sync (Rooms)
          </h4>
        </div>

        {partyError && <div style={{ color: 'var(--accent)', fontSize: '11px', fontWeight: 500 }}>{partyError}</div>}
        {partySuccess && <div style={{ color: '#4ade80', fontSize: '11px', fontWeight: 500 }}>{partySuccess}</div>}

        {!partyCode ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <span style={{ fontSize: '11px', color: 'var(--text-secondary)', lineHeight: '1.4' }}>
              Listen together with friends in real-time. Link play queues.
            </span>
            
            <button
              onClick={async () => {
                try {
                  setPartyError(null);
                  const code = await createPartyRoom();
                  setPartySuccess(`Host room active: ${code}`);
                } catch (e) {
                  setPartyError('Failed to host room');
                }
              }}
              className="liquid-glass-interactive"
              style={{
                background: 'var(--accent)',
                border: 'none',
                borderRadius: '8px',
                color: 'var(--bg-deep)',
                padding: '10px 16px',
                fontSize: '12px',
                fontWeight: 700,
                cursor: 'pointer',
                textAlign: 'center'
              }}
            >
              Host a Party Room
            </button>

            <div style={{ display: 'flex', gap: '8px', marginTop: '4px' }}>
              <input
                type="text"
                placeholder="Room Code (e.g. ROTTY-12345)"
                value={joinCodeInput}
                onChange={(e) => setJoinCodeInput(e.target.value.toUpperCase())}
                style={{ 
                  flex: 1, 
                  padding: '8px 12px', 
                  borderRadius: '8px', 
                  fontSize: '12px',
                  background: 'rgba(255, 255, 255, 0.05)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  color: '#fff'
                }}
              />
              <button
                onClick={async () => {
                  const trimmed = joinCodeInput.trim().toUpperCase();
                  if (!trimmed) return;
                  try {
                    setPartyError(null);
                    await joinPartyRoom(trimmed);
                    setPartySuccess(`Joined Party Room: ${trimmed}`);
                  } catch (e) {
                    setPartyError('Room not found — check code');
                  }
                }}
                className="liquid-glass-interactive"
                style={{
                  background: 'rgba(255, 255, 255, 0.08)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  borderRadius: '8px',
                  color: '#fff',
                  padding: '8px 16px',
                  fontSize: '12px',
                  fontWeight: 700,
                  cursor: 'pointer'
                }}
              >
                Join
              </button>
            </div>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <div
              style={{
                background: 'rgba(255, 255, 255, 0.03)',
                border: '1px solid rgba(255, 255, 255, 0.06)',
                borderRadius: '10px',
                padding: '12px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between'
              }}
            >
              <div style={{ display: 'flex', flexDirection: 'column' }}>
                <span style={{ fontSize: '10px', color: 'var(--text-tertiary)', textTransform: 'uppercase' }}>Active Code</span>
                <span style={{ fontSize: '16px', fontWeight: 800, color: 'var(--accent)', letterSpacing: '0.5px' }}>{partyCode}</span>
              </div>
              <button
                onClick={() => {
                  navigator.clipboard.writeText(partyCode);
                  setPartySuccess('Code copied to clipboard!');
                  setTimeout(() => setPartySuccess(null), 2000);
                }}
                style={{ background: 'rgba(255, 255, 255, 0.05)', border: 'none', color: '#fff', padding: '6px', borderRadius: '6px', cursor: 'pointer' }}
              >
                <Copy size={14} />
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <span style={{ fontSize: '10px', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                Members ({partyRoom?.members.length || 0})
              </span>
              {partyRoom?.members.map((member) => {
                const isMemberHost = member.uid === partyRoom.hostId;
                const isCurrentUser = member.uid === localStorage.getItem('rotty_user_uid');
                return (
                  <div
                    key={member.uid}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      background: 'rgba(255,255,255,0.01)',
                      padding: '6px 8px',
                      borderRadius: '8px',
                      border: '1px solid rgba(255,255,255,0.03)'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: isMemberHost ? 'gold' : '#4ade80' }} />
                      <span style={{ fontSize: '12px', fontWeight: 600 }}>{member.name} {isCurrentUser && '(You)'}</span>
                      {isMemberHost && <Crown size={12} style={{ color: 'gold' }} />}
                    </div>
                    {isPartyHost && !isMemberHost && (
                      <button
                        onClick={() => kickPartyMember(member.uid)}
                        style={{ background: 'transparent', border: 'none', color: 'var(--accent)', cursor: 'pointer' }}
                      >
                        <X size={12} />
                      </button>
                    )}
                  </div>
                );
              })}
            </div>

            <button
              onClick={leavePartyRoom}
              className="liquid-glass-interactive"
              style={{
                background: 'rgba(250, 45, 72, 0.08)',
                border: '1px solid rgba(250, 45, 72, 0.25)',
                borderRadius: '8px',
                color: 'var(--accent)',
                padding: '8px 16px',
                fontSize: '12px',
                fontWeight: 700,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '6px'
              }}
            >
              <LogOut size={14} />
              <span>Leave Party Room</span>
            </button>
          </div>
        )}
      </div>

      {/* PART 2: ROTTY CONNECT (DEVICE SYNC) */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Wifi size={16} style={{ color: 'var(--accent-alt)' }} />
            <h4 style={{ fontSize: '11px', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '1px' }}>
              Rotty Connect (Devices)
            </h4>
          </div>
          {isLoggedIn && (
            <button
              onClick={handleRefreshDevices}
              disabled={loadingDevices}
              style={{
                background: 'transparent',
                border: 'none',
                color: 'var(--text-secondary)',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '4px'
              }}
            >
              <RefreshCw size={12} className={loadingDevices ? 'spin-animation' : ''} style={{ animation: loadingDevices ? 'spin 1.5s linear infinite' : 'none' }} />
            </button>
          )}
        </div>

        {!isLoggedIn ? (
          <div 
            className="liquid-glass" 
            style={{ 
              padding: '20px', 
              borderRadius: '12px', 
              textAlign: 'center', 
              display: 'flex', 
              flexDirection: 'column', 
              gap: '12px',
              border: '1px solid rgba(255, 255, 255, 0.05)'
            }}
          >
            <AlertCircle size={24} style={{ color: 'var(--accent)', alignSelf: 'center' }} />
            <span style={{ fontSize: '12px', color: 'var(--text-secondary)', lineHeight: '1.4' }}>
              Sync is offline. Log in to your account to synchronize playback across devices.
            </span>
            <button
              onClick={onOpenAuth}
              className="liquid-glass-interactive"
              style={{
                background: 'var(--accent)',
                border: 'none',
                borderRadius: '8px',
                color: 'var(--bg-deep)',
                padding: '8px 16px',
                fontSize: '12px',
                fontWeight: 700,
                cursor: 'pointer'
              }}
            >
              Sync Account Now
            </button>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {isSyncControlled && syncPlaybackState && (
              <div 
                style={{ 
                  background: 'rgba(94, 92, 230, 0.08)', 
                  border: '1px solid rgba(94, 92, 230, 0.25)', 
                  borderRadius: '10px', 
                  padding: '12px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '8px'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--accent-alt)' }}>
                  <CloudLightning size={14} className="pulse-animation" style={{ animation: 'pulse 1.5s infinite' }} />
                  <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                    Remote Control Active
                  </span>
                </div>
                {syncPlaybackState.title ? (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    {syncPlaybackState.image && <img src={syncPlaybackState.image} alt="" style={{ width: '28px', height: '28px', borderRadius: '4px' }} />}
                    <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
                      <span style={{ fontSize: '11px', fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{syncPlaybackState.title}</span>
                      <span style={{ fontSize: '9px', color: 'var(--text-secondary)' }}>{syncPlaybackState.artist}</span>
                    </div>
                  </div>
                ) : (
                  <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Waiting for remote device state...</span>
                )}
              </div>
            )}

            <span style={{ fontSize: '10px', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              Online Devices
            </span>
            
            {syncDevices.length === 0 ? (
              <div style={{ padding: '20px 0', textAlign: 'center', color: 'var(--text-tertiary)', fontSize: '12px' }}>
                No sync nodes detected. Keep Rotty running on your other devices.
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {syncDevices.map((device) => {
                  const isCurrentDevice = device.id === localStorage.getItem('rotty_device_id');
                  const isControlledThis = isSyncControlled && syncPlaybackState?.activeDevice === device.id;
                  return (
                    <div 
                      key={device.id}
                      style={{
                        background: 'rgba(255, 255, 255, 0.02)',
                        border: '1px solid rgba(255, 255, 255, 0.05)',
                        borderRadius: '10px',
                        padding: '10px 12px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between'
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', overflow: 'hidden' }}>
                        {device.type === 'desktop' ? (
                          <Laptop size={18} style={{ color: 'var(--text-secondary)' }} />
                        ) : (
                          <Smartphone size={18} style={{ color: 'var(--text-secondary)' }} />
                        )}
                        <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
                          <span style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                            {device.name}
                          </span>
                          <span style={{ fontSize: '9px', color: device.online ? '#4ade80' : 'var(--text-tertiary)' }}>
                            {isCurrentDevice ? 'This Device' : device.online ? 'Online' : 'Offline'}
                          </span>
                        </div>
                      </div>

                      {!isCurrentDevice && device.online && (
                        <button
                          onClick={() => setIsSyncControlled(!isSyncControlled)}
                          className="liquid-glass-interactive"
                          style={{
                            background: isControlledThis ? 'var(--accent)' : 'rgba(255,255,255,0.05)',
                            border: 'none',
                            borderRadius: '6px',
                            color: isControlledThis ? 'var(--bg-deep)' : '#fff',
                            padding: '4px 10px',
                            fontSize: '10px',
                            fontWeight: 700,
                            cursor: 'pointer'
                          }}
                        >
                          {isControlledThis ? 'Disconnect' : 'Control'}
                        </button>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

// ──────────────────────────────────────────────────────────────────
// 4. MAIN PANEL WITH DESKTOP TABS
// ──────────────────────────────────────────────────────────────────
export const NowPlayingPanel: React.FC<NowPlayingPanelProps> = ({ onOpenAuth }) => {
  const { queue } = useAudio();
  const [activeTab, setActiveTab] = useState<'lyrics' | 'queue' | 'connect'>('lyrics');
  const [isMobile, setIsMobile] = useState<boolean>(window.innerWidth <= 768);

  useEffect(() => {
    const handleResize = () => setIsMobile(window.innerWidth <= 768);
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  return (
    <aside
      className="liquid-glass"
      style={{
        width: isMobile ? '100%' : '320px',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        borderRadius: isMobile ? '16px' : '16px 0 0 16px',
        zIndex: 10,
        flexShrink: 0
      }}
    >
      {/* Navigation Tabs */}
      <div
        style={{
          display: 'flex',
          borderBottom: '1px solid rgba(255, 255, 255, 0.05)',
          padding: '12px',
          gap: '4px'
        }}
      >
        <button
          onClick={() => setActiveTab('lyrics')}
          style={{
            flex: 1,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '4px',
            padding: '10px 4px',
            background: activeTab === 'lyrics' ? 'rgba(255, 255, 255, 0.05)' : 'transparent',
            border: 'none',
            borderRadius: '8px',
            color: activeTab === 'lyrics' ? 'var(--accent)' : 'var(--text-secondary)',
            fontFamily: 'var(--font-sans)',
            fontSize: '11px',
            fontWeight: 600,
            cursor: 'pointer',
            transition: 'all 0.2s'
          }}
        >
          <AlignLeft size={12} />
          <span>Lyrics</span>
        </button>
        
        <button
          onClick={() => setActiveTab('queue')}
          style={{
            flex: 1,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '4px',
            padding: '10px 4px',
            background: activeTab === 'queue' ? 'rgba(255, 255, 255, 0.05)' : 'transparent',
            border: 'none',
            borderRadius: '8px',
            color: activeTab === 'queue' ? 'var(--accent)' : 'var(--text-secondary)',
            fontFamily: 'var(--font-sans)',
            fontSize: '11px',
            fontWeight: 600,
            cursor: 'pointer',
            transition: 'all 0.2s'
          }}
        >
          <ListMusic size={12} />
          <span>Queue ({queue.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('connect')}
          style={{
            flex: 1,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '4px',
            padding: '10px 4px',
            background: activeTab === 'connect' ? 'rgba(255, 255, 255, 0.05)' : 'transparent',
            border: 'none',
            borderRadius: '8px',
            color: activeTab === 'connect' ? 'var(--accent)' : 'var(--text-secondary)',
            fontFamily: 'var(--font-sans)',
            fontSize: '11px',
            fontWeight: 600,
            cursor: 'pointer',
            transition: 'all 0.2s'
          }}
        >
          <Wifi size={12} />
          <span>Connect</span>
        </button>
      </div>

      {/* Contents area */}
      <div
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: '20px',
          display: 'flex',
          flexDirection: 'column',
          gap: '12px'
        }}
      >
        {activeTab === 'lyrics' && <LyricsPane />}
        {activeTab === 'queue' && <QueuePane />}
        {activeTab === 'connect' && <ConnectPane onOpenAuth={onOpenAuth} />}
      </div>
    </aside>
  );
};
