import { decryptPayload, getApiUrl } from './api';

export interface SpotifyPlaylist {
  id: string;
  name: string;
  description: string;
  image: string;
  songs: any[];
}

export const SpotifyService = {
  async syncPlaylist(playlistUrl: string): Promise<SpotifyPlaylist> {
    if (!playlistUrl || playlistUrl.trim() === '') {
      throw new Error('Please enter a valid Spotify playlist URL.');
    }

    try {
      const res = await fetch(getApiUrl('/api/spotify-sync'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: playlistUrl.trim() })
      });

      if (!res.ok) {
        const errJson = await res.json().catch(() => ({}));
        throw new Error(errJson.error || 'Failed to connect to Spotify sync server.');
      }

      const json = await res.json();
      if (!json.d) {
        throw new Error('Invalid empty payload returned from server.');
      }

      const decrypted = await decryptPayload(json.d);
      if (!decrypted) {
        throw new Error('Decryption of playlist data failed.');
      }

      const playlist = JSON.parse(decrypted);
      if (!playlist || !playlist.songs || playlist.songs.length === 0) {
        throw new Error('Failed to parse songs or playlist is empty/private.');
      }

      return playlist;
    } catch (e: any) {
      console.error('[SpotifyService] Sync failed:', e);
      throw new Error(e.message || 'Error occurred while syncing Spotify playlist.');
    }
  }
};
