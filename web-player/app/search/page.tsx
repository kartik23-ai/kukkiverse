'use client';

import { useState, useEffect } from 'react';
import { Search, Play, MoreHorizontal, Sparkles, Music, Globe, Radio } from 'lucide-react';
import { usePlayer } from '../context/PlayerContext';
import { Song } from '../types';
import { searchAll } from '../lib/api';

const GENRES = [
    { name: 'Bollywood Hits 🇮🇳', query: 'bollywood hits 2026', bg: 'from-amber-500 to-rose-600' },
    { name: 'Punjabi Fire 🔥', query: 'punjabi bangers', bg: 'from-orange-500 to-amber-600' },
    { name: 'Lo-Fi Chill 🎧', query: 'lofi study beats', bg: 'from-purple-600 to-indigo-700' },
    { name: 'Arijit & Romance ❤️', query: 'arijit singh romantic', bg: 'from-rose-500 to-pink-700' },
    { name: 'Global Top 50 🌐', query: 'global top hits 2026', bg: 'from-cyan-500 to-blue-600' },
    { name: 'Hip-Hop / Rap 🎤', query: 'deshi hip hop', bg: 'from-emerald-500 to-teal-700' },
];

export default function SearchPage() {
    const [query, setQuery] = useState('');
    const [results, setResults] = useState<Song[]>([]);
    const [loading, setLoading] = useState(false);
    const { playSong } = usePlayer();

    useEffect(() => {
        const delayDebounceFn = setTimeout(async () => {
            if (!query.trim()) {
                setResults([]);
                return;
            }

            setLoading(true);
            try {
                const songs = await searchAll(query);
                setResults(songs);
            } catch (error) {
                console.error("Unified search failed", error);
            } finally {
                setLoading(false);
            }
        }, 300);

        return () => clearTimeout(delayDebounceFn);
    }, [query]);

    return (
        <div className="p-4 md:p-10 pt-20 md:pt-10 w-full max-w-6xl mx-auto space-y-8 aurora-bg min-h-full">
            {/* Search Input Box */}
            <div className="relative max-w-2xl">
                <Search className="absolute left-5 top-1/2 -translate-y-1/2 text-purple-400" size={22} />
                <input
                    type="text"
                    placeholder="Search JioSaavn & YouTube (e.g. Arijit Singh, Kesariya, AP Dhillon)..."
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    className="w-full py-4 pl-14 pr-6 bg-black/60 border border-white/15 rounded-2xl text-white placeholder-gray-400 focus:outline-none focus:border-purple-500 focus:ring-4 focus:ring-purple-500/20 transition-all text-base md:text-lg shadow-2xl backdrop-blur-xl"
                    autoFocus
                />
            </div>

            {/* Content Area */}
            <div className="space-y-4">
                {loading && (
                    <div className="flex items-center gap-3 text-purple-400 font-semibold animate-pulse py-10">
                        <Radio className="animate-spin" size={20} />
                        <span>Searching JioSaavn & YouTube audio engines...</span>
                    </div>
                )}

                {!loading && results.length === 0 && query && (
                    <div className="text-center py-20 text-gray-400">
                        No results found for "{query}". Try another search term!
                    </div>
                )}

                {/* Genre Explorer Cards */}
                {!loading && results.length === 0 && !query && (
                    <div className="space-y-6">
                        <div className="flex items-center gap-2 text-white font-bold text-xl">
                            <Sparkles className="text-purple-400" size={20} />
                            <h2>Explore Genres & Trending Categories</h2>
                        </div>
                        <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                            {GENRES.map((g) => (
                                <div
                                    key={g.name}
                                    onClick={() => setQuery(g.name.split(' ')[0])}
                                    className={`p-6 rounded-2xl bg-gradient-to-br ${g.bg} font-extrabold text-lg md:text-xl text-white flex items-end h-32 hover:scale-[1.03] transition-all cursor-pointer shadow-xl border border-white/20 hover:shadow-purple-500/20`}
                                >
                                    {g.name}
                                </div>
                            ))}
                        </div>
                    </div>
                )}

                {/* Results List */}
                {results.length > 0 && (
                    <div className="space-y-3">
                        <h3 className="text-xs font-bold text-white/50 tracking-widest uppercase mb-4">
                            SEARCH RESULTS ({results.length})
                        </h3>
                        {results.map((song) => (
                            <div
                                key={song.id}
                                className="glass-panel flex items-center gap-4 p-3 rounded-2xl hover:bg-white/15 transition-all duration-300 group cursor-pointer border border-white/10 hover:border-purple-500/30"
                                onClick={() => playSong(song, results)}
                            >
                                <div className="relative w-14 h-14 shrink-0 rounded-xl overflow-hidden shadow-md">
                                    <img src={song.thumbnail} alt={song.title} className="w-full h-full object-cover group-hover:scale-110 transition duration-500" />
                                    <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                                        <Play size={20} fill="white" className="text-white" />
                                    </div>
                                </div>

                                <div className="flex-1 min-w-0">
                                    <div className="flex items-center gap-2">
                                        <h4 className="font-bold text-white text-base truncate group-hover:text-purple-300 transition">{song.title}</h4>
                                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-extrabold uppercase border ${
                                            song.source === 'saavn'
                                                ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                                                : 'bg-rose-500/10 text-rose-400 border-rose-500/30'
                                        }`}>
                                            {song.source === 'saavn' ? 'JioSaavn' : 'YouTube'}
                                        </span>
                                    </div>
                                    <p className="text-xs text-gray-400 truncate mt-1">{song.artist} • {song.album || 'Single'}</p>
                                </div>

                                <div className="hidden md:block text-xs font-mono text-gray-400">
                                    {song.duration ? `${Math.floor(song.duration / 60)}:${(song.duration % 60).toString().padStart(2, '0')}` : '3:30'}
                                </div>

                                <button className="p-2 text-gray-400 hover:text-white transition">
                                    <MoreHorizontal size={20} />
                                </button>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}
