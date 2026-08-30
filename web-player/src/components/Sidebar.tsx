import React from 'react';
import { Home, Search, Music, Sliders, Settings, LogIn, Heart } from 'lucide-react';
import { StorageService } from '../services/storage';

interface SidebarProps {
  activeTab: number;
  setActiveTab: (index: number) => void;
  onOpenAuth: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ activeTab, setActiveTab, onOpenAuth }) => {
  const navItems = [
    { icon: Home, label: 'Home', index: 0 },
    { icon: Search, label: 'Search', index: 1 },
    { icon: Music, label: 'Library', index: 2 },
    { icon: Sliders, label: 'Rotty Labs', index: 3 },
    { icon: Settings, label: 'Settings', index: 4 },
    { icon: Heart, label: 'Support Rotty', index: 5 }
  ];

  return (
    <aside
      className="sidebar-shell liquid-glass"
      style={{
        width: '240px',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        padding: '24px 16px',
        borderRadius: '0 16px 16px 0',
        zIndex: 10,
        flexShrink: 0
      }}
    >
      {/* App Watermark branding */}
      <div style={{ padding: '8px 12px', marginBottom: '32px' }}>
        <h2
          className="shimmer-text"
          style={{
            fontFamily: 'var(--font-heading)',
            fontSize: '22px',
            fontWeight: 900,
            letterSpacing: '1px',
            textTransform: 'uppercase'
          }}
        >
          Rotty Music
        </h2>
        <span
          style={{
            fontSize: '9px',
            fontWeight: 700,
            color: 'var(--text-tertiary)',
            letterSpacing: '3px',
            textTransform: 'uppercase',
            display: 'block',
            marginTop: '4px'
          }}
        >
          Premium Web Edition
        </span>
      </div>

      {/* Nav list */}
      <nav style={{ display: 'flex', flexDirection: 'column', gap: '8px', flex: 1 }}>
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.index;

          return (
            <button
              key={item.index}
              onClick={() => setActiveTab(item.index)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '16px',
                width: '100%',
                padding: '12px 16px',
                background: isActive ? 'rgba(255, 255, 255, 0.06)' : 'transparent',
                border: 'none',
                borderLeft: isActive ? '3px solid var(--accent)' : '3px solid transparent',
                borderRadius: '8px',
                color: isActive ? 'var(--accent)' : 'var(--text-secondary)',
                fontFamily: 'var(--font-sans)',
                fontSize: '14px',
                fontWeight: isActive ? 600 : 500,
                textAlign: 'left',
                cursor: 'pointer',
                transition: 'all 0.2s cubic-bezier(0.4, 0, 0.2, 1)'
              }}
              onMouseEnter={(e) => {
                if (!isActive) {
                  e.currentTarget.style.color = 'var(--text-primary)';
                  e.currentTarget.style.background = 'rgba(255, 255, 255, 0.03)';
                }
              }}
              onMouseLeave={(e) => {
                if (!isActive) {
                  e.currentTarget.style.color = 'var(--text-secondary)';
                  e.currentTarget.style.background = 'transparent';
                }
              }}
            >
              <Icon size={18} style={{ strokeWidth: isActive ? 2.5 : 2 }} />
              <span>{item.label}</span>
            </button>
          );
        })}
      </nav>

      {/* Footer profile info */}
      <div 
        onClick={() => {
          const isLoggedIn = !!localStorage.getItem('rotty_user_uid');
          if (isLoggedIn) {
            if (window.confirm('Do you want to sign out from Rotty Connect?')) {
              StorageService.clearUserSession();
              window.location.reload();
            }
          } else {
            onOpenAuth();
          }
        }}
        className="liquid-glass-interactive"
        style={{ 
          padding: '12px', 
          borderTop: StorageService.isSupporter() ? '1px solid rgba(250, 45, 120, 0.25)' : '1px solid rgba(255, 255, 255, 0.05)',
          cursor: 'pointer',
          display: 'flex',
          flexDirection: 'column',
          gap: '4px',
          borderRadius: '8px',
          boxShadow: StorageService.isSupporter() ? '0 0 15px rgba(250, 45, 120, 0.12)' : 'none',
          background: StorageService.isSupporter() ? 'rgba(250, 45, 120, 0.03)' : 'transparent',
          transition: 'all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1)'
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          {localStorage.getItem('rotty_user_uid') ? (
            <>
              {/* Circular initial avatar with backlit neon halo */}
              <div style={{
                width: '32px',
                height: '32px',
                borderRadius: '50%',
                background: StorageService.isSupporter() 
                  ? 'linear-gradient(135deg, #FF2E93 0%, #A259FF 100%)' 
                  : 'linear-gradient(135deg, #00D4FF 0%, #0575E6 100%)',
                boxShadow: `0 0 10px ${StorageService.isSupporter() ? 'rgba(250, 45, 120, 0.4)' : 'rgba(0, 212, 255, 0.3)'}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#fff',
                fontSize: '12px',
                fontWeight: 'bold',
                flexShrink: 0
              }}>
                {(localStorage.getItem('rotty_user_name') || 'C').charAt(0).toUpperCase()}
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden', flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <span style={{ fontSize: '12px', fontWeight: 700, color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {localStorage.getItem('rotty_user_name') || 'Creator'}
                  </span>
                  {StorageService.isSupporter() && (
                    <span style={{ color: '#FF2E93', display: 'inline-flex', alignItems: 'center', flexShrink: 0 }} title="Verified Supporter">
                      <svg viewBox="0 0 24 24" width="12" height="12" fill="currentColor"><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10 10-4.5 10-10S17.5 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>
                    </span>
                  )}
                </div>
                <span style={{ fontSize: '9px', color: StorageService.isSupporter() ? '#FF2E93' : 'var(--text-tertiary)', fontWeight: StorageService.isSupporter() ? 800 : 500 }}>
                  {StorageService.isSupporter() ? 'Supporter 💖' : 'Free Account'}
                </span>
              </div>
            </>
          ) : (
            <>
              <LogIn size={14} style={{ color: 'var(--text-secondary)' }} />
              <span style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-secondary)' }}>
                Sync Account
              </span>
            </>
          )}
        </div>
        <p style={{ fontSize: '8px', color: 'var(--text-tertiary)', marginTop: '2px', alignSelf: 'flex-start' }}>
          v1.3.0-web
        </p>
      </div>
    </aside>
  );
};
