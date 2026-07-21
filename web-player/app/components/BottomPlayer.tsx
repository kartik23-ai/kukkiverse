'use client';

import { Maximize2, Minimize2, MoreHorizontal, Pause, Play, Repeat, Shuffle, SkipBack, SkipForward, Volume2, Video, Music, Sparkles } from 'lucide-react';
import { useRef, useState, useEffect } from 'react';
import ReactPlayer from 'react-player/youtube';
import { usePlayer } from '../context/PlayerContext';

export default function BottomPlayer() {
    const { state, togglePlay, setVolume, playNext, playPrev, toggleShuffle, toggleRepeat, toggleMode } = usePlayer();
    const { activeSong, playing, volume, shuffle, repeatMode, mode } = state;
    const [progress, setProgress] = useState(0);
    const [duration, setDuration] = useState(0);
    const [isFullScreen, setIsFullScreen] = useState(false);
    const playerRef = useRef<ReactPlayer>(null);
    const videoRef = useRef<HTMLVideoElement>(null);

    useEffect(() => {
        if (videoRef.current) {
            videoRef.current.volume = volume;
            if (playing) {
                videoRef.current.play().catch(() => {});
            } else {
                videoRef.current.pause();
            }
        }
    }, [playing, volume, activeSong]);

    if (!activeSong) return null;

    const handleEnded = () => {
        if (repeatMode === 'ONE') {
            playerRef.current?.seekTo(0);
        } else {
            playNext(true);
        }
    };

    const isDirectVideo = activeSong.videoUrl && (activeSong.videoUrl.endsWith('.mp4') || activeSong.videoUrl.endsWith('.webm'));

    return (
        <>
            {/* React Player / Media Container - Always mounted for persistent audio */}
            <div className={`fixed z-[70] transition-all duration-500 ease-in-out
                ${isFullScreen
                    ? 'inset-x-0 top-24 mx-auto w-full max-w-xl aspect-video opacity-100 pointer-events-auto'
                    : 'w-1 h-1 opacity-0 pointer-events-none -top-10 left-0'}
            `}>
                <div className={`w-full h-full rounded-2xl overflow-hidden shadow-2xl ring-1 ring-white/10 ${!isFullScreen && 'hidden'}`}>
                    {mode === 'VIDEO' && isDirectVideo ? (
                        <video
                            ref={videoRef}
                            src={activeSong.videoUrl}
                            className="w-full h-full object-cover"
                            controlsList="nodownload"
                            onEnded={handleEnded}
                        />
                    ) : (
                        <ReactPlayer
                            ref={playerRef}
                            url={activeSong.audioUrl || activeSong.videoUrl || `https://www.youtube.com/watch?v=${activeSong.id}`}
                            playing={playing}
                            volume={volume}
                            width="100%"
                            height="100%"
                            onProgress={(p) => setProgress(p.played)}
                            onDuration={setDuration}
                            onEnded={handleEnded}
                            config={{
                                playerVars: {
                                    autoplay: 1,
                                    controls: 1,
                                    modestbranding: 1,
                                    rel: 0
                                }
                            }}
                        />
                    )}
                </div>

                {!isFullScreen && (
                    <ReactPlayer
                        url={activeSong.audioUrl || activeSong.videoUrl || `https://www.youtube.com/watch?v=${activeSong.id}`}
                        playing={playing}
                        volume={volume}
                        width="0"
                        height="0"
                        onProgress={(p) => setProgress(p.played)}
                        onDuration={setDuration}
                        onEnded={handleEnded}
                    />
                )}
            </div>

            {/* Full Screen Overlay */}
            {isFullScreen && (
                <div className="fixed inset-0 bg-black/95 z-[60] flex flex-col p-6 backdrop-blur-3xl animate-in fade-in slide-in-from-bottom-10 duration-300">
                    <div className="absolute inset-0 z-[-1] opacity-30 pointer-events-none">
                        <img src={activeSong.thumbnail} alt="" className="w-full h-full object-cover blur-3xl scale-125" />
                    </div>

                    {/* Header */}
                    <div className="w-full flex justify-between items-center mb-4 shrink-0">
                        <button onClick={() => setIsFullScreen(false)} className="text-white/70 hover:text-white p-2">
                            <Minimize2 size={24} />
                        </button>
                        <div className="flex flex-col items-center">
                            <span className="text-[10px] md:text-xs font-bold tracking-[0.2em] text-purple-400 uppercase flex items-center gap-1">
                                <Sparkles size={12} /> ROTTY ULTRA PLAYER
                            </span>
                            <span className="text-[10px] md:text-xs font-bold tracking-widest text-white/40">NOW PLAYING</span>
                        </div>
                        
                        {/* Audio / Video Toggle Pill */}
                        <button
                            onClick={toggleMode}
                            className="flex items-center gap-2 px-4 py-2 rounded-full bg-white/10 hover:bg-white/20 border border-white/15 text-xs font-bold transition-all text-white shadow-lg"
                        >
                            {mode === 'VIDEO' ? <Video size={14} className="text-purple-400" /> : <Music size={14} className="text-emerald-400" />}
                            <span>{mode === 'VIDEO' ? 'Video Mode 🎬' : 'Audio Mode 🎵'}</span>
                        </button>
                    </div>

                    {/* Main Content Container */}
                    <div className="flex-1 flex flex-col items-center justify-between w-full max-w-lg mx-auto py-2 min-h-0">
                        {/* Visual Display */}
                        {mode === 'VIDEO' ? (
                            <div className="relative aspect-video w-full rounded-2xl overflow-hidden shadow-2xl ring-1 ring-white/15 bg-black">
                                <ReactPlayer
                                    url={activeSong.videoUrl || `https://www.youtube.com/watch?v=${activeSong.id}`}
                                    playing={playing}
                                    volume={volume}
                                    width="100%"
                                    height="100%"
                                    onProgress={(p) => setProgress(p.played)}
                                    onDuration={setDuration}
                                    onEnded={handleEnded}
                                />
                            </div>
                        ) : (
                            <div className="relative aspect-square w-auto h-auto max-h-[42vh] rounded-full overflow-hidden shadow-2xl shadow-black/80 ring-4 ring-white/10 shrink-1 group">
                                <img
                                    src={activeSong.thumbnail}
                                    alt={activeSong.title}
                                    className={`w-full h-full object-cover transition-all duration-1000 ${playing ? 'animate-[spin_12s_linear_infinite]' : ''}`}
                                />
                                <div className="absolute inset-0 bg-gradient-to-tr from-white/10 to-transparent pointer-events-none" />
                                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-20 h-20 bg-black/90 rounded-full flex items-center justify-center border-2 border-white/20">
                                    <div className="w-4 h-4 bg-purple-500 rounded-full animate-ping" />
                                </div>
                            </div>
                        )}

                        {/* Song Details */}
                        <div className="text-center space-y-1 w-full px-4 shrink-0 my-4">
                            <h1 className="text-xl md:text-2xl font-bold text-white truncate px-2">{activeSong.title}</h1>
                            <p className="text-sm md:text-base text-gray-400 truncate">{activeSong.artist}</p>
                        </div>

                        {/* Progress & Controls */}
                        <div className="w-full flex flex-col gap-4 shrink-0 pb-4">
                            <div className="w-full space-y-2">
                                <div className="h-1.5 bg-white/10 rounded-full w-full relative group cursor-pointer">
                                    <input
                                        type="range"
                                        min={0}
                                        max={0.999999}
                                        step="any"
                                        value={progress}
                                        onChange={(e) => {
                                            const newPlayed = parseFloat(e.target.value);
                                            setProgress(newPlayed);
                                            playerRef.current?.seekTo(newPlayed);
                                        }}
                                        className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
                                    />
                                    <div
                                        className="absolute h-full bg-gradient-to-r from-purple-500 to-emerald-400 rounded-full group-hover:bg-purple-400 transition-colors pointer-events-none"
                                        style={{ width: `${progress * 100}%` }}
                                    />
                                </div>
                                <div className="flex justify-between text-xs text-gray-400 font-mono font-medium">
                                    <span>{formatTime(progress * duration)}</span>
                                    <span>{formatTime(duration)}</span>
                                </div>
                            </div>

                            {/* Controls */}
                            <div className="flex items-center justify-between w-full max-w-xs md:max-w-md mx-auto">
                                <button
                                    onClick={toggleShuffle}
                                    className={`transition p-2 ${shuffle ? 'text-purple-400' : 'text-gray-400 hover:text-white'}`}
                                >
                                    <Shuffle size={20} />
                                </button>
                                <button onClick={playPrev} className="text-white hover:scale-110 transition p-2">
                                    <SkipBack size={28} fill="currentColor" />
                                </button>
                                <button
                                    onClick={togglePlay}
                                    className="w-16 h-16 bg-white rounded-full flex items-center justify-center text-black hover:scale-105 transition shadow-lg shadow-white/20"
                                >
                                    {playing ? <Pause size={30} fill="black" /> : <Play size={30} className="ml-1" fill="black" />}
                                </button>
                                <button onClick={() => playNext()} className="text-white hover:scale-110 transition p-2">
                                    <SkipForward size={28} fill="currentColor" />
                                </button>
                                <button
                                    onClick={toggleRepeat}
                                    className={`transition p-2 ${repeatMode !== 'OFF' ? 'text-purple-400' : 'text-gray-400 hover:text-white'} relative`}
                                >
                                    <Repeat size={20} />
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Floating Glass Island Player */}
            <div className="fixed bottom-6 left-4 right-4 md:left-1/2 md:-translate-x-1/2 md:w-full md:max-w-3xl z-40 transition-all duration-500 ease-in-out">
                <div className="glass-panel rounded-[2rem] p-3 md:p-4 flex items-center justify-between shadow-2xl shadow-black/80 border border-white/10 bg-black/60 backdrop-blur-2xl">
                    {/* Left: Song Info */}
                    <div
                        className="flex items-center gap-4 cursor-pointer hover:opacity-90 transition group min-w-0 flex-1"
                        onClick={() => setIsFullScreen(true)}
                    >
                        <div className="w-12 h-12 md:w-14 md:h-14 bg-gray-900 rounded-2xl overflow-hidden relative shrink-0 shadow-lg border border-white/10">
                            <img src={activeSong.thumbnail} alt={activeSong.title} className="object-cover w-full h-full" />
                            <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover:opacity-100 transition">
                                <Maximize2 size={16} className="text-white" />
                            </div>
                        </div>
                        <div className="min-w-0 pr-4">
                            <h4 className="text-sm md:text-base font-bold truncate text-white group-hover:text-purple-400 transition">{activeSong.title}</h4>
                            <p className="text-xs text-gray-400 truncate">{activeSong.artist}</p>
                        </div>
                    </div>

                    {/* Center: Playback Controls & Mode Switcher */}
                    <div className="flex items-center gap-3 md:gap-5 shrink-0">
                        {/* Audio / Video Quick Toggle */}
                        <button
                            onClick={toggleMode}
                            title={mode === 'VIDEO' ? 'Switch to Audio Mode' : 'Switch to Video Mode'}
                            className="hidden md:flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white/10 hover:bg-white/20 border border-white/10 text-xs font-semibold transition text-white"
                        >
                            {mode === 'VIDEO' ? <Video size={13} className="text-purple-400" /> : <Music size={13} className="text-emerald-400" />}
                            <span>{mode === 'VIDEO' ? 'Video' : 'Audio'}</span>
                        </button>

                        <button onClick={(e) => { e.stopPropagation(); playPrev(); }} className="text-gray-300 hover:text-white transition p-2 hidden md:block">
                            <SkipBack size={20} fill="currentColor" />
                        </button>
                        <button
                            onClick={(e) => { e.stopPropagation(); togglePlay(); }}
                            className="w-11 h-11 bg-white text-black rounded-full flex items-center justify-center hover:scale-105 transition shadow-lg shadow-white/20 active:scale-95"
                        >
                            {playing ? <Pause size={20} fill="black" /> : <Play size={20} className="ml-0.5" fill="black" />}
                        </button>
                        <button onClick={(e) => { e.stopPropagation(); playNext(); }} className="text-gray-300 hover:text-white transition p-2">
                            <SkipForward size={20} fill="currentColor" />
                        </button>
                    </div>

                    {/* Right: Volume & Progress */}
                    <div className="hidden md:flex items-center gap-4 flex-1 justify-end pl-4">
                        <div className="w-20 flex flex-col gap-1">
                            <div className="h-1 bg-white/10 rounded-full overflow-hidden relative">
                                <div className="absolute inset-0 bg-gradient-to-r from-purple-500 to-emerald-400 w-full transform origin-left transition-transform duration-300"
                                    style={{ transform: `scaleX(${progress})` }}
                                />
                            </div>
                        </div>
                        <div className="flex items-center gap-2">
                            <Volume2 size={16} className="text-gray-400" />
                            <div className="w-16 h-1 bg-white/10 rounded-full relative overflow-hidden">
                                <div className="absolute inset-0 bg-white w-full transform origin-left" style={{ transform: `scaleX(${volume})` }} />
                                <input
                                    type="range" min={0} max={1} step={0.05} value={volume}
                                    onChange={(e) => setVolume(parseFloat(e.target.value))}
                                    className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                                />
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
}

const formatTime = (seconds: number) => {
    if (!seconds) return "0:00";
    const min = Math.floor(seconds / 60);
    const sec = Math.floor(seconds % 60);
    return `${min}:${sec < 10 ? '0' : ''}${sec}`;
};
