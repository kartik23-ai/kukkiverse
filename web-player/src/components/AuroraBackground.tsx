import React, { useEffect, useRef } from 'react';
import { useAudio } from '../context/AudioContext';

// Helper to hash string to a color pair for the canvas gradient
function getColorsFromString(title: string, artist: string): [string, string, string] {
  if (!title || title.trim() === '') {
    return ['#1a060c', '#061320', '#050508']; // Default dark theme base
  }

  const str = title + artist;
  let hash1 = 0;
  let hash2 = 0;
  for (let i = 0; i < str.length; i++) {
    hash1 = str.charCodeAt(i) + ((hash1 << 5) - hash1);
    hash2 = str.charCodeAt(i) * 31 + ((hash2 << 7) - hash2);
  }

  const hue1 = Math.abs(hash1) % 360;
  const hue2 = (hue1 + 90 + (Math.abs(hash2) % 60)) % 360;

  // Render dark rich tones to keep text readable
  return [
    `hsl(${hue1}, 55%, 12%)`,
    `hsl(${hue2}, 45%, 10%)`,
    '#050508' // Base deep dark color
  ];
}

export const AuroraBackground: React.FC = () => {
  const { currentSong } = useAudio();
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let animationFrameId: number;
    let width = (canvas.width = window.innerWidth);
    let height = (canvas.height = window.innerHeight);

    const handleResize = () => {
      if (!canvas) return;
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    };
    window.addEventListener('resize', handleResize);

    // Get current colors based on song
    const [c1, c2, bg] = getColorsFromString(
      currentSong?.title || '',
      currentSong?.artist || ''
    );

    // Dynamic wave parameters
    let time = 0;
    const wave = {
      x1: width / 3,
      y1: height / 3,
      r1: Math.max(width, height) * 0.5,
      x2: (width * 2) / 3,
      y2: (height * 2) / 3,
      r2: Math.max(width, height) * 0.6,
    };

    const draw = () => {
      time += 0.0015;

      // Slowly float coordinates using Lissajous-style math
      const cx1 = wave.x1 + Math.sin(time * 0.7) * (width * 0.15);
      const cy1 = wave.y1 + Math.cos(time * 0.5) * (height * 0.15);
      const cx2 = wave.x2 + Math.cos(time * 0.6) * (width * 0.15);
      const cy2 = wave.y2 + Math.sin(time * 0.8) * (height * 0.15);

      // 1. Fill base dark color
      ctx.fillStyle = bg;
      ctx.fillRect(0, 0, width, height);

      // 2. Draw first radial gradient wave
      const grad1 = ctx.createRadialGradient(cx1, cy1, 10, cx1, cy1, wave.r1);
      grad1.addColorStop(0, c1);
      grad1.addColorStop(1, 'transparent');
      ctx.fillStyle = grad1;
      ctx.fillRect(0, 0, width, height);

      // 3. Draw second radial gradient wave
      const grad2 = ctx.createRadialGradient(cx2, cy2, 10, cx2, cy2, wave.r2);
      grad2.addColorStop(0, c2);
      grad2.addColorStop(1, 'transparent');
      ctx.fillStyle = grad2;
      ctx.fillRect(0, 0, width, height);

      animationFrameId = requestAnimationFrame(draw);
    };

    draw();

    return () => {
      window.removeEventListener('resize', handleResize);
      cancelAnimationFrame(animationFrameId);
    };
  }, [currentSong]);

  return (
    <canvas
      ref={canvasRef}
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        height: '100%',
        zIndex: -1,
        pointerEvents: 'none',
      }}
    />
  );
};
