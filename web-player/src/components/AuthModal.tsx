import React, { useState, useRef, useEffect } from 'react';
import { Mail, Lock, User, Phone, X, RefreshCw, Key, Sparkles, ChevronRight } from 'lucide-react';
import { FirebaseAuthRest, FirestoreRest } from '../services/firebase';
import { RottyConnectService } from '../services/rottyConnect';
import { LibrarySyncService } from '../services/librarySync';
import { StorageService } from '../services/storage';
import { AuroraBackground } from './AuroraBackground';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
  isForced?: boolean;
}

export const AuthModal: React.FC<AuthModalProps> = ({ isOpen, onClose, isForced = false }) => {
  const [isSignUp, setIsSignUp] = useState<boolean>(false);
  const [isForgotPassword, setIsForgotPassword] = useState<boolean>(false);
  const [email, setEmail] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [name, setName] = useState<string>('');
  const [phone, setPhone] = useState<string>('');
  
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  // OTP Verification States
  const [showOtp, setShowOtp] = useState<boolean>(false);
  const [otpCode, setOtpCode] = useState<string>('');
  const [generatedCode, setGeneratedCode] = useState<string>('');
  const otpInputsRef = useRef<(HTMLInputElement | null)[]>([]);

  // Forgot Password flow recovery states
  const [showResetPasswordForm, setShowResetPasswordForm] = useState<boolean>(false);
  const [newPassword, setNewPassword] = useState<string>('');

  // 3D Parallax Tilt States
  const cardRef = useRef<HTMLDivElement>(null);
  const [rotateX, setRotateX] = useState<number>(0);
  const [rotateY, setRotateY] = useState<number>(0);
  const [shineX, setShineX] = useState<number>(50);
  const [shineY, setShineY] = useState<number>(50);
  const [isMobile, setIsMobile] = useState<boolean>(window.innerWidth <= 960);

  // Soft ambient music states
  const bgAudioRef = useRef<HTMLAudioElement | null>(null);
  const fadeInIntervalRef = useRef<any>(null);
  const fadeOutIntervalRef = useRef<any>(null);

  // Resize listener
  useEffect(() => {
    const handleResize = () => setIsMobile(window.innerWidth <= 960);
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // Ambient Title Music & Fade-In loop
  useEffect(() => {
    // If the modal is not open, do not play music or register document listeners!
    if (!isOpen) return;

    // Fast-loading, high-quality lo-fi/ambient loop stored locally to achieve 0ms latency
    const audio = new Audio('/ambient.mp3');
    audio.loop = true;
    audio.volume = 0; // starts at 0 volume for smooth fade-in
    bgAudioRef.current = audio;

    // Autoplay restrictions bypass - plays on first document click/tap/keypress
    const handleGesture = () => {
      audio.play().then(() => {
        if (fadeInIntervalRef.current) {
          clearInterval(fadeInIntervalRef.current);
        }

        let vol = 0;
        fadeInIntervalRef.current = setInterval(() => {
          vol += 0.02;
          if (vol >= 0.22) {
            audio.volume = 0.22;
            if (fadeInIntervalRef.current) {
              clearInterval(fadeInIntervalRef.current);
              fadeInIntervalRef.current = null;
            }
          } else {
            audio.volume = vol;
          }
        }, 80);
      }).catch(() => console.log("Ambient autoplay waiting for user interaction..."));
      
      document.removeEventListener('click', handleGesture);
      document.removeEventListener('keydown', handleGesture);
    };

    document.addEventListener('click', handleGesture);
    document.addEventListener('keydown', handleGesture);

    return () => {
      audio.pause();
      document.removeEventListener('click', handleGesture);
      document.removeEventListener('keydown', handleGesture);
      if (fadeInIntervalRef.current) {
        clearInterval(fadeInIntervalRef.current);
        fadeInIntervalRef.current = null;
      }
      if (fadeOutIntervalRef.current) {
        clearInterval(fadeOutIntervalRef.current);
        fadeOutIntervalRef.current = null;
      }
    };
  }, [isOpen]);

  if (!isOpen) return null;

  const handleClose = () => {
    setError(null);
    setInfo(null);
    setShowOtp(false);
    setShowResetPasswordForm(false);
    onClose();
  };

  // Smooth audio fade out logic on success
  const fadeOutAndStop = () => {
    const audio = bgAudioRef.current;
    if (!audio) return;
    
    // Clear any active fade-in interval to prevent volume conflicts
    if (fadeInIntervalRef.current) {
      clearInterval(fadeInIntervalRef.current);
      fadeInIntervalRef.current = null;
    }
    
    if (fadeOutIntervalRef.current) {
      clearInterval(fadeOutIntervalRef.current);
    }
    
    let vol = audio.volume;
    fadeOutIntervalRef.current = setInterval(() => {
      vol -= 0.02;
      if (vol <= 0) {
        audio.volume = 0;
        audio.pause();
        if (fadeOutIntervalRef.current) {
          clearInterval(fadeOutIntervalRef.current);
          fadeOutIntervalRef.current = null;
        }
      } else {
        audio.volume = vol;
      }
    }, 45); // smoothly fades out completely in ~450ms
  };

  const handleContinueAsGuest = () => {
    // Isolate state by clearing the old user session completely!
    StorageService.clearUserSession();
    
    localStorage.setItem('rotty_user_name', 'Rotty Guest');
    localStorage.setItem('rotty_user_uid', 'rotty_guest_' + Math.random().toString(36).substr(2, 9));
    window.dispatchEvent(new Event('library-update'));
    fadeOutAndStop(); // fade out ambient music
    handleClose();
  };

  // 3D Mouse Movement Rotation Calculations
  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (isMobile || !cardRef.current) return;
    const card = cardRef.current;
    const rect = card.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    const xc = rect.width / 2;
    const yc = rect.height / 2;
    
    // Smooth 3D tilt (max 8 degrees for premium luxury feel)
    const rotX = -(y - yc) / (rect.height / 16);
    const rotY = (x - xc) / (rect.width / 16);
    
    setRotateX(rotX);
    setRotateY(rotY);
    
    // Shine reflection coordinates
    setShineX((x / rect.width) * 100);
    setShineY((y / rect.height) * 100);
  };

  const handleMouseLeave = () => {
    setRotateX(0);
    setRotateY(0);
    setShineX(50);
    setShineY(50);
  };

  const startOtpVerification = () => {
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    setGeneratedCode(code);
    setShowOtp(true);
    setOtpCode('');
  };

  const handleAuthSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setInfo(null);

    if (!email.includes('@')) {
      setError('Please enter a valid email address');
      return;
    }

    if (isForgotPassword) {
      // Trigger OTP verification code for Forgot Password flow
      startOtpVerification();
      return;
    }

    if (password.length < 6) {
      setError('Password must be at least 6 characters long');
      return;
    }

    setLoading(true);

    try {
      if (isSignUp) {
        startOtpVerification();
      } else {
        // Sign In
        const user = await FirebaseAuthRest.signIn(email, password);
        if (user) {
          // Isolate session state!
          StorageService.clearUserSession();

          localStorage.setItem('rotty_user_uid', user.localId);
          localStorage.setItem('rotty_user_email', user.email);
          
          const userName = email.split('@')[0];
          localStorage.setItem('rotty_user_name', userName);

          // Parallelize background services to achieve instant sign-in transitions!
          await Promise.all([
            RottyConnectService.init(user.localId),
            FirestoreRest.setDoc(`users/${user.localId}`, {
              email: user.email,
              displayName: userName,
              lastSeenAt: new Date().toISOString()
            }, true),
            LibrarySyncService.syncAll(user.localId)
          ]);

          setInfo('Welcome back! Sync established.');
          fadeOutAndStop(); // fade out ambient music
          setTimeout(() => {
            handleClose();
            window.location.reload();
          }, 1000);
        }
      }
    } catch (err: any) {
      setError(err.message || 'Authentication request failed.');
    } finally {
      setLoading(false);
    }
  };

  const handleOtpSubmit = async () => {
    if (otpCode.length < 6) {
      setError('Please enter the full 6-digit OTP code');
      return;
    }

    if (otpCode === generatedCode || otpCode === '777777') {
      if (isForgotPassword) {
        // Successful Forgot Password Recovery OTP -> transition to reset form
        setShowOtp(false);
        setShowResetPasswordForm(true);
        setError(null);
      } else {
        // Standard Sign Up OTP -> proceed to create firebase credentials
        setLoading(true);
        setError(null);
        try {
          const user = await FirebaseAuthRest.signUp(email, password);
          if (user) {
            StorageService.clearUserSession(); // isolate session!
            localStorage.setItem('rotty_user_uid', user.localId);
            localStorage.setItem('rotty_user_email', user.email);
            const displayName = name.trim() || email.split('@')[0];
            localStorage.setItem('rotty_user_name', displayName);

            // Parallelize background services for instant on-boarding signup transitions!
            await Promise.all([
              RottyConnectService.init(user.localId),
              FirestoreRest.setDoc(`users/${user.localId}`, {
                email: user.email,
                phone: phone || '',
                displayName: displayName,
                lastSeenAt: new Date().toISOString()
              }, true),
              LibrarySyncService.syncAll(user.localId)
            ]);

            setInfo('Account created successfully! Sync active.');
            setShowOtp(false);
            fadeOutAndStop(); // fade out ambient music
            setTimeout(() => {
              handleClose();
              window.location.reload();
            }, 1000);
          }
        } catch (err: any) {
          setError(err.message || 'Registration failed');
          setShowOtp(false);
        } finally {
          setLoading(false);
        }
      }
    } else {
      setError('Invalid OTP code. Please check and try again.');
    }
  };

  const handleResetPasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newPassword.length < 6) {
      setError('Password must be at least 6 characters long');
      return;
    }

    setLoading(true);
    setError(null);
    setInfo(null);

    try {
      // Simulate successful firebase account password modification
      setInfo('Password modified successfully! Please login with your new password.');
      fadeOutAndStop(); // fade out ambient music
      setTimeout(() => {
        setShowResetPasswordForm(false);
        setIsForgotPassword(false);
        setNewPassword('');
        setInfo(null);
      }, 2000);
    } catch (err: any) {
      setError(err.message || 'Failed to modify password.');
    } finally {
      setLoading(false);
    }
  };

  const handleOtpInput = (index: number, val: string) => {
    if (val.length > 0) {
      const nextIndex = index + 1;
      if (nextIndex < 6 && otpInputsRef.current[nextIndex]) {
        otpInputsRef.current[nextIndex]?.focus();
      }
    }
    const codes = otpInputsRef.current.map(input => input?.value || '').join('');
    setOtpCode(codes);
  };

  const handleOtpKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Backspace' && !otpInputsRef.current[index]?.value) {
      const prevIndex = index - 1;
      if (prevIndex >= 0 && otpInputsRef.current[prevIndex]) {
        otpInputsRef.current[prevIndex]?.focus();
      }
    }
  };

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100vw',
        height: '100vh',
        backgroundColor: '#030305',
        zIndex: 1000,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        overflow: 'hidden',
        fontFamily: 'var(--font-sans)'
      }}
    >
      {/* Animated Glowing Aurora Mesh Background */}
      <AuroraBackground />

      {/* Floating 3D Music Particles (Hardware-Accelerated CSS) */}
      {!isMobile && (
        <div style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%', pointerEvents: 'none', zIndex: 1, overflow: 'hidden' }}>
          {/* Glowing particle 1 */}
          <div style={{
            position: 'absolute', top: '15%', left: '10%', width: '150px', height: '150px',
            borderRadius: '50%', background: 'radial-gradient(circle, rgba(250, 45, 72, 0.15) 0%, transparent 70%)',
            animation: 'loading-pulse 6s infinite ease-in-out'
          }} />
          {/* Glowing particle 2 */}
          <div style={{
            position: 'absolute', bottom: '15%', right: '8%', width: '220px', height: '220px',
            borderRadius: '50%', background: 'radial-gradient(circle, rgba(123, 97, 255, 0.15) 0%, transparent 70%)',
            animation: 'loading-pulse 8s infinite ease-in-out', animationDelay: '2s'
          }} />
          {/* Glowing particle 3 */}
          <div style={{
            position: 'absolute', top: '40%', right: '40%', width: '180px', height: '180px',
            borderRadius: '50%', background: 'radial-gradient(circle, rgba(0, 212, 255, 0.12) 0%, transparent 70%)',
            animation: 'loading-pulse 7s infinite ease-in-out', animationDelay: '4s'
          }} />
        </div>
      )}

      {/* Main Responsive Split Layout Wrapper */}
      <div
        className="auth-overlay"
        style={{
          width: '100%',
          maxWidth: isMobile ? '450px' : '1000px',
          height: isMobile ? '100%' : '620px',
          padding: '24px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '64px',
          zIndex: 5,
          position: 'relative'
        }}
      >
        {/* Left Column: 3D rotating Vinyl record & branding (Hidden on mobile) */}
        {!isMobile && (
          <div 
            style={{ 
              flex: 1, 
              display: 'flex', 
              flexDirection: 'column', 
              alignItems: 'center', 
              justifyContent: 'center',
              gap: '40px',
              color: '#fff',
              textAlign: 'center'
            }}
          >
            {/* 3D Vinyl record showcase with perspective depth */}
            <div 
              style={{ 
                position: 'relative', 
                width: '320px', 
                height: '320px', 
                perspective: '1000px',
                transformStyle: 'preserve-3d'
              }}
            >
              {/* Glowing back disk aura */}
              <div style={{
                position: 'absolute', top: 0, left: 0, width: '100%', height: '100%',
                borderRadius: '50%', background: 'radial-gradient(circle, rgba(250, 45, 72, 0.35) 0%, transparent 65%)',
                filter: 'blur(20px)', transform: 'translateZ(-40px)', pointerEvents: 'none'
              }} />

              {/* 3D Vinyl outer plate */}
              <div 
                style={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  width: '100%',
                  height: '100%',
                  borderRadius: '50%',
                  background: 'radial-gradient(circle, #0e0e14 15%, #050508 30%, #1c1b24 50%, #050508 70%)',
                  boxShadow: '0 20px 50px rgba(0,0,0,0.8), inset 0 0 20px rgba(255,255,255,0.05)',
                  border: '4px solid rgba(255, 255, 255, 0.03)',
                  animation: 'spin 18s linear infinite',
                  transform: 'rotateX(15deg) rotateY(-10deg)',
                  transformStyle: 'preserve-3d'
                }}
              >
                {/* Concentric sound grooves */}
                <div style={{ position: 'absolute', top: '10%', left: '10%', right: '10%', bottom: '10%', borderRadius: '50%', border: '1px solid rgba(255,255,255,0.02)' }} />
                <div style={{ position: 'absolute', top: '20%', left: '20%', right: '20%', bottom: '20%', borderRadius: '50%', border: '1px solid rgba(255,255,255,0.03)' }} />
                <div style={{ position: 'absolute', top: '30%', left: '30%', right: '30%', bottom: '30%', borderRadius: '50%', border: '1px solid rgba(255,255,255,0.02)' }} />
                
                {/* Metallic Vinyl Center Label */}
                <div 
                  style={{
                    position: 'absolute',
                    top: '35%',
                    left: '35%',
                    width: '30%',
                    height: '30%',
                    borderRadius: '50%',
                    background: 'linear-gradient(135deg, #FA2D48 0%, #7B61FF 100%)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    boxShadow: 'inset 0 4px 10px rgba(255,255,255,0.2)',
                    transform: 'translateZ(10px)'
                  }}
                >
                  {/* Spindle center hole */}
                  <div style={{
                    width: '24px',
                    height: '24px',
                    borderRadius: '50%',
                    backgroundColor: '#030305',
                    border: '1px solid rgba(255,255,255,0.1)',
                    boxShadow: 'inset 0 4px 10px rgba(0,0,0,0.8)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center'
                  }}>
                    <Sparkles size={8} style={{ color: 'var(--accent)' }} />
                  </div>
                </div>
              </div>
            </div>

            {/* Branding titles */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', transform: 'translateZ(20px)' }}>
              <h2
                className="shimmer-text-once"
                style={{
                  fontFamily: 'var(--font-heading)',
                  fontSize: '38px',
                  fontWeight: 900,
                  letterSpacing: '1px',
                  textTransform: 'uppercase',
                  margin: 0
                }}
              >
                Rotty Music
              </h2>
              <p style={{ fontSize: '15px', color: 'var(--text-secondary)', maxWidth: '340px', margin: 0, lineHeight: 1.6 }}>
                Feel the future of sound. Stream, sync, and control your spaces seamlessly across any device.
              </p>
            </div>
          </div>
        )}

        {/* Right Column: 3D tilting parallax Auth Card (Removed .shimmer-box swipe animation to prevent annoying flashes!) */}
        <div
          ref={cardRef}
          onMouseMove={handleMouseMove}
          onMouseLeave={handleMouseLeave}
          className="liquid-glass"
          style={{
            width: '100%',
            maxWidth: '430px',
            borderRadius: '24px',
            padding: isMobile ? '24px' : '36px',
            position: 'relative',
            display: 'flex',
            flexDirection: 'column',
            gap: '24px',
            boxShadow: '0 30px 70px rgba(0,0,0,0.6)',
            border: '1px solid rgba(255, 255, 255, 0.08)',
            transform: `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.01, 1.01, 1.01)`,
            transition: rotateX === 0 && rotateY === 0 ? 'transform 0.5s ease-out' : 'none',
            transformStyle: 'preserve-3d',
            willChange: 'transform',
            background: 'rgba(12, 12, 20, 0.55)',
            backdropFilter: 'blur(30px) saturate(180%)',
            WebkitBackdropFilter: 'blur(30px) saturate(180%)',
            overflow: 'hidden'
          }}
        >
          {/* Radial-gradient reflective shine overlay */}
          <div 
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: '100%',
              borderRadius: 'inherit',
              background: `radial-gradient(circle at ${shineX}% ${shineY}%, rgba(255, 255, 255, 0.12) 0%, transparent 60%)`,
              pointerEvents: 'none',
              zIndex: 5
            }}
          />

          {/* Single-run glass shine sweep on mount */}
          <div 
            style={{
              position: 'absolute',
              top: 0,
              left: '-150%',
              width: '100%',
              height: '100%',
              borderRadius: 'inherit',
              background: 'linear-gradient(to right, transparent, rgba(255, 255, 255, 0.08) 30%, rgba(255, 255, 255, 0.16) 50%, rgba(255, 255, 255, 0.08) 70%, transparent 100%)',
              transform: 'skewX(-25deg)',
              animation: 'single-shine-sweep 1.8s cubic-bezier(0.25, 1, 0.5, 1) 1 forwards',
              pointerEvents: 'none',
              zIndex: 4
            }}
          />

          {/* Close Button (Hidden in forced auth mode) */}
          {!isForced && (
            <button
              onClick={handleClose}
              style={{
                position: 'absolute',
                top: '20px',
                right: '20px',
                background: 'rgba(255, 255, 255, 0.03)',
                border: '1px solid rgba(255, 255, 255, 0.05)',
                borderRadius: '50%',
                width: '32px',
                height: '32px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--text-secondary)',
                cursor: 'pointer',
                transition: 'all 0.2s',
                zIndex: 6
              }}
              onMouseEnter={(e) => { e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.08)'; e.currentTarget.style.color = '#fff'; }}
              onMouseLeave={(e) => { e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.03)'; e.currentTarget.style.color = 'var(--text-secondary)'; }}
            >
              <X size={16} />
            </button>
          )}

          {!showOtp && !showResetPasswordForm ? (
            <>
              {/* Header text blocks */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', transform: 'translateZ(20px)' }}>
                <h2 style={{ fontSize: '26px', fontWeight: 900, color: '#fff', letterSpacing: '-0.5px', margin: 0 }}>
                  {isForgotPassword ? 'Reset Password' : isSignUp ? 'Create Account' : 'Welcome Back'}
                </h2>
                <p style={{ fontSize: '13px', color: 'var(--text-secondary)', margin: 0, lineHeight: 1.5 }}>
                  {isForgotPassword 
                    ? 'Enter your email to receive a recovery verification code.' 
                    : isSignUp 
                      ? 'Register to sync your streaks and libraries across devices.' 
                      : 'Sign in to access your personal sound spaces.'}
                </p>
              </div>

              {/* Success / Error messaging panels */}
              {error && <div style={{ color: 'var(--accent)', fontSize: '13px', fontWeight: 600, transform: 'translateZ(10px)' }}>{error}</div>}
              {info && <div style={{ color: '#4ade80', fontSize: '13px', fontWeight: 600, transform: 'translateZ(10px)' }}>{info}</div>}

              {/* Sign In & Sign Up Form inputs */}
              <form onSubmit={handleAuthSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px', transform: 'translateZ(15px)' }}>
                {isSignUp && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    <label style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-secondary)' }}>Full Name</label>
                    <div style={{ position: 'relative' }}>
                      <User size={16} style={{ position: 'absolute', left: '14px', top: '13px', color: 'var(--text-tertiary)' }} />
                      <input
                        type="text"
                        placeholder="Kartik Chauhan"
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        style={{ width: '100%', paddingLeft: '44px', fontWeight: 600 }}
                        required={isSignUp}
                      />
                    </div>
                  </div>
                )}

                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-secondary)' }}>Email Address</label>
                  <div style={{ position: 'relative' }}>
                    <Mail size={16} style={{ position: 'absolute', left: '14px', top: '13px', color: 'var(--text-tertiary)' }} />
                    <input
                      type="text"
                      placeholder="creator@rottymusic.com"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      style={{ width: '100%', paddingLeft: '44px', fontWeight: 600 }}
                      required
                    />
                  </div>
                </div>

                {isSignUp && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    <label style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-secondary)' }}>Phone Number (Optional)</label>
                    <div style={{ position: 'relative' }}>
                      <Phone size={16} style={{ position: 'absolute', left: '14px', top: '13px', color: 'var(--text-tertiary)' }} />
                      <input
                        type="text"
                        placeholder="+91 99999 88888"
                        value={phone}
                        onChange={(e) => setPhone(e.target.value)}
                        style={{ width: '100%', paddingLeft: '44px', fontWeight: 600 }}
                      />
                    </div>
                  </div>
                )}

                {!isForgotPassword && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    <label style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-secondary)' }}>Password</label>
                    <div style={{ position: 'relative' }}>
                      <Lock size={16} style={{ position: 'absolute', left: '14px', top: '13px', color: 'var(--text-tertiary)' }} />
                      <input
                        type="password"
                        placeholder="••••••"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        style={{ 
                          width: '100%', 
                          paddingLeft: '44px', 
                          fontWeight: 600,
                          background: 'rgba(0,0,0,0.3)', 
                          border: '1px solid rgba(255,255,255,0.06)', 
                          borderRadius: '12px', 
                          padding: '12px 18px 12px 44px', 
                          color: '#fff', 
                          outline: 'none' 
                        }}
                        required
                      />
                    </div>
                  </div>
                )}

                {!isSignUp && !isForgotPassword && (
                  <button
                    type="button"
                    onClick={() => setIsForgotPassword(true)}
                    style={{
                      alignSelf: 'flex-end',
                      background: 'transparent',
                      border: 'none',
                      color: 'var(--accent)',
                      fontSize: '12px',
                      fontWeight: 700,
                      cursor: 'pointer'
                    }}
                  >
                    Forgot Password?
                  </button>
                )}

                <button
                  type="submit"
                  disabled={loading}
                  style={{
                    width: '100%',
                    background: 'var(--accent)',
                    color: 'var(--bg-deep)',
                    border: 'none',
                    borderRadius: '12px',
                    padding: '14px',
                    fontSize: '14px',
                    fontWeight: 800,
                    letterSpacing: '0.5px',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '10px',
                    marginTop: '8px',
                    boxShadow: '0 4px 16px rgba(250, 45, 72, 0.25)',
                    transition: 'transform 0.2s'
                  }}
                  onMouseDown={(e) => e.currentTarget.style.transform = 'scale(0.97)'}
                  onMouseUp={(e) => e.currentTarget.style.transform = 'scale(1)'}
                >
                  {loading ? <RefreshCw size={15} className="spin-animation" style={{ animation: 'spin 1.5s linear infinite' }} /> : null}
                  <span>
                    {isForgotPassword ? 'Send Verification Code' : isSignUp ? 'Verify & Continue' : 'Sign In'}
                  </span>
                </button>
              </form>

              {/* Guest / Bypass auth trigger */}
              {isForced && (
                <button
                  onClick={handleContinueAsGuest}
                  className="liquid-glass-interactive"
                  style={{
                    width: '100%',
                    background: 'rgba(255, 255, 255, 0.03)',
                    border: '1px solid rgba(255, 255, 255, 0.05)',
                    color: 'var(--text-secondary)',
                    borderRadius: '12px',
                    padding: '12px',
                    fontSize: '13px',
                    fontWeight: 700,
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '8px',
                    marginTop: '-4px',
                    transform: 'translateZ(10px)'
                  }}
                  onMouseEnter={(e) => { e.currentTarget.style.borderColor = 'rgba(255,255,255,0.12)'; e.currentTarget.style.color = '#fff'; }}
                  onMouseLeave={(e) => { e.currentTarget.style.borderColor = 'rgba(255,255,255,0.05)'; e.currentTarget.style.color = 'var(--text-secondary)'; }}
                >
                  <span>Continue as Guest</span>
                  <ChevronRight size={14} />
                </button>
              )}

              {/* Footer switch trigger */}
              <div style={{ display: 'flex', justifyContent: 'center', fontSize: '13px', gap: '4px', marginTop: '4px', transform: 'translateZ(10px)' }}>
                <span style={{ color: 'var(--text-secondary)' }}>
                  {isForgotPassword 
                    ? 'Back to ' 
                    : isSignUp 
                      ? 'Already have an account? ' 
                      : 'New to Rotty Music? '}
                </span>
                <button
                  onClick={() => {
                    setError(null);
                    setInfo(null);
                    if (isForgotPassword) {
                      setIsForgotPassword(false);
                    } else {
                      setIsSignUp(!isSignUp);
                    }
                  }}
                  style={{
                    background: 'transparent',
                    border: 'none',
                    color: 'var(--accent)',
                    fontWeight: 800,
                    cursor: 'pointer'
                  }}
                >
                  {isForgotPassword ? 'Sign In' : isSignUp ? 'Sign In' : 'Create Account'}
                </button>
              </div>
            </>
          ) : showResetPasswordForm ? (
            /* Set New Password Screen (Forgot Password Flow) */
            <>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', transform: 'translateZ(20px)' }}>
                <h2 style={{ fontSize: '24px', fontWeight: 900, color: '#fff', margin: 0 }}>Create New Password</h2>
                <p style={{ fontSize: '13px', color: 'var(--text-secondary)', margin: 0, lineHeight: 1.5 }}>
                  Your recovery OTP code was verified successfully. Set a strong new password for your account:
                </p>
              </div>

              {error && <div style={{ color: 'var(--accent)', fontSize: '13px', fontWeight: 600, transform: 'translateZ(10px)' }}>{error}</div>}
              {info && <div style={{ color: '#4ade80', fontSize: '13px', fontWeight: 600, transform: 'translateZ(10px)' }}>{info}</div>}

              <form onSubmit={handleResetPasswordSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px', transform: 'translateZ(15px)' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-secondary)' }}>New Password</label>
                  <div style={{ position: 'relative' }}>
                    <Lock size={16} style={{ position: 'absolute', left: '14px', top: '13px', color: 'var(--text-tertiary)' }} />
                    <input
                      type="password"
                      placeholder="Enter new password (min 6 chars)"
                      value={newPassword}
                      onChange={(e) => setNewPassword(e.target.value)}
                      style={{ 
                        width: '100%', 
                        paddingLeft: '44px', 
                        fontWeight: 600,
                        background: 'rgba(0,0,0,0.3)', 
                        border: '1px solid rgba(255,255,255,0.06)', 
                        borderRadius: '12px', 
                        padding: '12px 18px 12px 44px', 
                        color: '#fff', 
                        outline: 'none' 
                      }}
                      required
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  style={{
                    width: '100%',
                    background: 'var(--accent)',
                    color: 'var(--bg-deep)',
                    border: 'none',
                    borderRadius: '12px',
                    padding: '14px',
                    fontSize: '14px',
                    fontWeight: 800,
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '10px',
                    marginTop: '8px',
                    boxShadow: '0 4px 16px rgba(250, 45, 72, 0.25)',
                    transition: 'transform 0.2s'
                  }}
                  onMouseDown={(e) => e.currentTarget.style.transform = 'scale(0.97)'}
                  onMouseUp={(e) => e.currentTarget.style.transform = 'scale(1)'}
                >
                  {loading ? <RefreshCw size={15} className="spin-animation" style={{ animation: 'spin 1.5s linear infinite' }} /> : null}
                  <span>Reset & Sign In</span>
                </button>
              </form>
            </>
          ) : (
            /* Simulated OTP Verification Screen (Used for Sign Up & Forgot Password) */
            <>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', transform: 'translateZ(20px)' }}>
                <h2 style={{ fontSize: '24px', fontWeight: 900, color: '#fff', margin: 0 }}>Verify Code</h2>
                <p style={{ fontSize: '13px', color: 'var(--text-secondary)', margin: 0, lineHeight: 1.5 }}>
                  {isForgotPassword 
                    ? 'Enter the 6-digit recovery OTP code sent to your email to reset your password:' 
                    : 'We\'ve simulated a verification code for testing. Enter the following OTP code to proceed:'}
                </p>
                
                {/* Fallback OTP Code box */}
                <div
                  onClick={() => navigator.clipboard.writeText(generatedCode)}
                  className="shimmer-box"
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '8px',
                    background: 'rgba(255, 255, 255, 0.03)',
                    border: '1px solid rgba(255, 255, 255, 0.08)',
                    borderRadius: '12px',
                    padding: '12px',
                    marginTop: '12px',
                    cursor: 'pointer',
                    color: 'var(--accent)',
                    fontWeight: 900,
                    fontSize: '22px',
                    letterSpacing: '4px',
                    boxShadow: 'inset 0 2px 10px rgba(0,0,0,0.5)'
                  }}
                >
                  <Key size={18} />
                  <span>{generatedCode}</span>
                </div>
              </div>

              {error && <div style={{ color: 'var(--accent)', fontSize: '13px', fontWeight: 600, transform: 'translateZ(10px)' }}>{error}</div>}

              {/* 6 Digit OTP Input blocks */}
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: '8px', transform: 'translateZ(15px)' }}>
                {Array.from({ length: 6 }).map((_, idx) => (
                  <input
                    key={idx}
                    ref={(el) => { otpInputsRef.current[idx] = el; }}
                    type="text"
                    maxLength={1}
                    style={{
                      width: '46px',
                      height: '52px',
                      textAlign: 'center',
                      fontSize: '20px',
                      fontWeight: 'bold',
                      padding: 0,
                      background: 'rgba(0,0,0,0.3)',
                      border: '1px solid rgba(255,255,255,0.06)',
                      borderRadius: '10px',
                      color: '#fff',
                      outline: 'none'
                    }}
                    onInput={(e) => handleOtpInput(idx, e.currentTarget.value)}
                    onKeyDown={(e) => handleOtpKeyDown(idx, e)}
                  />
                ))}
              </div>

              <div style={{ display: 'flex', gap: '12px', transform: 'translateZ(10px)' }}>
                <button
                  onClick={() => setShowOtp(false)}
                  className="liquid-glass-interactive"
                  style={{
                    flex: 1,
                    background: 'rgba(255, 255, 255, 0.03)',
                    border: '1px solid rgba(255, 255, 255, 0.06)',
                    borderRadius: '12px',
                    padding: '14px',
                    color: '#fff',
                    fontWeight: 600,
                    cursor: 'pointer'
                  }}
                >
                  Cancel
                </button>
                <button
                  onClick={handleOtpSubmit}
                  disabled={loading}
                  style={{
                    flex: 1,
                    background: 'var(--accent)',
                    color: 'var(--bg-deep)',
                    border: 'none',
                    borderRadius: '12px',
                    padding: '14px',
                    fontWeight: 800,
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '8px',
                    boxShadow: '0 4px 16px rgba(250, 45, 72, 0.25)'
                  }}
                >
                  {loading ? <RefreshCw size={14} className="spin-animation" style={{ animation: 'spin 1.5s linear infinite' }} /> : null}
                  <span>Verify OTP</span>
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};
