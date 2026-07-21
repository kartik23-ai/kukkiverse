import React, { useState } from 'react';
import { MusicApi } from '../services/api';
import type { Song } from '../services/api';
import { SongRow } from '../components/SongRow';
import { Search as SearchIcon, Disc, CornerDownLeft } from 'lucide-react';

export const Search: React.FC = () => {
  const [query, setQuery] = useState<string>('');
  const [results, setResults] = useState<Song[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [searched, setSearched] = useState<boolean>(false);

  const quickSearches = [
    'Blinding Lights',
    'Die With A Smile',
    'Starboy',
    'Birds of a Feather',
    'Flowers',
    'As It Was'
  ];

  const handleSearch = async (searchQuery: string) => {
    const trimmed = searchQuery.trim();
    if (!trimmed) return;

    setLoading(true);
    setSearched(true);
    try {
      const data = await MusicApi.searchSongs(trimmed);
      setResults(data);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleSearch(query);
    }
  };

  return (
    <div style={{ padding: '32px', display: 'flex', flexDirection: 'column', gap: '24px', overflowY: 'auto', height: '100%' }}>
      {/* Search Input Box */}
      <div style={{ position: 'relative', width: '100%', maxWidth: '600px' }}>
        <input
          type="text"
          placeholder="Search for songs, artists, or albums..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={handleKeyDown}
          style={{
            width: '100%',
            padding: '16px 48px 16px 20px',
            fontSize: '15px',
            border: '1px solid rgba(255, 255, 255, 0.08)',
            borderRadius: '14px',
            background: 'rgba(255, 255, 255, 0.04)',
            boxShadow: '0 4px 20px rgba(0,0,0,0.1)'
          }}
        />
        <button
          onClick={() => handleSearch(query)}
          style={{
            position: 'absolute',
            right: '16px',
            top: '50%',
            transform: 'translateY(-50%)',
            background: 'transparent',
            border: 'none',
            color: 'var(--text-secondary)',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: '8px'
          }}
        >
          <CornerDownLeft size={16} />
          <SearchIcon size={18} />
        </button>
      </div>

      {/* Quick searches */}
      {!searched && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '16px' }}>
          <h3 style={{ fontSize: '13px', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '1px' }}>
            Trending Global Searches
          </h3>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px' }}>
            {quickSearches.map((term) => (
              <button
                key={term}
                onClick={() => {
                  setQuery(term);
                  handleSearch(term);
                }}
                className="liquid-glass liquid-glass-interactive"
                style={{
                  padding: '10px 18px',
                  border: '1px solid rgba(255, 255, 255, 0.04)',
                  borderRadius: '20px',
                  fontSize: '13px',
                  color: 'var(--text-primary)',
                  fontWeight: 600,
                  cursor: 'pointer'
                }}
              >
                {term}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Results panel */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', flex: 1 }}>
        {loading ? (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '12px' }}>
            <Disc size={36} className="spin-animation" style={{ animation: 'spin 2s linear infinite', color: 'var(--accent)' }} />
            <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Searching server mirrors...</span>
          </div>
        ) : results.length > 0 ? (
          <>
            <h2 style={{ fontSize: '18px', fontWeight: 800, paddingLeft: '4px' }}>
              Search Results
            </h2>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              {results.map((song, index) => (
                <SongRow
                  key={`${song.id}-${index}`}
                  song={song}
                  index={index}
                />
              ))}
            </div>
          </>
        ) : searched ? (
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-tertiary)', fontSize: '14px' }}>
            No songs found. Try a different query.
          </div>
        ) : null}
      </div>
    </div>
  );
};
