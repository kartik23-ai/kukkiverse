'use client';

import { Play, Sparkles, TrendingUp, Flame, Music2, Radio, Compass, Heart, Disc, Volume2, ShieldCheck } from 'lucide-react';
import { useState, useEffect } from 'react';
import { usePlayer } from './context/PlayerContext';
import { Song } from './types';
import { INITIAL_TRENDING_SONGS, searchJioSaavn, searchYoutube } from './lib/api';

export default function Home() {
    const { playSong } = usePlayer();
    const [saavnSongs, setSaavnSongs] = useState<Song[]>([]);
    const [ytSongs, setYtSongs] = useState<Song[]>(INITIAL_TRENDING_SONGS);
    const [activeTab, setActiveTab] = useState<'saavn' | 'youtube'>('saavn');
    const [loading, setLoading] = useState(false);

    const hours = new Date().getHours();
    const greeting = hours < 12 ? 'Good morning ☀️' : hours < 18 ? 'Good afternoon 🌤️' : 'Good evening 🌙';

    useEffect(() => {
        let mounted = true;
        async function loadContent() {
            setLoading(true);
            try {
                const [saavnResults, ytResults] = await Promise.all([
                    searchJioSaavn('trending hindi 2026'),
                    searchYoutube('latest hit songs 2026')
                ]);

                if (mounted) {
                    if (saavnResults.length > 0) setSaavnSongs(saavnResults);
                    if (ytResults.length > 0) setYtSongs(ytResults);
                }
            } catch (_) {}
            if (mounted) setLoading(false);
        }
        loadContent();
        return () => { mounted = false; };
    }, []);

    const displaySongs = activeTab === 'saavn' ? (saavnSongs.length > 0 ? saavnSongs : INITIAL_TRENDING_SONGS) : ytSongs;
    const heroSong = displaySongs[0] || INITIAL_TRENDING_SONGS[0];

    return (
        <div className="p-4 md:p-10 pt-20 md:pt-10 aurora-bg min-h-full space-y-10 selection:bg-purple-500 selection:text-white">
            {/* Top Greeting & Engine Switcher */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                    <h1 className="text-3xl md:text-5xl font-extrabold tracking-tight title-glow bg-clip-text text-transparent bg-gradient-to-r from-white via-purple-200 to-indigo-300">
                        {greeting}
                    </h1>
                    <p className="text-sm md:text-base text-gray-400 mt-1 flex items-center gap-2 font-medium">
                        <Sparkles size={16} className="text-purple-400 animate-pulse" />
                        Next-Generation Music Player inspired by VxMusic
                    </p>
                </div>

                {/* Tab Switcher: JioSaavn vs YouTube */}
                <div className="flex items-center gap-2 p-1.5 rounded-2xl bg-black/60 border border-white/15 backdrop-blur-xl shadow-2xl">
                    <button
                        onClick={() => setActiveTab('saavn')}
                        className={`flex items-center gap-2 px-5 py-2.5 rounded-xl font-bold text-xs md:text-sm transition-all duration-300 ${
                            activeTab === 'saavn'
                                ? 'bg-gradient-to-r from-emerald-500 to-teal-600 text-white shadow-lg shadow-emerald-500/20 scale-[1.02]'
                                : 'text-gray-400 hover:text-white'
                        }`}
                    >
                        <Disc size={16} /> JioSaavn Hits 🇮🇳
                    </button>
                    <button
                        onClick={() => setActiveTab('youtube')}
                        className={`flex items-center gap-2 px-5 py-2.5 rounded-xl font-bold text-xs md:text-sm transition-all duration-300 ${
                            activeTab === 'youtube'
                                ? 'bg-gradient-to-r from-rose-500 to-red-600 text-white shadow-lg shadow-rose-500/20 scale-[1.02]'
                                : 'text-gray-400 hover:text-white'
                        }`}
                    >
                        <Flame size={16} /> YouTube Trends 🌐
                    </button>
                </div>
            </div>

            {/* Hero Spotlight Spotlight Card */}
            <div
                className="relative rounded-3xl overflow-hidden shadow-2xl border border-white/15 group cursor-pointer"
                onClick={() => playSong(heroSong, displaySongs)}
            >
                <div className="absolute inset-0 bg-gradient-to-r from-black via-black/85 to-transparent z-10" />
                <img
                    src={heroSong.thumbnail}
                    alt={heroSong.title}
                    className="w-full h-72 md:h-96 object-cover group-hover:scale-105 transition-transform duration-700 opacity-60"
                />

                <div className="absolute inset-0 z-20 p-6 md:p-12 flex flex-col justify-end items-start space-y-3">
                    <span className="px-4 py-1.5 rounded-full bg-white/20 backdrop-blur-md text-white text-xs font-extrabold tracking-widest uppercase flex items-center gap-2 border border-white/20 shadow-lg">
                        <ShieldCheck size={14} className="text-emerald-400" /> SPOTLIGHT RECOMMENDATION
                    </span>
                    <h2 className="text-3xl md:text-5xl font-extrabold text-white max-w-2xl line-clamp-2 leading-tight">
                        {heroSong.title}
                    </h2>
                    <p className="text-base md:text-lg text-purple-300 font-semibold">{heroSong.artist} • {heroSong.album || 'Featured Release'}</p>

                    <div className="pt-2 flex items-center gap-4">
                        <button className="px-8 py-3.5 rounded-full bg-gradient-to-r from-purple-500 via-indigo-600 to-cyan-500 hover:from-purple-600 hover:to-cyan-600 text-white font-extrabold text-sm md:text-base flex items-center gap-3 shadow-2xl shadow-purple-500/40 transition-all hover:scale-105 active:scale-95">
                            <Play fill="white" size={20} /> Play Track
                        </button>
                    </div>
                </div>
            </div>

            {/* Trending Section */}
            <div id="trending">
                <div className="flex items-center justify-between mb-6">
                    <div className="flex items-center gap-3">
                        <TrendingUp size={24} className="text-purple-400" />
                        <h2 className="text-2xl font-extrabold text-white">Quick Picks & Trending</h2>
                    </div>
                    <span className="text-xs font-bold text-gray-400 uppercase tracking-widest">
                        Engine: {activeTab === 'saavn' ? 'JioSaavn Official' : 'YouTube Explode'}
                    </span>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {displaySongs.slice(0, 6).map((song) => (
                        <div
                            key={song.id}
                            onClick={() => playSong(song, displaySongs)}
                            className="glass-panel p-3.5 rounded-2xl flex items-center gap-4 cursor-pointer hover:bg-white/15 transition-all duration-300 border border-white/10 group shadow-xl hover:shadow-purple-500/20 hover:scale-[1.01]"
                        >
                            <img src={song.thumbnail} alt={song.title} className="w-16 h-16 rounded-xl object-cover shadow-md group-hover:scale-105 transition shrink-0" />
                            <div className="min-w-0 flex-1">
                                <h3 className="font-bold text-white text-base truncate group-hover:text-purple-300 transition">{song.title}</h3>
                                <p className="text-xs text-gray-400 truncate mt-1">{song.artist}</p>
                            </div>
                            <div className="w-11 h-11 rounded-full bg-purple-500/20 group-hover:bg-purple-500 border border-purple-500/40 text-purple-300 group-hover:text-white flex items-center justify-center transition-all duration-300 shrink-0 shadow-lg">
                                <Play fill="currentColor" size={18} className="ml-0.5" />
                            </div>
                        </div>
                    ))}
                </div>
            </div>

            {/* Made for You Cards */}
            <div id="discover">
                <div className="flex items-center gap-3 mb-6">
                    <Compass size={24} className="text-cyan-400" />
                    <h2 className="text-2xl font-extrabold text-white">Recommended Songs</h2>
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
                        {displaySongs.map((song) => (
                            <div
                                key={song.id}
                                className="glass-panel p-4 rounded-2xl hover:bg-white/15 transition-all duration-300 cursor-pointer group flex flex-col gap-3 border border-white/10 hover:border-purple-500/40 hover:scale-[1.03] shadow-2xl"
                                onClick={() => playSong(song, displaySongs)}
                            >
                                <div className="relative aspect-square rounded-xl overflow-hidden shadow-xl">
                                    <img src={song.thumbnail} alt={song.title} className="w-full h-full object-cover group-hover:scale-110 transition duration-500" />
                                    <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-center justify-center">
                                        <div className="w-12 h-12 rounded-full bg-gradient-to-r from-purple-500 to-indigo-600 text-white flex items-center justify-center shadow-2xl transform translate-y-4 group-hover:translate-y-0 transition-transform duration-300">
                                            <Play fill="white" size={20} className="ml-0.5" />
                                        </div>
                                    </div>
                                </div>
                                <div className="min-h-[50px]">
                                    <h3 className="font-bold text-sm text-white truncate group-hover:text-purple-300 transition" title={song.title}>
                                        {song.title}
                                    </h3>
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
