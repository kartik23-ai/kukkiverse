import React, { useState, useEffect } from 'react';
import { Download, Share, X, Sparkles, Smartphone, PlusSquare, Info } from 'lucide-react';

export const PwaInstallPrompt: React.FC = () => {
  const [showPrompt, setShowPrompt] = useState<boolean>(false);
  const [deferredPrompt, setDeferredPrompt] = useState<any>(null);
  const [isIOS, setIsIOS] = useState<boolean>(false);
  const [isStandalone, setIsStandalone] = useState<boolean>(false);

  useEffect(() => {
    // 1. Check if already running in standalone mode (PWA installed and open)
    const checkStandalone = () => {
      const isStandaloneMode = 
        window.matchMedia('(display-mode: standalone)').matches || 
        (navigator as any).standalone === true ||
        document.referrer.includes('android-app://');
      setIsStandalone(isStandaloneMode);
      return isStandaloneMode;
    };

    // 2. Detect iOS
    const detectIOS = () => {
      const userAgent = window.navigator.userAgent.toLowerCase();
      const isIpadOrIphone = /iphone|ipad|ipod/.test(userAgent) || 
        (navigator.maxTouchPoints > 0 && navigator.userAgent.includes('Macintosh'));
      setIsIOS(isIpadOrIphone);
      return isIpadOrIphone;
    };

    const isInstalled = checkStandalone();
    const ios = detectIOS();
    const isDismissed = localStorage.getItem('rotty_pwa_dismissed') === 'true';

    // 3. Listen for Android/Chrome beforeinstallprompt event
    const handleBeforeInstallPrompt = (e: Event) => {
      e.preventDefault();
      setDeferredPrompt(e);
      
      // If PWA is not installed, not dismissed, show the prompt after a small delay
      if (!isInstalled && !isDismissed) {
        setTimeout(() => {
          setShowPrompt(true);
        }, 4000); // 4 seconds delay to let splash/onboarding finish
      }
    };

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt);

    // 4. For iOS / Safari (which doesn't support beforeinstallprompt), we check status and show manually
    if (ios && !isInstalled && !isDismissed) {
      setTimeout(() => {
        setShowPrompt(true);
      }, 5000); // 5 seconds delay for iOS
    }

    // 5. Fallback for other browsers if install event doesn't fire but we want to prompt installation anyway
    // We only show it if the user is on mobile (to avoid showing it on normal desktop unless supported)
    const isMobileDevice = /android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(navigator.userAgent);
    if (isMobileDevice && !ios && !isInstalled && !isDismissed && !deferredPrompt) {
      const timer = setTimeout(() => {
        // Show fallback prompt if not dismissed
        if (localStorage.getItem('rotty_pwa_dismissed') !== 'true') {
          setShowPrompt(true);
        }
      }, 6000);
      return () => clearTimeout(timer);
    }

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
    };
  }, [deferredPrompt]);

  const handleInstallClick = async () => {
    if (!deferredPrompt) {
      // Fallback instruction if event is not captured yet
      alert('To install: Tap your browser settings (three dots in Chrome) and select "Add to Home Screen" or "Install App".');
      return;
    }
    
    // Show the browser install prompt
    deferredPrompt.prompt();
    
    // Wait for the user to respond to the prompt
    const { outcome } = await deferredPrompt.userChoice;
    console.log(`User response to install prompt: ${outcome}`);
    
    // Clear prompt state
    setDeferredPrompt(null);
    setShowPrompt(false);
    
    // Save state
    if (outcome === 'accepted') {
      localStorage.setItem('rotty_pwa_dismissed', 'true');
    }
  };

  const handleDismiss = () => {
    setShowPrompt(false);
    // Don't prompt the user again for this session/permanently
    localStorage.setItem('rotty_pwa_dismissed', 'true');
  };

  if (!showPrompt || isStandalone) return null;

  return (
    <div
      style={{
        position: 'fixed',
        bottom: '24px',
        left: '50%',
        transform: 'translateX(-50%)',
        width: '90%',
        maxWidth: '440px',
        zIndex: 9999,
        animation: 'pwa-slide-up 0.5s cubic-bezier(0.16, 1, 0.3, 1) forwards',
      }}
    >
      {/* CSS Animation Keyframes Inject */}
      <style>{`
        @keyframes pwa-slide-up {
          0% {
            transform: translate(-50%, 100px);
            opacity: 0;
          }
          100% {
            transform: translate(-50%, 0);
            opacity: 1;
          }
        }
        @keyframes pwa-pulse-glow {
          0%, 100% {
            box-shadow: 0 0 20px rgba(250, 45, 72, 0.15), 0 0 40px rgba(123, 97, 255, 0.1);
          }
          50% {
            box-shadow: 0 0 30px rgba(250, 45, 72, 0.3), 0 0 50px rgba(123, 97, 255, 0.25);
          }
        }
      `}</style>

      {/* Main Glassmorphic Container */}
      <div
        style={{
          background: 'rgba(15, 15, 20, 0.65)',
          backdropFilter: 'blur(28px) saturate(180%)',
          WebkitBackdropFilter: 'blur(28px) saturate(180%)',
          border: '1px solid rgba(255, 255, 255, 0.08)',
          borderRadius: '24px',
          padding: '22px',
          color: '#ffffff',
          boxShadow: '0 24px 64px rgba(0, 0, 0, 0.7)',
          animation: 'pwa-pulse-glow 4s infinite alternate',
          position: 'relative',
          overflow: 'hidden',
        }}
      >
        {/* Glow Accent Spots */}
        <div
          style={{
            position: 'absolute',
            top: '-20%',
            left: '-20%',
            width: '60%',
            height: '60%',
            borderRadius: '50%',
            background: 'radial-gradient(circle, rgba(250, 45, 72, 0.18) 0%, transparent 70%)',
            pointerEvents: 'none',
            zIndex: 0,
          }}
        />
        <div
          style={{
            position: 'absolute',
            bottom: '-20%',
            right: '-20%',
            width: '60%',
            height: '60%',
            borderRadius: '50%',
            background: 'radial-gradient(circle, rgba(123, 97, 255, 0.15) 0%, transparent 70%)',
            pointerEvents: 'none',
            zIndex: 0,
          }}
        />

        {/* Close Button */}
        <button
          onClick={handleDismiss}
          style={{
            position: 'absolute',
            top: '16px',
            right: '16px',
            background: 'rgba(255, 255, 255, 0.05)',
            border: '1px solid rgba(255, 255, 255, 0.08)',
            borderRadius: '50%',
            width: '28px',
            height: '28px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            color: 'rgba(255, 255, 255, 0.6)',
            transition: 'all 0.2s',
            zIndex: 10,
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.1)';
            e.currentTarget.style.color = '#fff';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.05)';
            e.currentTarget.style.color = 'rgba(255, 255, 255, 0.6)';
          }}
        >
          <X size={14} />
        </button>

        {/* Content */}
        <div style={{ position: 'relative', zIndex: 1 }}>
          {/* Header */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '14px' }}>
            <div
              style={{
                width: '40px',
                height: '40px',
                borderRadius: '12px',
                background: 'linear-gradient(135deg, var(--accent), var(--accent-soft))',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 4px 12px rgba(250, 45, 72, 0.3)',
              }}
            >
              <Smartphone size={20} style={{ color: '#fff' }} />
            </div>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <h3 style={{ margin: 0, fontSize: '16px', fontWeight: 700, letterSpacing: '-0.3px', color: '#fff' }}>
                  Install Rotty Music
                </h3>
                <Sparkles size={14} style={{ color: 'var(--accent-soft)', animation: 'bounce 2s infinite' }} />
              </div>
              <span style={{ fontSize: '11px', color: 'rgba(255, 255, 255, 0.5)', fontWeight: 500 }}>
                Get PWA App on your device
              </span>
            </div>
          </div>

          {/* Description */}
          <p style={{ margin: '0 0 16px 0', fontSize: '13px', lineHeight: '1.5', color: 'rgba(255, 255, 255, 0.8)' }}>
            App ko desktop ya mobile home screen par add karein aur payein <strong>0ms network lag</strong> ambient loop, offline mode, aur seamless premium player controls.
          </p>

          {/* Body: Conditional Layout depending on OS */}
          {isIOS ? (
            /* iOS Instructions Safari */
            <div
              style={{
                background: 'rgba(255, 255, 255, 0.03)',
                border: '1px solid rgba(255, 255, 255, 0.05)',
                borderRadius: '16px',
                padding: '14px',
                marginBottom: '16px',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '10px', fontSize: '12px', fontWeight: 600, color: 'var(--accent-soft)' }}>
                <Info size={14} />
                <span>iOS Safari Installation Steps:</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', fontSize: '12px', color: 'rgba(255, 255, 255, 0.8)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(255,255,255,0.08)', borderRadius: '6px', width: '24px', height: '24px', flexShrink: 0 }}>
                    1
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px', flexWrap: 'wrap' }}>
                    Safari browser toolbar me niche 
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: '2px', background: 'rgba(255,255,255,0.1)', padding: '2px 6px', borderRadius: '4px', fontSize: '11px', color: '#fff' }}>
                      <Share size={12} style={{ strokeWidth: 2 }} /> Share
                    </span> 
                    icon par tap karein.
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(255,255,255,0.08)', borderRadius: '6px', width: '24px', height: '24px', flexShrink: 0 }}>
                    2
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px', flexWrap: 'wrap' }}>
                    List ko scroll down karein aur 
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', background: 'rgba(255,255,255,0.1)', padding: '2px 6px', borderRadius: '4px', fontSize: '11px', color: '#fff' }}>
                      <PlusSquare size={12} /> Add to Home Screen
                    </span> 
                    choose karein.
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(255,255,255,0.08)', borderRadius: '6px', width: '24px', height: '24px', flexShrink: 0 }}>
                    3
                  </div>
                  <div>
                    Top right corner me <strong>"Add"</strong> button par tap karein.
                  </div>
                </div>
              </div>
            </div>
          ) : (
            /* Android/Chrome Button Install */
            <div style={{ display: 'flex', gap: '10px' }}>
              <button
                onClick={handleInstallClick}
                className="liquid-glass-interactive"
                style={{
                  flex: 1,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '8px',
                  background: 'linear-gradient(135deg, var(--accent), var(--accent-soft))',
                  border: 'none',
                  borderRadius: '16px',
                  padding: '14px',
                  color: '#fff',
                  fontSize: '13px',
                  fontWeight: 600,
                  cursor: 'pointer',
                  boxShadow: '0 4px 15px rgba(250, 45, 72, 0.25)',
                  transition: 'transform 0.2s, box-shadow 0.2s',
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'scale(1.02)';
                  e.currentTarget.style.boxShadow = '0 6px 20px rgba(250, 45, 72, 0.4)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'scale(1)';
                  e.currentTarget.style.boxShadow = '0 4px 15px rgba(250, 45, 72, 0.25)';
                }}
              >
                <Download size={16} />
                <span>Install Rotty Music</span>
              </button>
              
              <button
                onClick={handleDismiss}
                style={{
                  background: 'rgba(255, 255, 255, 0.05)',
                  border: '1px solid rgba(255, 255, 255, 0.08)',
                  borderRadius: '16px',
                  padding: '14px 20px',
                  color: 'rgba(255, 255, 255, 0.8)',
                  fontSize: '13px',
                  fontWeight: 600,
                  cursor: 'pointer',
                  transition: 'background 0.2s, color 0.2s',
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = 'rgba(255, 255, 255, 0.1)';
                  e.currentTarget.style.color = '#fff';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = 'rgba(255, 255, 255, 0.05)';
                  e.currentTarget.style.color = 'rgba(255, 255, 255, 0.8)';
                }}
              >
                Later
              </button>
            </div>
          )}

          {/* Footer note */}
          {isIOS && (
            <div style={{ display: 'flex', justifyContent: 'center', marginTop: '12px' }}>
              <button
                onClick={handleDismiss}
                style={{
                  background: 'transparent',
                  border: 'none',
                  color: 'rgba(255, 255, 255, 0.4)',
                  fontSize: '12px',
                  fontWeight: 500,
                  cursor: 'pointer',
                  textDecoration: 'underline',
                }}
                onMouseEnter={(e) => e.currentTarget.style.color = 'rgba(255, 255, 255, 0.7)'}
                onMouseLeave={(e) => e.currentTarget.style.color = 'rgba(255, 255, 255, 0.4)'}
              >
                I understand, hide this prompt
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
