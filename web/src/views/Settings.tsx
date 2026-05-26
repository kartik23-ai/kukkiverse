import React, { useState } from 'react';
import { HelpCircle, HardDrive, RefreshCw, User, CloudLightning, LogOut, Heart } from 'lucide-react';
import { StorageService } from '../services/storage';

interface SettingsProps {
  onOpenAuth: () => void;
  setActiveTab: (index: number) => void;
}

export const Settings: React.FC<SettingsProps> = ({ onOpenAuth, setActiveTab }) => {
  const [clearing, setClearing] = useState<boolean>(false);

  const handleClearCache = () => {
    if (window.confirm('Are you sure you want to delete all cached settings, liked songs, and custom playlists? This action cannot be undone.')) {
      setClearing(true);
      localStorage.clear();
      setTimeout(() => {
        window.location.reload();
      }, 800);
    }
  };

  const handleSignOut = () => {
    if (window.confirm('Are you sure you want to sign out from Rotty Connect?')) {
      StorageService.clearUserSession();
      window.location.reload();
    }
  };

  const getStorageMetrics = () => {
    try {
      const liked = JSON.parse(localStorage.getItem('rotty_liked_songs') || '[]').length;
      const playlists = JSON.parse(localStorage.getItem('rotty_playlists') || '[]').length;
      const history = JSON.parse(localStorage.getItem('rotty_recent_songs') || '[]').length;
      return { liked, playlists, history };
    } catch (_) {
      return { liked: 0, playlists: 0, history: 0 };
    }
  };

  const metrics = getStorageMetrics();
  const isLoggedIn = !!localStorage.getItem('rotty_user_uid');
  const userEmail = localStorage.getItem('rotty_user_email') || '';
  const userName = localStorage.getItem('rotty_user_name') || '';

  return (
    <div style={{ padding: '32px', display: 'flex', flexDirection: 'column', gap: '32px', overflowY: 'auto', height: '100%', maxWidth: '800px' }}>
      
      {/* Page Header */}
      <div>
        <h1 style={{ fontSize: '28px', fontWeight: 800 }}>Settings</h1>
        <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
          Configure app aesthetics and manage cloud sync states.
        </p>
      </div>

      {/* User Profile Card */}
      {isLoggedIn && (
        <div 
          className="liquid-glass" 
          style={{ 
            padding: '20px', 
            borderRadius: '24px', 
            display: 'flex', 
            alignItems: 'center', 
            gap: '16px',
            border: StorageService.isSupporter() ? '1px solid rgba(250, 45, 120, 0.3)' : '1px solid rgba(255, 255, 255, 0.06)',
            boxShadow: StorageService.isSupporter() 
              ? '0 0 25px rgba(250, 45, 120, 0.15)' 
              : '0 8px 32px 0 rgba(0, 0, 0, 0.3)',
            transition: 'all 0.3s ease-in-out'
          }}
        >
          {/* Avatar with Backlit Neon Halo Glow */}
          <div style={{
            width: '60px',
            height: '60px',
            borderRadius: '50%',
            background: StorageService.isSupporter() 
              ? 'linear-gradient(135deg, #FF2E93 0%, #A259FF 100%)' 
              : 'linear-gradient(135deg, #00D4FF 0%, #0575E6 100%)',
            boxShadow: `0 0 15px ${StorageService.isSupporter() ? 'rgba(250, 45, 120, 0.4)' : 'rgba(0, 212, 255, 0.3)'}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#fff',
            fontSize: '24px',
            fontWeight: 'bold',
            flexShrink: 0
          }}>
            {(userName || 'G').charAt(0).toUpperCase()}
          </div>
          
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{ fontSize: '18px', fontWeight: 800, color: '#fff', letterSpacing: '-0.5px' }}>{userName}</span>
              {StorageService.isSupporter() && (
                <div style={{
                  padding: '2px 8px',
                  borderRadius: '8px',
                  backgroundColor: 'rgba(250, 45, 120, 0.15)',
                  border: '1px solid rgba(250, 45, 120, 0.3)',
                  color: '#FF2E93',
                  fontSize: '9px',
                  fontWeight: 900,
                  letterSpacing: '0.5px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px'
                }}>
                  SUPPORTER 💖
                </div>
              )}
            </div>
            <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
              {StorageService.isSupporter() ? 'Thank you for supporting Rotty!' : 'Free Music Listener'}
            </span>
          </div>
        </div>
      )}

      {/* Supporter Banner / Action */}
      {!StorageService.isSupporter() && (
        <div 
          className="liquid-glass-interactive" 
          onClick={() => setActiveTab(5)}
          style={{ 
            padding: '20px', 
            borderRadius: '20px', 
            background: 'linear-gradient(135deg, rgba(250, 45, 120, 0.08) 0%, rgba(162, 89, 255, 0.08) 100%)',
            border: '1px solid rgba(250, 45, 120, 0.25)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '16px',
            cursor: 'pointer',
            boxShadow: '0 8px 32px 0 rgba(250, 45, 120, 0.05)',
            transition: 'transform 0.2s ease-in-out'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <div style={{
              width: '44px',
              height: '44px',
              borderRadius: '50%',
              background: 'rgba(250, 45, 120, 0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#FF2E93',
              flexShrink: 0
            }}>
              <Heart size={20} fill="#FF2E93" />
            </div>
            <div>
              <h3 style={{ fontSize: '15px', fontWeight: 800, color: '#fff', margin: 0 }}>Support Rotty Music 💖</h3>
              <p style={{ fontSize: '12px', color: 'var(--text-secondary)', margin: '4px 0 0 0' }}>
                Unlock a permanent Supporter Badge and glowing profile aesthetics for ₹99!
              </p>
            </div>
          </div>
          <button 
            style={{
              background: '#FF2E93',
              border: 'none',
              borderRadius: '10px',
              color: '#fff',
              padding: '8px 16px',
              fontSize: '12px',
              fontWeight: 700,
              cursor: 'pointer',
              boxShadow: '0 4px 12px rgba(250, 45, 120, 0.3)',
              flexShrink: 0
            }}
          >
            Support Now
          </button>
        </div>
      )}

      {/* Setting 1: Cloud Sync & Account */}
      <div className="liquid-glass" style={{ padding: '24px', borderRadius: '14px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <CloudLightning size={20} style={{ color: 'var(--accent)' }} />
          <h2 style={{ fontSize: '18px', fontWeight: 700 }}>Rotty Connect & Cloud Sync</h2>
        </div>
        <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
          Link this device to your premium cloud account to synchronize your likes, streak data, playlists, and control active devices.
        </p>
        
        {isLoggedIn ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', background: 'rgba(0,0,0,0.2)', padding: '16px', borderRadius: '10px', marginTop: '8px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <User size={18} style={{ color: 'var(--accent)' }} />
              <div>
                <span style={{ fontSize: '14px', fontWeight: 700, display: 'block' }}>{userName}</span>
                <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{userEmail}</span>
              </div>
            </div>
            <button
              onClick={handleSignOut}
              className="liquid-glass-interactive"
              style={{
                alignSelf: 'flex-start',
                background: 'rgba(250, 45, 72, 0.08)',
                border: '1px solid rgba(250, 45, 72, 0.25)',
                borderRadius: '8px',
                color: '#fa2d48',
                padding: '8px 16px',
                fontSize: '12px',
                fontWeight: 600,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                marginTop: '4px'
              }}
            >
              <LogOut size={12} />
              <span>Sign Out Account</span>
            </button>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.04)', padding: '16px', borderRadius: '10px', marginTop: '8px' }}>
            <span style={{ fontSize: '13px', fontWeight: 500, color: 'var(--text-secondary)' }}>
              Currently in Offline Mode (Localhost cache only)
            </span>
            <button
              onClick={onOpenAuth}
              className="liquid-glass-interactive"
              style={{
                alignSelf: 'flex-start',
                background: 'var(--accent)',
                border: 'none',
                borderRadius: '8px',
                color: 'var(--bg-deep)',
                padding: '10px 20px',
                fontSize: '13px',
                fontWeight: 700,
                cursor: 'pointer',
                boxShadow: '0 4px 12px rgba(250, 45, 72, 0.2)'
              }}
            >
              Sign In / Sync Account
            </button>
          </div>
        )}
      </div>

      {/* Setting 2: Cache management */}
      <div className="liquid-glass" style={{ padding: '24px', borderRadius: '14px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <HardDrive size={20} style={{ color: 'var(--accent)' }} />
          <h2 style={{ fontSize: '18px', fontWeight: 700 }}>Local Storage & Diagnostics</h2>
        </div>
        <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
          Manage cached track history, liked files, and user collections.
        </p>

        {/* Diagnostics grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '12px', marginTop: '8px' }}>
          <div style={{ background: 'rgba(0,0,0,0.2)', padding: '12px', borderRadius: '8px', textAlign: 'center' }}>
            <span style={{ fontSize: '18px', fontWeight: 800, color: 'var(--accent)' }}>{metrics.liked}</span>
            <span style={{ display: 'block', fontSize: '10px', color: 'var(--text-secondary)', textTransform: 'uppercase', marginTop: '4px' }}>Liked Tracks</span>
          </div>
          <div style={{ background: 'rgba(0,0,0,0.2)', padding: '12px', borderRadius: '8px', textAlign: 'center' }}>
            <span style={{ fontSize: '18px', fontWeight: 800, color: 'var(--accent)' }}>{metrics.playlists}</span>
            <span style={{ display: 'block', fontSize: '10px', color: 'var(--text-secondary)', textTransform: 'uppercase', marginTop: '4px' }}>Playlists</span>
          </div>
          <div style={{ background: 'rgba(0,0,0,0.2)', padding: '12px', borderRadius: '8px', textAlign: 'center' }}>
            <span style={{ fontSize: '18px', fontWeight: 800, color: 'var(--accent)' }}>{metrics.history}</span>
            <span style={{ display: 'block', fontSize: '10px', color: 'var(--text-secondary)', textTransform: 'uppercase', marginTop: '4px' }}>Cache Queue</span>
          </div>
        </div>

        {/* Clear cache button */}
        <button
          onClick={handleClearCache}
          className="liquid-glass-interactive"
          style={{
            alignSelf: 'flex-start',
            marginTop: '8px',
            background: 'rgba(250, 45, 72, 0.1)',
            border: '1px solid rgba(250, 45, 72, 0.3)',
            color: '#fa2d48',
            fontWeight: 600,
            fontSize: '13px',
            padding: '10px 20px',
            borderRadius: '8px',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: '8px'
          }}
        >
          {clearing ? <RefreshCw size={14} className="spin-animation" style={{ animation: 'spin 1s linear infinite' }} /> : null}
          <span>Clear Local Storage Cache</span>
        </button>
      </div>

      {/* Setting 3: About */}
      <div className="liquid-glass" style={{ padding: '24px', borderRadius: '14px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <HelpCircle size={20} style={{ color: 'var(--accent)' }} />
          <h2 style={{ fontSize: '18px', fontWeight: 700 }}>About Web Player</h2>
        </div>
        <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: '1.5' }}>
          This is an exclusive local web reproduction of the premium Windows client for Rotty Music. Built with React, TypeScript, and high-performance Web Audio filters, running on custom secure public nodes.
        </p>
        <div style={{ display: 'flex', gap: '24px', marginTop: '8px', fontSize: '12px', color: 'var(--text-tertiary)' }}>
          <span>Version: 1.2.0-web</span>
          <span>Target: Web/Localhost</span>
          <span>Signature: Kartik AI Dev Team</span>
        </div>
      </div>

    </div>
  );
};
