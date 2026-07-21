import { FirestoreRest } from './firebase';
import { StorageService } from './storage';
import type { Song } from './api';
import type { Playlist } from './storage';

export const LibrarySyncService = {
  async syncAll(userId: string) {
    if (!userId) return;
    try {
      console.log('[LibrarySync] Syncing user library data from cloud...');
      
      // 1. Pull user root document (Liked songs, etc.)
      const userDoc = await FirestoreRest.getDoc(`users/${userId}`);
      if (userDoc) {
        // Quietly set supporter status based on verified Firestore flag
        StorageService.setIsSupporter(userDoc.is_supporter === true);

        // Restore Liked Songs
        if (Array.isArray(userDoc.favoriteSongs)) {
          const cloudLiked = userDoc.favoriteSongs;
          const localLiked = StorageService.getLikedSongs();
          
          // Merge lists (avoid duplicates)
          const mergedLiked = [...localLiked];
          cloudLiked.forEach((cs: Song) => {
            if (cs && cs.id && !mergedLiked.some(ls => ls.id === cs.id)) {
              mergedLiked.push(cs);
            }
          });
          localStorage.setItem('rotty_liked_songs', JSON.stringify(mergedLiked));
        }
      }

      // 2. Pull Cloud Playlists
      const cloudPlaylists = await FirestoreRest.listDocs(`users/${userId}/playlists`);
      const localPlaylists = StorageService.getPlaylists();
      
      // Merge cloud and local playlists
      const mergedPlaylists = [...localPlaylists];
      for (const cp of cloudPlaylists) {
        if (!cp || !cp.id) continue;
        const existingIdx = mergedPlaylists.findIndex(p => p.id === cp.id);
        const songs = Array.isArray(cp.songs) ? cp.songs : [];
        const playlistData: Playlist = {
          id: cp.id,
          name: cp.name || 'Unnamed Playlist',
          songs: songs,
          createdAt: cp.createdAt || new Date().toISOString()
        };

        if (existingIdx >= 0) {
          // Sync changes by overwriting with cloud version
          mergedPlaylists[existingIdx] = playlistData;
        } else {
          mergedPlaylists.push(playlistData);
        }
      }
      localStorage.setItem('rotty_playlists', JSON.stringify(mergedPlaylists));

      // 3. Upload all local playlists/likes back to Cloud Firestore (Two-way sync)
      const finalPlaylists = StorageService.getPlaylists();
      const finalLiked = StorageService.getLikedSongs();

      // Set user root doc with favorites list
      await FirestoreRest.setDoc(`users/${userId}`, {
        favoriteSongs: finalLiked,
        favoriteIds: finalLiked.map(s => s.id),
        updatedAt: new Date().toISOString()
      }, true);

      // Sync all merged playlists to cloud subcollection
      for (const pl of finalPlaylists) {
        await FirestoreRest.setDoc(`users/${userId}/playlists/${pl.id}`, {
          id: pl.id,
          name: pl.name,
          songs: pl.songs,
          createdAt: pl.createdAt
        });
      }

      // Dispatch custom event to notify UI views (Library/Home)
      window.dispatchEvent(new Event('library-update'));
      console.log('[LibrarySync] Cloud sync completed successfully!');
    } catch (e) {
      console.error('[LibrarySync] Error syncing library data:', e);
    }
  }
};
