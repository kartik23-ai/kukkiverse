import React, { useState, useEffect } from 'react';
import { Heart, Star, CheckCircle, Smartphone, Mail, Hash, Sparkles } from 'lucide-react';
import { StorageService } from '../services/storage';
import { FirestoreRest } from '../services/firebase';

export const Support: React.FC = () => {
  const [email, setEmail] = useState<string>('');
  const [utr, setUtr] = useState<string>('');
  const [verifying, setVerifying] = useState<boolean>(false);
  const [success, setSuccess] = useState<boolean>(false);
  const [isSupporterLocal, setIsSupporterLocal] = useState<boolean>(StorageService.isSupporter());

  // Show submission modal state
  const [showSubModal, setShowSubModal] = useState<boolean>(false);
  const [showSuccessModal, setShowSuccessModal] = useState<boolean>(false);
  const [submittedUtr, setSubmittedUtr] = useState<string>('');

  // Kartik's Configurable UPI ID & display name
  const upiAddress = '8532999011@ybl';
  const payeeName = 'Rotty Music';
  const upiUri = `upi://pay?pa=${upiAddress}&pn=${encodeURIComponent(payeeName)}&am=99&cu=INR&tn=Rotty%20Music%20Supporter`;
  const qrApiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${encodeURIComponent(upiUri)}`;

  useEffect(() => {
    const cachedEmail = localStorage.getItem('rotty_user_email') || '';
    setEmail(cachedEmail);
  }, []);

  const handleLaunchUPI = () => {
    try {
      window.open(upiUri, '_self');
    } catch (_) {
      alert('Failed to launch direct payment. Please scan the QR code to pay.');
    }
  };

  const handleVerifyPayment = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanEmail = email.trim();
    const cleanUtr = utr.trim();

    if (!cleanEmail || !cleanUtr) {
      alert('Please fill both Email and UPI UTR ID!');
      return;
    }

    setVerifying(true);

    // Bypass logic for developer testing (email/utr contains bypass or 777777)
    if (
      cleanEmail.toLowerCase().includes('bypass') ||
      cleanEmail === '777777' ||
      cleanUtr.toLowerCase().includes('bypass') ||
      cleanUtr === '777777'
    ) {
      StorageService.setIsSupporter(true);
      setIsSupporterLocal(true);
      const uid = localStorage.getItem('rotty_user_uid');
      if (uid) {
        try {
          await FirestoreRest.setDoc(`users/${uid}`, { is_supporter: true }, true);
        } catch (_) {}
      }
      
      // Trigger a window event to update the avatar decoration in sidebar/header instantly
      window.dispatchEvent(new Event('library-update'));

      setTimeout(() => {
        setVerifying(false);
        setSuccess(true);
        setShowSuccessModal(true);
      }, 800);
      return;
    }

    // UTR numeric 12-digit check
    const utrRegex = /^\d{12}$/;
    if (!utrRegex.test(cleanUtr)) {
      setVerifying(false);
      alert('Please enter a valid 12-digit numeric UPI UTR Reference Number.');
      return;
    }

    const uid = localStorage.getItem('rotty_user_uid') || 'guest';
    const data = {
      uid,
      email: cleanEmail,
      utr: cleanUtr,
      status: 'pending',
      submittedAt: new Date().toISOString()
    };

    try {
      // Post to payments_pending/utr
      await FirestoreRest.setDoc(`payments_pending/${cleanUtr}`, data);
      setSubmittedUtr(cleanUtr);
      setVerifying(false);
      setShowSubModal(true);
      setUtr('');
    } catch (err: any) {
      setVerifying(false);
      alert(`Submission failed: ${err.message || 'Error occurred'}`);
    }
  };

  const isSupporter = isSupporterLocal || success;

  return (
    <div 
      className="view-shell support-view"
      style={{ 
        padding: '32px', 
        display: 'flex', 
        flexDirection: 'column', 
        gap: '24px', 
        overflowY: 'auto', 
        height: '100%', 
        maxWidth: '800px',
        margin: '0 auto',
        width: '100%'
      }}
    >
      {/* Header */}
      <div>
        <h1 
          className="shimmer-text"
          style={{ 
            fontSize: '28px', 
            fontWeight: 900, 
            letterSpacing: '1.5px',
            textTransform: 'uppercase',
            display: 'flex',
            alignItems: 'center',
            gap: '12px'
          }}
        >
          <span>Support Rotty</span>
          <Heart size={24} fill="var(--accent)" style={{ color: 'var(--accent)' }} />
        </h1>
        <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
          Help fund hosting and secure permanent profile VIP aesthetics.
        </p>
      </div>

      {isSupporter ? (
        /* Supporter VIP State */
        <div 
          className="liquid-glass"
          style={{
            padding: '40px 24px',
            borderRadius: '24px',
            border: '1px solid rgba(250, 45, 120, 0.3)',
            boxShadow: '0 12px 40px rgba(250, 45, 120, 0.15)',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            textAlign: 'center',
            gap: '20px',
            animation: 'fade-in 0.5s ease-out'
          }}
        >
          <div 
            style={{
              padding: '24px',
              borderRadius: '50%',
              background: 'rgba(250, 45, 120, 0.08)',
              border: '2px solid rgba(250, 45, 120, 0.3)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 0 25px rgba(250, 45, 120, 0.3)'
            }}
          >
            <Star size={44} fill="#FF2E93" style={{ color: '#FF2E93' }} />
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <h2 style={{ fontSize: '22px', fontWeight: 900, color: '#fff', letterSpacing: '-0.5px' }}>
              You are a Supporter! 🌟
            </h2>
            <p style={{ fontSize: '13.5px', color: 'var(--text-secondary)', lineHeight: '1.6', maxWidth: '500px' }}>
              Thank you for contributing ₹99 to help cover backend server and hosting costs. 
              Your permanent hot-pink verified supporter badge, neon halo, and premium UI elements are now fully unlocked!
            </p>
          </div>
        </div>
      ) : (
        /* Appeal & QR Payment Checkout Forms */
        <div style={{ display: 'flex', flexDirection: 'column', gap: '28px' }}>
          
          {/* Description appeal card */}
          <div 
            className="liquid-glass" 
            style={{ 
              padding: '24px', 
              borderRadius: '16px', 
              display: 'flex', 
              flexDirection: 'column', 
              gap: '12px',
              border: '1px solid rgba(255, 255, 255, 0.06)'
            }}
          >
            <h3 style={{ fontSize: '17px', fontWeight: 800, color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
              Keep Rotty Alive and Ad-Free 💖
            </h3>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: '1.6' }}>
              Maintaining high-speed servers, database instances, and developing new features takes effort and hosting costs. 
              If you love this completely free, ad-free visual music experience, consider supporting Kartik with a one-time gift of <strong>₹99</strong>.
              <br /><br />
              In return, you will <strong>permanently unlock</strong> a glowing Supporter Badge, hot-pink verification status, and neon profile styling!
            </p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.2fr', gap: '24px', flexWrap: 'wrap' }} className="responsive-grid">
            
            {/* STEP 1: QR Payment */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <span style={{ fontSize: '11px', fontWeight: 800, color: 'var(--text-tertiary)', letterSpacing: '1px' }}>
                STEP 1: SCAN QR CODE TO PAY ₹99
              </span>
              <div 
                className="liquid-glass"
                style={{ 
                  padding: '24px', 
                  borderRadius: '16px', 
                  display: 'flex', 
                  flexDirection: 'column', 
                  alignItems: 'center',
                  gap: '16px',
                  border: '1px solid rgba(255, 255, 255, 0.04)'
                }}
              >
                {/* Embedded QR Code via high-speed safe public generator API */}
                <div style={{
                  padding: '12px',
                  backgroundColor: '#fff',
                  borderRadius: '14px',
                  display: 'inline-flex',
                  boxShadow: '0 8px 24px rgba(0,0,0,0.2)'
                }}>
                  <img 
                    src={qrApiUrl} 
                    alt="Rotty Music UPI QR Code" 
                    style={{ width: '180px', height: '180px' }} 
                  />
                </div>
                
                <div style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                  <p style={{ fontSize: '12px', color: 'var(--text-secondary)', fontWeight: 500 }}>
                    Scan with GPay, PhonePe, Paytm, or any UPI App
                  </p>
                  <span style={{ fontSize: '11px', color: 'var(--text-tertiary)', fontWeight: 'bold' }}>
                    UPI ID: {upiAddress}
                  </span>
                </div>

                {/* Direct payment launch on supported mobile clients */}
                <button
                  onClick={handleLaunchUPI}
                  className="liquid-glass-interactive"
                  style={{
                    width: '100%',
                    height: '44px',
                    backgroundColor: 'var(--accent)',
                    border: 'none',
                    borderRadius: '10px',
                    color: 'var(--bg-deep)',
                    fontWeight: 800,
                    fontSize: '12.5px',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '8px',
                    boxShadow: '0 4px 12px rgba(250, 45, 72, 0.2)'
                  }}
                >
                  <Smartphone size={16} />
                  <span>Pay Directly via UPI App</span>
                </button>
              </div>
            </div>

            {/* STEP 2: Claim Verification Form */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <span style={{ fontSize: '11px', fontWeight: 800, color: 'var(--text-tertiary)', letterSpacing: '1px' }}>
                STEP 2: ENTER DETAILS FOR VERIFICATION
              </span>
              <form 
                onSubmit={handleVerifyPayment}
                className="liquid-glass"
                style={{ 
                  padding: '24px', 
                  borderRadius: '16px', 
                  display: 'flex', 
                  flexDirection: 'column', 
                  gap: '16px',
                  border: '1px solid rgba(255, 255, 255, 0.04)'
                }}
              >
                {/* Email Address */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '13px', fontWeight: 700, color: '#fff', display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Mail size={14} style={{ color: 'var(--accent)' }} />
                    <span>Email Address</span>
                  </label>
                  <span style={{ fontSize: '11px', color: 'var(--text-tertiary)' }}>
                    Enter your logged-in account email.
                  </span>
                  <input
                    type="email"
                    placeholder="e.g. yourname@gmail.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      backgroundColor: 'rgba(255, 255, 255, 0.04)',
                      border: '1px solid rgba(255, 255, 255, 0.08)',
                      borderRadius: '8px',
                      color: '#fff',
                      fontSize: '13px',
                      outline: 'none',
                      fontWeight: 600,
                      transition: 'border-color 0.2s'
                    }}
                    onFocus={(e) => e.target.style.borderColor = 'var(--accent)'}
                    onBlur={(e) => e.target.style.borderColor = 'rgba(255, 255, 255, 0.08)'}
                  />
                </div>

                {/* 12-Digit UPI UTR ID */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '13px', fontWeight: 700, color: '#fff', display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Hash size={14} style={{ color: 'var(--accent)' }} />
                    <span>12-Digit UPI UTR ID</span>
                  </label>
                  <span style={{ fontSize: '11px', color: 'var(--text-tertiary)' }}>
                    Locate the UTR/Transaction Reference number on your receipt.
                  </span>
                  <input
                    type="text"
                    maxLength={12}
                    placeholder="e.g. 312567890123"
                    value={utr}
                    onChange={(e) => setUtr(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      backgroundColor: 'rgba(255, 255, 255, 0.04)',
                      border: '1px solid rgba(255, 255, 255, 0.08)',
                      borderRadius: '8px',
                      color: '#fff',
                      fontSize: '13px',
                      outline: 'none',
                      fontWeight: 600,
                      transition: 'border-color 0.2s'
                    }}
                    onFocus={(e) => e.target.style.borderColor = 'var(--accent)'}
                    onBlur={(e) => e.target.style.borderColor = 'rgba(255, 255, 255, 0.08)'}
                  />
                </div>

                {/* Verification Trigger Button */}
                <button
                  type="submit"
                  disabled={verifying}
                  className="liquid-glass-interactive"
                  style={{
                    width: '100%',
                    height: '44px',
                    backgroundColor: 'transparent',
                    border: '1.5px solid var(--accent)',
                    borderRadius: '10px',
                    color: 'var(--accent)',
                    fontWeight: 800,
                    fontSize: '13px',
                    cursor: verifying ? 'not-allowed' : 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '8px',
                    marginTop: '8px',
                    opacity: verifying ? 0.6 : 1
                  }}
                >
                  {verifying ? (
                    <div className="spinner-mini" style={{ width: '16px', height: '16px', border: '2px solid var(--accent)', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
                  ) : (
                    <span>Submit Claim & Activate Badge 🎖️</span>
                  )}
                </button>
              </form>
            </div>

          </div>

        </div>
      )}

      {/* MODAL 1: PENDING CLAIM SUBMITTED */}
      {showSubModal && (
        <div 
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            width: '100vw',
            height: '100vh',
            backgroundColor: 'rgba(5, 5, 8, 0.85)',
            backdropFilter: 'blur(10px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: '16px'
          }}
        >
          <div 
            className="liquid-glass"
            style={{
              padding: '32px',
              borderRadius: '24px',
              border: '1px solid rgba(255, 255, 255, 0.08)',
              width: '90%',
              maxWidth: '420px',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              boxShadow: '0 12px 40px rgba(0, 0, 0, 0.5)',
              textAlign: 'center',
              gap: '16px',
              animation: 'scale-up 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)'
            }}
          >
            <div style={{
              width: '64px',
              height: '64px',
              borderRadius: '50%',
              backgroundColor: 'rgba(16, 185, 129, 0.1)',
              border: '1.5px solid rgba(16, 185, 129, 0.4)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#10B981'
            }}>
              <CheckCircle size={32} />
            </div>

            <h3 style={{ fontSize: '19px', fontWeight: 900, color: '#fff', marginTop: '8px' }}>
              Claim Submitted! 🎖️
            </h3>

            <p style={{ fontSize: '12.5px', color: 'var(--text-secondary)', lineHeight: '1.6' }}>
              Aapki UTR ID (<strong>{submittedUtr}</strong>) verification ke liye submit ho gayi hai. 
              Kartik 12-24 hours me verify karke supporter badge unlock kar denge.
            </p>

            <button
              onClick={() => setShowSubModal(false)}
              className="liquid-glass-interactive"
              style={{
                width: '100%',
                height: '42px',
                backgroundColor: 'var(--accent)',
                border: 'none',
                borderRadius: '10px',
                color: 'var(--bg-deep)',
                fontWeight: 800,
                fontSize: '13px',
                cursor: 'pointer',
                marginTop: '12px'
              }}
            >
              Got it! 👍
            </button>
          </div>
        </div>
      )}

      {/* MODAL 2: BYPASS SUCCESS CELEBRATION */}
      {showSuccessModal && (
        <div 
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            width: '100vw',
            height: '100vh',
            backgroundColor: 'rgba(5, 5, 8, 0.85)',
            backdropFilter: 'blur(10px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: '16px'
          }}
        >
          <div 
            className="liquid-glass"
            style={{
              padding: '32px',
              borderRadius: '24px',
              border: '1px solid rgba(250, 45, 120, 0.25)',
              width: '90%',
              maxWidth: '420px',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              boxShadow: '0 12px 40px rgba(250, 45, 120, 0.15)',
              textAlign: 'center',
              gap: '16px',
              animation: 'scale-up 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)'
            }}
          >
            <div style={{
              width: '64px',
              height: '64px',
              borderRadius: '50%',
              backgroundColor: 'rgba(250, 45, 120, 0.1)',
              border: '1.5px solid rgba(250, 45, 120, 0.4)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#FF2E93',
              boxShadow: '0 0 15px rgba(250, 45, 120, 0.3)'
            }}>
              <Sparkles size={32} />
            </div>

            <h3 style={{ fontSize: '19px', fontWeight: 900, color: '#fff', marginTop: '8px' }}>
              Thank You, Supporter! 💖
            </h3>

            <p style={{ fontSize: '12.5px', color: 'var(--text-secondary)', lineHeight: '1.6' }}>
              Your support has been verified. You have permanently unlocked the exclusive Rotty Supporter badge on your profile!
            </p>

            <button
              onClick={() => setShowSuccessModal(false)}
              className="liquid-glass-interactive"
              style={{
                width: '100%',
                height: '42px',
                backgroundColor: 'var(--accent)',
                border: 'none',
                borderRadius: '10px',
                color: 'var(--bg-deep)',
                fontWeight: 800,
                fontSize: '13px',
                cursor: 'pointer',
                marginTop: '12px'
              }}
            >
              Awesome 🎵
            </button>
          </div>
        </div>
      )}

    </div>
  );
};
