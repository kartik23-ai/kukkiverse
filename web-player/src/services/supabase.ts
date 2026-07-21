import type { Song } from './api';

const SUPABASE_URL = 'https://xakcwvxvshalmavnqasq.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhha2N3dnh2c2hhbG1hdm5xYXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1NDMyMzcsImV4cCI6MjA5NTExOTIzN30.7MmM3bp4m4u9Sjn3TrD2V1Lk4rJdEybRlcghQzsHO5c';

const headers = {
  'apikey': SUPABASE_KEY,
  'Authorization': `Bearer ${SUPABASE_KEY}`,
  'Content-Type': 'application/json'
};

export interface PartyMember {
  uid: string;
  name: string;
}

export interface PartyRoom {
  code: string;
  hostId: string;
  isPlaying: boolean;
  nowPlaying: Song | null;
  queue: Song[];
  members: PartyMember[];
  updatedAt: string;
}

export const SupabaseService = {
  async createPartyRoom(hostUid: string, hostName: string): Promise<string> {
    const code = `ROTTY-${Math.floor(10000 + Math.random() * 90000)}`;
    const now = new Date().toISOString();

    // 1. Insert room doc
    const roomRes = await fetch(`${SUPABASE_URL}/rest/v1/party_rooms`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        code,
        host_id: hostUid,
        is_playing: false,
        now_playing: null,
        queue: [],
        updated_at: now
      })
    });
    if (!roomRes.ok) throw new Error('Failed to create party room document');

    // 2. Add host as member
    const memberRes = await fetch(`${SUPABASE_URL}/rest/v1/party_members`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        room_code: code,
        uid: hostUid,
        name: hostName,
        joined_at: now
      })
    });
    if (!memberRes.ok) throw new Error('Failed to join room as host');

    return code;
  },

  async joinPartyRoom(code: string, uid: string, name: string): Promise<void> {
    const cleanCode = code.trim().toUpperCase();

    // 1. Verify room exists
    const checkRes = await fetch(`${SUPABASE_URL}/rest/v1/party_rooms?code=eq.${cleanCode}&select=code`, {
      headers
    });
    if (!checkRes.ok) throw new Error('Failed to verify party room');
    const checkData = await checkRes.json();
    if (!Array.isArray(checkData) || checkData.length === 0) {
      throw new Error('Party room not found');
    }

    // 2. Clean up any existing membership in this room
    await fetch(`${SUPABASE_URL}/rest/v1/party_members?room_code=eq.${cleanCode}&uid=eq.${uid}`, {
      method: 'DELETE',
      headers
    });

    // 3. Insert new membership
    const now = new Date().toISOString();
    const joinRes = await fetch(`${SUPABASE_URL}/rest/v1/party_members`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        room_code: cleanCode,
        uid: uid,
        name: name,
        joined_at: now
      })
    });
    if (!joinRes.ok) throw new Error('Failed to join party room');
  },

  async leavePartyRoom(code: string, uid: string): Promise<void> {
    await fetch(`${SUPABASE_URL}/rest/v1/party_members?room_code=eq.${code}&uid=eq.${uid}`, {
      method: 'DELETE',
      headers
    });
  },

  async kickMember(code: string, uid: string): Promise<void> {
    await fetch(`${SUPABASE_URL}/rest/v1/party_members?room_code=eq.${code}&uid=eq.${uid}`, {
      method: 'DELETE',
      headers
    });
  },

  async pushPartyQueue(code: string, queue: Song[]): Promise<void> {
    await fetch(`${SUPABASE_URL}/rest/v1/party_rooms?code=eq.${code}`, {
      method: 'PATCH',
      headers,
      body: JSON.stringify({
        queue: queue,
        updated_at: new Date().toISOString()
      })
    });
  },

  async updatePartyPlayback(code: string, song: Song | null, isPlaying: boolean): Promise<void> {
    await fetch(`${SUPABASE_URL}/rest/v1/party_rooms?code=eq.${code}`, {
      method: 'PATCH',
      headers,
      body: JSON.stringify({
        now_playing: song,
        is_playing: isPlaying,
        updated_at: new Date().toISOString()
      })
    });
  },

  async fetchRoomState(code: string): Promise<PartyRoom | null> {
    try {
      // 1. Fetch room detail
      const roomRes = await fetch(`${SUPABASE_URL}/rest/v1/party_rooms?code=eq.${code}&select=*`, { headers });
      if (!roomRes.ok) return null;
      const roomData = await roomRes.json();
      if (!Array.isArray(roomData) || roomData.length === 0) return null;
      
      const room = roomData[0];

      // 2. Fetch members list
      const membersRes = await fetch(`${SUPABASE_URL}/rest/v1/party_members?room_code=eq.${code}&select=*`, { headers });
      const membersData = membersRes.ok ? await membersRes.json() : [];
      const members: PartyMember[] = Array.isArray(membersData) 
        ? membersData.map(m => ({ uid: m.uid, name: m.name || 'Guest' }))
        : [];

      return {
        code: room.code,
        hostId: room.host_id,
        isPlaying: !!room.is_playing,
        nowPlaying: room.now_playing,
        queue: Array.isArray(room.queue) ? room.queue : [],
        members: members,
        updatedAt: room.updated_at
      };
    } catch (e) {
      console.error('Error fetching room state:', e);
      return null;
    }
  },

  watchPartyRoom(code: string, callback: (room: PartyRoom | null) => void, intervalMs = 2500): () => void {
    let active = true;

    const poll = async () => {
      if (!active) return;
      const state = await this.fetchRoomState(code);
      if (active) {
        callback(state);
      }
    };

    poll(); // Initial load
    const interval = setInterval(poll, intervalMs);

    return () => {
      active = false;
      clearInterval(interval);
    };
  }
};
