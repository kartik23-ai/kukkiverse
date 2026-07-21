export interface Song {
  id: string;
  title: string;
  artist: string;
  thumbnail: string;
  duration?: number;
  audioUrl?: string;
  videoUrl?: string;
}

export type RepeatMode = 'OFF' | 'ALL' | 'ONE';
export type PlayerMode = 'AUDIO' | 'VIDEO';

export interface PlayerState {
  playing: boolean;
  activeSong: Song | null;
  queue: Song[];
  currentIndex: number;
  volume: number;
  shuffle: boolean;
  repeatMode: RepeatMode;
  mode: PlayerMode;
}
