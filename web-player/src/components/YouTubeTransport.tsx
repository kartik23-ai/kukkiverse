import React, { useEffect, useRef, useState } from 'react';
import { EyeOff, LoaderCircle, Maximize2, Minimize2, RefreshCw } from 'lucide-react';
import { useAudio } from '../context/AudioContext';

interface YouTubeTransportProps {
  placement?: 'desktop-dock' | 'mobile-mini' | 'mobile-full';
}

export const YouTubeTransport: React.FC<YouTubeTransportProps> = ({ placement = 'desktop-dock' }) => {
  const {
    youtubeVideoId,
    videoUrl,
    isVideoMode,
    toggleVideoMode,
    onYoutubeVideoError,
    isPlaying,
    currentTime,
    isResolvingVideo
  } = useAudio();
  const stageRef = useRef<HTMLDivElement | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [videoError, setVideoError] = useState(false);
  const [isBuffering, setIsBuffering] = useState(false);
  const isCompact = placement !== 'mobile-full';

  useEffect(() => {
    setVideoError(false);
    setIsBuffering(false);
  }, [videoUrl]);

  useEffect(() => {
    const handleFullscreenChange = () => setIsFullscreen(document.fullscreenElement === stageRef.current);
    document.addEventListener('fullscreenchange', handleFullscreenChange);
    return () => document.removeEventListener('fullscreenchange', handleFullscreenChange);
  }, []);

  // The audio element is the master clock. The muted video is corrected to it
  // frequently enough that seeking and background throttling cannot create a
  // visible drift in mini-player or fullscreen mode.
  useEffect(() => {
    const video = videoRef.current;
    if (!video || !videoUrl) return;

    const syncToAudioClock = () => {
      if (!Number.isFinite(currentTime)) return;
      if (Math.abs(video.currentTime - currentTime) > 0.16) {
        try {
          video.currentTime = currentTime;
        } catch {
          // The media element may still be loading metadata.
        }
      }
    };

    syncToAudioClock();
    if (!isVideoMode || !isPlaying) {
      video.pause();
      return;
    }

    void video.play().catch(() => setIsBuffering(true));
    const timer = window.setInterval(syncToAudioClock, 250);
    return () => window.clearInterval(timer);
  }, [currentTime, isPlaying, isVideoMode, videoUrl]);

  if (!youtubeVideoId && !videoUrl && !isResolvingVideo) return null;

  const handleLoadedMetadata = () => {
    setIsBuffering(false);
    const video = videoRef.current;
    if (!video) return;
    try {
      video.currentTime = Math.min(currentTime, Math.max(0, video.duration || currentTime));
    } catch {
      // Metadata can arrive between the duration and currentTime assignments.
    }
  };

  const handleVideoError = () => {
    setVideoError(true);
    setIsBuffering(false);
    onYoutubeVideoError();
  };

  const toggleFullscreen = async () => {
    if (!stageRef.current) return;
    if (document.fullscreenElement) {
      await document.exitFullscreen().catch(() => undefined);
      return;
    }
    await stageRef.current.requestFullscreen?.().catch(() => undefined);
  };

  const retryVideo = () => {
    setVideoError(false);
    setIsBuffering(true);
    onYoutubeVideoError();
  };

  const isLoading = isResolvingVideo || (!videoUrl && !videoError);
  const isVisible = isVideoMode && Boolean(videoUrl);
  const isStageActive = isVideoMode || isResolvingVideo;

  const placementStyle: React.CSSProperties = placement === 'mobile-full'
    ? {
        position: 'relative',
        width: '100%',
        height: 'min(56vw, 360px)',
        minHeight: '210px',
        margin: '0 auto 8px',
        borderRadius: '24px',
        zIndex: 1,
        pointerEvents: isStageActive ? 'auto' : 'none'
      }
    : placement === 'mobile-mini'
      ? {
          position: 'absolute',
          top: '7px',
          left: '8px',
          width: '88px',
          height: '46px',
          borderRadius: '12px',
          zIndex: 3,
          pointerEvents: isStageActive ? 'auto' : 'none'
        }
      : {
          position: 'absolute',
          left: '16px',
          bottom: '8px',
          width: '154px',
          height: '74px',
          borderRadius: '14px',
          zIndex: 24,
          pointerEvents: isStageActive ? 'auto' : 'none'
        };

  return (
    <div
      ref={stageRef}
      data-video-placement={placement}
      aria-label={isVisible ? 'Cached music video' : 'Preparing cached music video'}
      style={{
        ...placementStyle,
        minWidth: placement === 'mobile-full' ? '0' : placement === 'mobile-mini' ? '88px' : '154px',
        minHeight: placement === 'mobile-full' ? '210px' : placement === 'mobile-mini' ? '46px' : '74px',
        opacity: isStageActive ? 1 : 0,
        overflow: 'hidden',
        background: '#06070b',
        border: isStageActive ? '1px solid rgba(255,255,255,0.14)' : 'none',
        boxShadow: isStageActive ? '0 18px 48px rgba(0,0,0,0.42)' : 'none'
      }}
    >
      {videoUrl && (
        <video
          ref={videoRef}
          key={videoUrl}
          src={videoUrl}
          muted
          playsInline
          preload="auto"
          controls={false}
          disablePictureInPicture
          onLoadedMetadata={handleLoadedMetadata}
          onCanPlay={() => setIsBuffering(false)}
          onWaiting={() => setIsBuffering(true)}
          onPlaying={() => setIsBuffering(false)}
          onError={handleVideoError}
          aria-label="Cached music video"
          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
        />
      )}

      {isStageActive && (isLoading || isBuffering || videoError) && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'grid',
            placeItems: 'center',
            background: 'linear-gradient(135deg, rgba(6,7,11,0.92), rgba(18,20,30,0.76))',
            color: '#fff',
            pointerEvents: 'auto'
          }}
        >
          <div style={{ display: 'grid', justifyItems: 'center', gap: '10px' }}>
            {videoError ? (
              <>
                <span style={{ fontSize: '13px', fontWeight: 700 }}>Video cache failed</span>
                <button
                  type="button"
                  onClick={retryVideo}
                  style={{ display: 'inline-flex', alignItems: 'center', gap: '7px', border: 0, borderRadius: '999px', padding: '9px 14px', color: '#fff', background: 'rgba(250,45,72,0.88)', cursor: 'pointer', fontWeight: 700 }}
                >
                  <RefreshCw size={14} /> Retry download
                </button>
              </>
            ) : (
              <>
                <LoaderCircle size={22} className="spin" />
                <span style={{ fontSize: isCompact ? '10px' : '12px', fontWeight: 700, textAlign: 'center', padding: '0 12px' }}>Downloading video for smooth playback…</span>
              </>
            )}
          </div>
        </div>
      )}

      {isVisible && !isCompact && (
        <div
          style={{ position: 'absolute', left: '14px', right: '14px', bottom: '14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', pointerEvents: 'none' }}
        >
          <span style={{ padding: '7px 10px', borderRadius: '999px', background: 'rgba(5,5,8,0.72)', backdropFilter: 'blur(14px)', color: '#fff', fontSize: '11px', fontWeight: 700, letterSpacing: '0.04em' }}>
            Cached video · synced to Rotty audio
          </span>
          <div style={{ display: 'flex', gap: '8px', pointerEvents: 'auto' }}>
            <button
              type="button"
              onClick={toggleFullscreen}
              aria-label={isFullscreen ? 'Exit fullscreen video' : 'Open fullscreen video'}
              style={{ width: '34px', height: '34px', display: 'grid', placeItems: 'center', color: '#fff', border: 0, borderRadius: '50%', background: 'rgba(5,5,8,0.72)', cursor: 'pointer' }}
            >
              {isFullscreen ? <Minimize2 size={15} /> : <Maximize2 size={15} />}
            </button>
            <button
              type="button"
              onClick={toggleVideoMode}
              aria-label="Close video mode"
              style={{ width: '34px', height: '34px', display: 'grid', placeItems: 'center', color: '#fff', border: 0, borderRadius: '50%', background: 'rgba(5,5,8,0.72)', cursor: 'pointer' }}
            >
              <EyeOff size={15} />
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
