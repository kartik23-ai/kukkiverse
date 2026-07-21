import { FirestoreRest } from './firebase';
import type { Song } from './api';

export interface SyncDevice {
  id: string;
  name: string;
  type: 'mobile' | 'desktop';
  online: boolean;
  lastSeen: string;
}

export interface PlaybackState {
  songId: string | null;
  title: string | null;
  artist: string | null;
  image: string | null;
  positionMs: number;
  durationMs: number;
  isPlaying: boolean;
  activeDevice: string | null;
  updatedAt: string;
}

export type ConnectAction = 'play' | 'pause' | 'next' | 'prev' | 'seekTo' | 'volume';

export const RottyConnectService = {
  userId: '' as string,
  deviceId: '' as string,
  deviceName: '' as string,
  deviceType: 'desktop' as 'mobile' | 'desktop',
  
  heartbeatTimer: null as any,
  commandTimer: null as any,
  commandCallback: null as ((action: ConnectAction, value?: number) => void) | null,

  async init(userId: string) {
    if (!userId) return;
    this.userId = userId;

    // Get or generate device ID
    let devId = localStorage.getItem('rotty_device_id');
    if (!devId) {
      devId = 'web_' + Math.random().toString(36).substring(2, 15);
      localStorage.setItem('rotty_device_id', devId);
    }
    this.deviceId = devId;

    // Detect device attributes
    const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) || window.innerWidth <= 768;
    this.deviceType = isMobile ? 'mobile' : 'desktop';
    
    // User agent basic naming
    let name = 'Web Browser';
    if (navigator.userAgent.includes('Chrome')) name = 'Chrome Browser';
    else if (navigator.userAgent.includes('Safari')) name = 'Safari Browser';
    else if (navigator.userAgent.includes('Firefox')) name = 'Firefox Browser';
    this.deviceName = `${isMobile ? 'Mobile' : 'Desktop'} PWA (${name})`;

    // Register this device as online
    await this.sendHeartbeat(true);

    // Setup heartbeat loop every 30 seconds
    if (this.heartbeatTimer) clearInterval(this.heartbeatTimer);
    this.heartbeatTimer = setInterval(() => {
      this.sendHeartbeat(true);
    }, 30000);

    console.log(`[RottyConnect] Initialized device ${this.deviceName} (${this.deviceId}) for user ${this.userId}`);
  },

  async sendHeartbeat(online: boolean) {
    if (!this.userId || !this.deviceId) return;
    const deviceData = {
      name: this.deviceName,
      type: this.deviceType,
      online: online,
      lastSeen: new Date().toISOString()
    };
    await FirestoreRest.setDoc(`rotty_connect/${this.userId}/devices/${this.deviceId}`, deviceData);
  },

  async getDevices(): Promise<SyncDevice[]> {
    if (!this.userId) return [];
    try {
      const docs = await FirestoreRest.listDocs(`rotty_connect/${this.userId}/devices`);
      return docs.map(d => ({
        id: d.id,
        name: d.name || 'Unknown Web Device',
        type: d.type === 'desktop' ? 'desktop' : 'mobile',
        online: !!d.online,
        lastSeen: d.lastSeen || new Date().toISOString()
      }));
    } catch (e) {
      console.error('Error fetching Sync devices:', e);
      return [];
    }
  },

  async updatePlayback(song: Song | null, isPlaying: boolean, positionSec: number) {
    if (!this.userId || !this.deviceId) return;
    const playbackData = {
      songId: song ? song.id : null,
      title: song ? song.title : null,
      artist: song ? song.artist : null,
      image: song ? song.image : null,
      positionMs: Math.floor(positionSec * 1000),
      durationMs: song ? Math.floor(song.duration * 1000) : 0,
      isPlaying: isPlaying,
      activeDevice: this.deviceId,
      updatedAt: new Date().toISOString()
    };
    await FirestoreRest.setDoc(`rotty_connect/${this.userId}/state/playback`, playbackData);
  },

  async watchPlayback(): Promise<PlaybackState | null> {
    if (!this.userId) return null;
    const doc = await FirestoreRest.getDoc(`rotty_connect/${this.userId}/state/playback`);
    if (!doc) return null;
    return {
      songId: doc.songId || null,
      title: doc.title || null,
      artist: doc.artist || null,
      image: doc.image || null,
      positionMs: Number(doc.positionMs) || 0,
      durationMs: Number(doc.durationMs) || 0,
      isPlaying: !!doc.isPlaying,
      activeDevice: doc.activeDevice || null,
      updatedAt: doc.updatedAt || new Date().toISOString()
    };
  },

  async sendCommand(action: ConnectAction, value?: number) {
    if (!this.userId || !this.deviceId) return;
    const commandData = {
      action: action,
      from: this.deviceId,
      value: value !== undefined ? value : null,
      timestamp: new Date().toISOString()
    };
    await FirestoreRest.addDoc(`rotty_connect/${this.userId}/commands`, commandData);
  },

  listenForCommands(onCommand: (action: ConnectAction, value?: number) => void) {
    this.commandCallback = onCommand;
    if (this.commandTimer) clearInterval(this.commandTimer);

    // Poll command collection every 2 seconds
    this.commandTimer = setInterval(async () => {
      if (!this.userId || !this.deviceId) return;
      try {
        const commands = await FirestoreRest.listDocs(`rotty_connect/${this.userId}/commands`);
        if (commands.length === 0) return;

        for (const cmd of commands) {
          if (cmd.from === this.deviceId) continue; // Skip own command
          
          if (cmd.action && this.commandCallback) {
            this.commandCallback(cmd.action as ConnectAction, cmd.value !== null ? Number(cmd.value) : undefined);
          }
          
          // Delete command doc to prevent re-execution
          await FirestoreRest.deleteDoc(`rotty_connect/${this.userId}/commands/${cmd.id}`);
        }
      } catch (e) {
        console.error('Error polling commands:', e);
      }
    }, 2000);
  },

  async dispose() {
    if (this.commandTimer) {
      clearInterval(this.commandTimer);
      this.commandTimer = null;
    }
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
    // Set device offline
    await this.sendHeartbeat(false);
    this.userId = '';
  }
};
