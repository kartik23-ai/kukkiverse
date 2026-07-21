'use client';

import { Play, Sparkles, TrendingUp, Compass, Flame, Music2, Radio } from 'lucide-react';
import { useState, useEffect } from 'react';
import { usePlayer } from './context/PlayerContext';
import { Song } from './types';
import { INITIAL_TRENDING_SONGS, searchYoutube } from './lib/api';

export default function Home() {
    const { playSong } = usePlayer();
    const [songs, setSongs] = useState<Song[]>(INITIAL_TRENDING_SONGS);
    const [loading, setLoading] = useState(false);
    const hours = new Date().getHours();
    const greeting = hours < 12 ? 'Good morning ☀️' : hours < 18 ? 'Good afternoon 🌤️' : 'Good evening 🌙';

    useEffect(() => {
        let mounted = true;
        async function fetchPopular() {
            setLoading(true);
            try {
                const results = await searchYoutube('latest hit songs 2026');
                if (mounted && results.length > 0) {
                    setSongs(results);
                }
            } catch (_) {}
            if (mounted) setLoading(false);
        }
        fetchPopular();
        return () => { mounted = false; };
    }, []);

    const heroSong = songs[0] || INITIAL_TRENDING_SONGS[0];

    return (
        <div className="p-4 md:p-10 pt-20 md:pt-10 aurora-bg min-h-full space-y-10 selection:bg-purple-500 selection:text-white">
            {/* Header Greeting */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                    <h1 className="text-3xl md:text-5xl font-extrabold tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white via-purple-200 to-indigo-400">
                        {greeting}
                    </h1>
                    <p className="text-sm md:text-base text-gray-400 mt-1 flex items-center gap-2">
                        <Sparkles size={16} className="text-purple-400 animate-pulse" />
                        Experience ultra-high fidelity streaming on ROTTY Web
                    </p>
                </div>

                <div className="flex items-center gap-3">
                    <span className="px-4 py-2 rounded-full bg-purple-500/10 border border-purple-500/30 text-purple-300 font-semibold text-xs flex items-center gap-2 shadow-lg shadow-purple-500/10">
                        <Radio size={14} className="animate-pulse text-purple-400" />
                        Hugging Face Engine Active
                    </span>
                </div>
            </div>

            {/* Featured Hero Banner */}
            <div className="relative rounded-3xl overflow-hidden shadow-2xl border border-white/10 group cursor-pointer" onClick={() => playSong(heroSong, songs)}>
                <div className="absolute inset-0 bg-gradient-to-r from-black via-black/80 to-transparent z-10" />
                <img src={heroSong.thumbnail} alt={heroSong.title} className="w-full h-64 md:h-80 object-cover group-hover:scale-105 transition-transform duration-700 opacity-60" />
                
                <div className="absolute inset-0 z-20 p-6 md:p-10 flex flex-col justify-end items-start space-y-3">
                    <span className="px-3.5 py-1 rounded-full bg-white/20 backdrop-blur-md text-white text-xs font-bold tracking-widest uppercase flex items-center gap-1.5 border border-white/20">
                        <Flame size={14} className="text-amber-400" /> FEATURED TRACK
                    </span>
                    <h2 className="text-2xl md:text-4xl font-extrabold text-white max-w-xl line-clamp-2">{heroSong.title}</h2>
                    <p className="text-sm md:text-base text-gray-300 font-medium">{heroSong.artist}</p>
                    
                    <button className="mt-2 px-6 py-3 rounded-full bg-gradient-to-r from-purple-500 to-indigo-600 hover:from-purple-600 hover:to-indigo-700 text-white font-bold flex items-center gap-3 shadow-xl shadow-purple-500/30 transition-all hover:scale-105 active:scale-95">
                        <Play fill="white" size={18} /> Play Now
                    </button>
                </div>
            </div>

            {/* Quick Picks */}
            <div>
                <div className="flex items-center gap-2 mb-6">
                    <TrendingUp size={22} className="text-purple-400" />
                    <h2 className="text-2xl font-bold text-white">Quick Picks</h2>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {songs.slice(0, 6).map(song => (
                        <div
                            key={song.id}
                            onClick={() => playSong(song, songs)}
                            className="glass-panel p-3 rounded-2xl flex items-center gap-4 cursor-pointer hover:bg-white/15 transition-all duration-300 border border-white/10 group shadow-lg hover:shadow-purple-500/10"
                        >
                            <img src={song.thumbnail} alt={song.title} className="w-16 h-16 rounded-xl object-cover shadow-md group-hover:scale-105 transition" />
                            <div className="min-w-0 flex-1">
                                <h3 className="font-bold text-white truncate group-hover:text-purple-300 transition">{song.title}</h3>
                                <p className="text-xs text-gray-400 truncate mt-0.5">{song.artist}</p>
                            </div>
                            <div className="w-10 h-10 rounded-full bg-purple-500/20 group-hover:bg-purple-500 border border-purple-500/40 text-purple-300 group-hover:text-white flex items-center justify-center transition-all duration-300 shrink-0">
                                <Play fill="currentColor" size={16} className="ml-0.5" />
                            </div>
                        </div>
                    ))}
                </div>
            </div>

            {/* Made for You Grid */}
            <div>
                <div className="flex items-center gap-2 mb-6">
                    <Compass size={22} className="text-indigo-400" />
                    <h2 className="text-2xl font-bold text-white">Made For You</h2>
                </div>

                {loading ? (
                    <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-6">
                        {[...Array(6)].map((_, i) => (
                            <div key={i} className="glass-panel p-4 rounded-2xl animate-pulse space-y-3">
                                <div className="aspect-square bg-white/10 rounded-xl" />
                                <div className="h-4 bg-white/10 rounded w-3/4" />
                                <div className="h-3 bg-white/10 rounded w-1/2" />
                            </div>
                        ))}
                    </div>
                ) : (
                    <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-6">
                        {songs.map(song => (
                            <div
                                key={song.id}
                                className="glass-panel p-4 rounded-2xl hover:bg-white/10 transition-all duration-300 cursor-pointer group flex flex-col gap-3 border border-white/10 hover:border-purple-500/30 hover:scale-[1.02] shadow-xl"
                                onClick={() => playSong(song, songs)}
                            >
                                <div className="relative aspect-square rounded-xl overflow-hidden shadow-xl">
                                    <img src={song.thumbnail} alt={song.title} className="w-full h-full object-cover group-hover:scale-110 transition duration-500" />
                                    <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-center justify-center">
                                        <div className="w-12 h-12 rounded-full bg-purple-500 text-white flex items-center justify-center shadow-xl transform translate-y-4 group-hover:translate-y-0 transition-transform duration-300">
                                            <Play fill="white" size={20} className="ml-0.5" />
                                        </div>
                                    </div>
                                </div>
                                <div className="min-h-[50px]">
                                    <h3 className="font-bold text-sm text-white truncate group-hover:text-purple-300 transition" title={song.title}>{song.title}</h3>
                                    <p className="text-xs text-gray-400 truncate mt-1">{song.artist}</p>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}
