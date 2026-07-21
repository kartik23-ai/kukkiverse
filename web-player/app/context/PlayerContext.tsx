'use client';

import React, { createContext, useContext, useState, ReactNode } from 'react';
import { Song, PlayerState, RepeatMode, PlayerMode } from '../types';
import { resolveStreamUrls } from '../lib/api';

interface PlayerContextType {
  state: PlayerState;
  playSong: (song: Song, newQueue?: Song[]) => void;
  togglePlay: () => void;
  setVolume: (vol: number) => void;
  playNext: (auto?: boolean) => void;
  playPrev: () => void;
  toggleShuffle: () => void;
  toggleRepeat: () => void;
  toggleMode: () => void;
  setMode: (mode: PlayerMode) => void;
}

const PlayerContext = createContext<PlayerContextType | undefined>(undefined);

export function PlayerProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<PlayerState>({
    playing: false,
    activeSong: null,
    queue: [],
    currentIndex: -1,
    volume: 0.8,
    shuffle: false,
    repeatMode: 'OFF',
    mode: 'AUDIO',
  });

  const playSong = async (song: Song, newQueue?: Song[]) => {
    let queue = newQueue ? [...newQueue] : state.queue;
    if (queue.length === 0) queue = [song];
    const index = queue.findIndex(s => s.id === song.id);

    // Initial set without waiting for async stream resolution
    setState(prev => ({
      ...prev,
      activeSong: song,
      playing: true,
      queue,
      currentIndex: index !== -1 ? index : 0
    }));

    // Async stream resolution fallback for direct audio/video URLs
    if (!song.audioUrl) {
      try {
        const streams = await resolveStreamUrls(song.id);
        const updatedSong: Song = {
          ...song,
          audioUrl: streams.audioUrl,
          videoUrl: streams.videoUrl,
        };
        setState(prev => {
          if (prev.activeSong?.id === song.id) {
            return { ...prev, activeSong: updatedSong };
          }
          return prev;
        });
      } catch (e) {
        console.warn('Stream resolution fallback:', e);
      }
    }
  };

  const togglePlay = () => {
    setState(prev => ({ ...prev, playing: !prev.playing }));
  };

  const setVolume = (vol: number) => {
    setState(prev => ({ ...prev, volume: vol }));
  };

  const toggleMode = () => {
    setState(prev => ({ ...prev, mode: prev.mode === 'AUDIO' ? 'VIDEO' : 'AUDIO' }));
  };

  const setMode = (mode: PlayerMode) => {
    setState(prev => ({ ...prev, mode }));
  };

  const playNext = (auto: boolean = false) => {
    setState(prev => {
      if (prev.queue.length === 0) return prev;
      let nextIndex = -1;
      if (prev.shuffle) {
        do {
          nextIndex = Math.floor(Math.random() * prev.queue.length);
        } while (nextIndex === prev.currentIndex && prev.queue.length > 1);
      } else {
        nextIndex = prev.currentIndex + 1;
        if (nextIndex >= prev.queue.length) {
          if (prev.repeatMode === 'ALL' || !auto) {
            nextIndex = 0;
          } else {
            return { ...prev, playing: false };
          }
        }
      }
      const nextSong = prev.queue[nextIndex];
      playSong(nextSong, prev.queue);
      return prev;
    });
  };

  const playPrev = () => {
    setState(prev => {
      if (prev.queue.length === 0) return prev;
      let newIndex = prev.currentIndex - 1;
      if (newIndex < 0) newIndex = prev.queue.length - 1;
      const prevSong = prev.queue[newIndex];
      playSong(prevSong, prev.queue);
      return prev;
    });
  };

  const toggleShuffle = () => {
    setState(prev => ({ ...prev, shuffle: !prev.shuffle }));
  };

  const toggleRepeat = () => {
    setState(prev => {
      const modes: RepeatMode[] = ['OFF', 'ALL', 'ONE'];
      const nextIndex = (modes.indexOf(prev.repeatMode) + 1) % modes.length;
      return { ...prev, repeatMode: modes[nextIndex] };
    });
  };

  return (
    <PlayerContext.Provider
      value={{
        state,
        playSong,
        togglePlay,
        setVolume,
        playNext,
        playPrev,
        toggleShuffle,
        toggleRepeat,
        toggleMode,
        setMode,
      }}
    >
      {children}
    </PlayerContext.Provider>
  );
}

export function usePlayer() {
  const context = useContext(PlayerContext);
  if (context === undefined) {
    throw new Error('usePlayer must be used within a PlayerProvider');
  }
  return context;
}
